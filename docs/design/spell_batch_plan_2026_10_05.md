# The spell batch: your 2026-10-05 answers, built in six steps

> **Status: APPROVED 2026-10-07** (user: "Approved. Thanks!"), after two days as a proposal.
> Of step 0, the leash floor and the charm expiry shipped and were playtested on 10-06 and
> 10-07 ahead of the approval, since they were proven bugs on the host; the rest of step 0
> starts 10-08. This is a copy of the plan-mode file so the plan lives in the repo under a
> real name. Per-item status belongs in the CLAUDE.md To-Do, not here.

## Context

Your answers on 2026-10-05 unlocked a batch that all lands in one place, the spell system: Bind
and Gate, damage over time, a global cooldown, prorated mana on interrupts, and several rule
changes. Everything is on the deploy branch and needs **no protocol bump** (testers' current
clients keep connecting; the client-side halves ride the export you already owe).

A design review then attacked the plan and found real gaps, including bugs that exist today.
Those are folded in below, mostly as a new first step. Each step is its own commit with its own
tests, so you can stop me after any of them.

## What you decided

| Topic | Your decision |
|---|---|
| Group share range | **200 m** for XP shares, quest journal ticks and the coin split (was 30 m). You must be alive for XP and journal credit. |
| Heal range | 30 m, applied to every friendly spell (heals and buffs). |
| Slow | Level 8, 10 mana, 1.0 s cast, 5% attack slow for 30 s. |
| Torpor | Level 20, 20 mana, 1.5 s cast, 10% attack slow for 1 minute, **no heal**. |
| Slow stacking | One attack slow on a target at a time; a weaker one never replaces a stronger one. |
| Global cooldown | Build it now. After any spell, all your spells lock briefly. Slow and Torpor have no other cooldown. |
| Bind Affinity | Bind yourself anywhere. Bind a **group member** only while they stand in a safe area (town). |
| Bind from birth | Every character starts bound at the starter spawn; a bind is only ever replaced. |
| Gate | Ten classes: Cleric, Druid, Shaman, Magician, Wizard, Sorcerer, Enchanter, Necromancer, Blood Mage, Bard. Your pet always comes. |
| Succor, Evacuate | Build them now. |
| Damage over time | Build it. |
| Interrupted casts | A hit that interrupts you costs mana in proportion to cast progress. Cancelling on purpose stays free. |
| Sound | The friends build ships silent. |

## The six steps

**Step 0. Harden the cast code first** (about half a day; every item verified in the code
before it is touched, since these came from a reviewer, not from me)
- A caster at 0 HP can still finish a cast in the tick they die. Add the alive check. (With
  Gate this would have moved the corpse to the bind point and skipped the corpse run.)
- Six low-level mob types leash shorter than the 25 m spell range, and a mob ignores attackers
  beyond its leash, so they may be nukable with no response **today**. Make every leash exceed
  spell reach, with a test that keeps it so.
- Refusals: several send no mana correction, a silenced or mesmerized caster is never told at
  all, and most are broadcast to everyone. Make every refusal private and carry your true mana.
- A hit and a finished cast in the same tick can both "win". Close it.
- A finished cast can be held and fired later. Give it an expiry.
- Casting should stand you up server-side, as a swing does (seated regen while casting).
- Check the report that charm expires one tick after landing; fix if true.

**Step 1. Small rules** (about half a day)
- Group share range to 200 m: one constant (`GROUP_COIN_SHARE_RANGE`, `world/mod.rs`) covers
  XP and coin; `award_kill` (`tick.rs`) applies the same test to journal ticks.
- Heals and buffs reach 30 m (server pre-flight, client check 1 m inside it).
- Slow and Torpor numbers on both sides; Torpor enters the server's data; strongest slow wins,
  enforced where the slow is applied, with a no-cost refusal for a weaker one.
- Birth bind written at character creation. "Ships silent" recorded in both schedule files.

**Step 2. Bind and Gate** (about a day) — design: `docs/design/bind_and_gate.md`
- A server data file of **safe areas** (town first), tested so no hostile aggro reaches in. It
  also gives Succor and Evacuate their arrival point.
- `BIND` and `PORT` arms; refusals cost nothing; destinations never come from the client. A
  targeted mob means "bind myself"; a player outside your group is refused.
- Teleport with the existing message; wipe you and your pet from every mob's aggro; move the
  pet properly (map grid, its target cleared so it does not run back).
- Evacuate skips dead and linkdead members.
- Client: stop running Gate and bind locally online (today Gate reloads the whole scene).

**Step 3. Interrupted casts** (about half a day)
- On a successful interrupt from **real damage** (not an absorbed or zero-damage hit, which
  would make it a mana-drain weapon): charge `mana cost x fraction of the cast done`, capped at
  what you have, then send your true mana.

**Step 4. Global cooldown** (about a day)
- Server refuses a cast that *starts* inside the lockout, right at the start, so you lose no
  cast time. Client mirrors it and `scripts/hotbar.gd` greys every spell gem.
- Length: a named constant, 2.25 s on the client with a slightly shorter server limit so an
  honest fast player is never refused. (Sources on EQ's vary from about 1.5 to 2.25 s.)
- Bard songs are exempt, or twisting stops working. Turned on with the client export.

**Step 5. Damage over time** (about a day and a half, in four slices)
- Split the spell-damage function so kill handling is shared, with no behaviour change.
- DoTs on mobs and pets: tick every 3 s, build aggro, break mez, kill with full rewards.
- **Anti-farming rules:** a mob's DoTs end the moment it starts leashing home, and yours end
  when you die, Gate, Succor, Evacuate or log out. No tagging something and collecting from
  safety.
- Ticks you can see (the existing proc message), and the target frame shows what is on a mob:
  DoTs, and also mez, root, snare and slow, which are invisible today.
- PvP DoTs through the buff system. Dark Decay and Entangle enter the server's data.
- The shared kill step also fixes: a mob finished off by your damage shield pays nothing today.

## Still open (not blocking approval)

- **Aria of Dismay**, a Bard song, is a 35% attack slow on the client. Under "strongest wins"
  it would outrank Slow (5%) and Torpor (10%) whenever a Bard is singing. Fine, or should it
  come down?
- **200 m sharing** lets a group-mate sit in town and still collect XP and coin from the camps
  nearest town. Your call stands; this is here so it is a known trade-off, not a surprise.

## Things I chose that you may want to overrule

- "Safe area" means a circle around town, defined in data. More areas are a data edit.
- Succor and Evacuate keep their current levels and costs and arrive in town, the only safe
  point there is. Until a second zone exists that makes Succor a faster Gate.
- Gate stays at level 8 with a 5 minute cooldown.
- DoT numbers are the spell's own (no INT bonus), as with all server spell damage.
- `docs/concepts/classes/shaman.md` still describes Torpor as a big slow with a heal. I will add
  a dated note pointing at the new numbers, not rewrite the class design.

## What gets reused

`handlers::send_teleport` and the Respawn pattern; the death sweep's aggro wipe (`tick.rs`
~9597) as a shared helper; the `cast_target_refusal` pre-flight; the `apply_*_exclusive` buff
pattern and `Entity::apply_cc`; the body of `apply_spell_damage_to_enemy`; the existing
`ProcTriggered` and `BuffSnapshot` messages (today's client ignores a snapshot for a mob, so
nothing breaks before the export); the pet's buff surface in `remote_pet.gd` for the target
frame; `CooldownTracker` and `hotbar.gd::_apply_cooldown`; `roll_cast_interrupt`;
`GroupManager::group_of` / `same_group`.

## Verification

- Server: `cargo test -p projectdawn-server` green after every step (today 250 unit, 67
  integration). New tests are written to fail on the old code first, and each exploit case
  runs as a client would: a cast at 0 HP, a nuke from beyond a leash, a forged Gate
  destination, a bind outside a safe area, a cast started inside the lockout, a weaker slow
  over a stronger one, a zero-damage interrupt, a DoT kill paying exactly once.
- Client: a headless probe per client change; `tools/check_spell_lockstep.gd` must report zero
  drift after every data edit.
- A `/code-review` pass after each of steps 0, 2, 3, 4 and 5.
- For you: one checklist per step in `docs/playtest_notes/`; the 30 m rows in
  `xp_eligibility_and_pet_levels_checklist.md` are rewritten for 200 m. Nothing is ticked
  without a playtest.
- After each step: merge the deploy branch into `feat/trade-window` and run its suite.
