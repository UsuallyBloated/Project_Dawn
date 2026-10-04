# Bind and Gate

**Drafted 2026-10-04.** Design only; nothing here is built. The decisions are gathered in §7.

Mandate, from the 2026-08-24 refusals playtest and the To-Do entry it produced ("Gate and the
Soul Binder use two different bind points"): binding at Sister Maelis and then casting Gate
says *"You have no bind point. Cast Bind Affinity first."* It was agreed that day to fix this
as its own sprint and not with a quick patch, because the bind system is what produced the
first tester's unwinnable death loop.

Why now: Bind Affinity sits on ten classes' level 1 spell bars and does nothing real, and Gate
is the first travel spell a Druid or Wizard gets. Friends will meet both in their first hour.

## 1. What is broken today (verified in source, 2026-10-04)

There are two bind points that have never met.

| | Set by | Read by | Lives in |
|---|---|---|---|
| **Server bind** | the Soul Binder (`BindAtCurrentLocation`, `handlers.rs:1012`) | Respawn (`handlers.rs:1104`) | `conn.bind`, persisted in `characters.bind_x/y/z` |
| **Client bind** | casting Bind Affinity (`spells.gd::_execute_bind`) | Gate (`spells.gd:154`, `_execute_port`) | `PlayerStats.bind_zone_path`, never sent anywhere |

Three consequences, each checked against the code:

- **Bind Affinity is refused by the server and obeyed by the client.** The server has the
  spell in `spells.toml` (`target_type = "BIND"`) but no arm for it, so the cast pre-flight
  answers "That magic has no effect here yet." and charges nothing. The client, in the same
  function that sends the cast, runs `_execute_bind` anyway and prints "You are now bound to
  ...". Two contradictory lines, and a bind that only the client believes in.
- **Gate is not in `spells.toml` at all**, so the server refuses it as an unknown spell. The
  client runs `_execute_port` regardless, which calls `ZoneLoader.travel_to`: it reloads the
  whole world scene and stands you at the zone's default entry. The server never moved you, so
  its next position update puts you back. A scene reload for nothing.
- **The client's bind is a zone and an entry name, not a position.** Even offline, Gate could
  only ever return you to a zone's default entry.

Succor and Evacuate (`port_entry_id = "safe"`) fail the same way as Gate. The four
`Teleport:` and three `Circle of` spells need zone scenes that do not exist and are out of
scope here.

## 2. Reference behavior

**EverQuest (classic, per the Project 1999 wiki).** A caster can bind *themselves* almost
anywhere: self-binds work everywhere except specific dungeon and planar zones. Binding
*another* character only works at allowable bind locations, which means cities and a few
designated outposts; that is how melee classes got bound, since they have no Bind Affinity of
their own. Gate "returns you to your bind point": all seven casting classes get it at level 4
or 5, with a 5 second cast and an 8 second recast. Succor (Druid) and Evacuate (Wizard) are
level 57 group escapes to "a relatively safe location in the current zone", with 9 second
casts, and Evacuate has a small chance of leaving someone behind.

**Star Wars Galaxies (pre-CU).** No bind spell and no Gate. You pay a fee at a **cloning
facility** to store your clone data there, and on death you wake at that facility; cloning at
the nearest facility instead carries penalties. The same building sells item insurance. The
SWG answer to "where do I come back" is a *paid town service*, not a class ability.

**What this game already took from each.** Sister Maelis, the Soul Binder, is the SWG shape:
a town service anyone can use. Bind Affinity and Gate are the EQ shape: a caster's privilege.
The two are meant to coexist, and the server's bind handler already says so in a comment
("the caster-class spell path will bind anywhere by design; THIS arm is the NPC service and
stays gated").

## 3. What exists to build on

Almost everything. This sprint is mostly wiring.

- **One persisted bind position**, `conn.bind`, loaded at login, written through
  `Outcome::BindIntent` and `db::set_bind_point`.
- **A teleport that works on a living player.** `handlers::send_teleport` plus `conn.pos =
  dest` is exactly what Respawn and a resurrection accept do today; the client's `Net`
  already snaps the local player on the `Teleport` message (PD_W0022), and the tick's own
  cell-crossing step sorts out who can now see whom.
- **Every cast gate.** A spell in `spells.toml` gets class and level checks, a server-enforced
  cast time, cancel on movement, interrupt rolls when hit, a server-side cooldown, and the
  one-cast-per-tick cap, with no new code. The 2026-10-02 pre-flight (`cast_target_refusal`)
  is where a refusal that costs nothing belongs.
- **The hate wipe.** The death sweep already removes a player from every mob's aggro and
  threat tables and clears the mob's target, and a mob with no target leashes home and heals
  to full (`entity.rs::tick_leash`).
- **Spawn positions, server-side** (`spawn_points::Spawner`, from `zone_camps.toml`). The
  largest aggro radius in the world today is 22 m, so the largest default leash is 44 m.

## 4. Design

### 4.1 One bind, owned by the server

`conn.bind` is the only bind point. Two things set it (the Soul Binder, Bind Affinity) and two
things read it (Respawn, Gate). The client keeps no bind of its own online; `PlayerStats.bind_*`
and `ZoneData.NON_BINDABLE_ZONES` become offline leftovers and retire with the rest of the solo
plumbing.

### 4.2 Bind Affinity

A new `BIND` arm in the cast resolver, with its checks in the pre-flight so a refused bind
costs nothing and rolls no skill-up:

- The caster binds **themselves** at the spot where they stand (decision D2 covers binding
  others).
- The spot must be bindable (decision D1). The recommended rule: **not within 60 m of any
  hostile spawn point**. Refusal line: "The magic will not anchor here."
- On success: `conn.bind` is set, persisted by the existing bind intent, and confirmed with the
  Soul Binder's line, "Your soul is bound to this place."
- Costs stay as authored: 30 mana, a 3 second cast, no cooldown. It rolls Alteration like any
  completed cast; mana rations that, as in EQ.

Why 60 m: it clears the largest aggro radius (22 m) and the largest leash (44 m) with room to
spare, so nobody can wake up naked inside a camp, which is the self-built version of the death
loop. It still leaves the caster's real perk intact: bind on the road near where you hunt and
your corpse run is a short one.

### 4.3 Gate

Gate joins `spells.toml` as the first `PORT` spell, with the client's numbers (50 mana, 5
second cast, 300 second cooldown, level 8). Two new optional fields carry what kind of port it
is: `port = "bind"` (Gate) or `port = "safe"` (§4.4), and `port_group`.

When the cast completes:

1. The destination is `conn.bind`, or the starter spawn when unbound (decision D3). It is
   never taken from the client; `CastSpell` carries a spell name and a target id and nothing
   else.
2. The caster is removed from every mob's aggro and threat tables and any mob targeting them
   drops the target, exactly as the death sweep does. Those mobs leash home and heal to full.
   Without this, whatever was chasing you would walk across the zone into town.
3. `conn.pos = dest` and a `Teleport` to the caster. Other players see them leave and arrive
   through the ordinary area-of-interest handling.
4. The caster's pet follows the rule in decision D4.

Gate stays what it is in EQ: an escape you have to *finish casting*. Five seconds under fire
with interrupt rolls is the cost, and the 300 second cooldown stops it being a commute.

### 4.4 Succor and Evacuate

Both are "port to this zone's safe point", single and group. The arm is the same as Gate's
with a different destination, so they are nearly free once Gate exists. Two things say wait
(decision D5):

- **There is no safe point.** In a one-zone world the only obvious one is the town, which
  makes Succor (level 12, 3 second cast, 60 second cooldown) a better Gate than Gate.
- **The numbers are leftovers.** EQ's versions are level 57 with 9 second casts. Ours are
  level 12 and 16 with 3 and 5 second casts, authored for the offline game. At those values
  every Druid is a town portal for the group from level 16.

Recommendation: build the arm so they are a data change later, and leave both out of
`spells.toml` until the content pass gives them real numbers and a safe point that is not the
town. Until then the client should refuse them honestly online ("isn't available online yet",
the tradeskill precedent) instead of reloading the scene.

### 4.5 The client's part

Small, and it rides an export:

- Online, `_apply_spell` must not run `_execute_port` or `_execute_bind`. The server does the
  work and its `Teleport` and chat line are the result.
- The "You have no bind point" pre-check goes (the server decides, per D3).
- Succor, Evacuate and the seven zone ports refuse honestly online before any mana is spent.

An old client against the new server is ugly but safe: it still reloads the scene on Gate, and
then the server's teleport puts the character where it really is. Position is the server's
either way.

## 5. Wire: nothing new for slice 1

The To-Do entry expected "a wire addition so the client learns its bind position (protocol
bump, gdext rebuild, re-export)". It turns out not to be needed. The client never has to
*know* where the bind is: the server moves the player with a message that already exists
(`Teleport`) and confirms a bind with a chat line that already exists.

So slice 1 needs **no protocol bump and no DLL rebuild**, and does not have to wait for the
trade window's deploy day. It ships like any server change (redeploy) plus an ordinary export.

A bind readout on the character sheet ("Bound near: ...") would need a small new message. That
is slice 3, optional, and can ride PD_W0028 if wanted.

## 6. The exploit ledger (write the tests from this list)

1. **The destination is the server's.** No client field can name where Gate goes. Test: bind
   at A, walk to B, Gate; the server's position is A.
2. **Wrong class or level cannot cast it.** The existing class/level gate; one test with a
   Warrior naming Gate.
3. **Cast time, movement and cooldown.** Existing gates. One Gate-specific test that a second
   Gate inside 300 seconds is refused and moves nobody.
4. **Binding where you should not.** Dead: refused. Inside the camp clearance: refused, mana
   untouched, no skill roll. A non-finite position cannot occur (the NaN move guard). Tests
   for the first two.
5. **The death loop.** The clearance rule plus the unbound fallback mean a respawn or a Gate
   never lands inside a camp's reach. Test: a bind attempt 30 m from a spawn point is refused;
   at 70 m it succeeds.
6. **No trains.** After Gate no mob holds the caster as a target or in its tables. Test: a
   mob aggros the caster, the caster Gates, the mob's target clears.
7. **No kills from safety.** A mob that loses its target leashes and heals to full, so "tag it,
   Gate out, let the damage finish it" pays nothing. XP shares already need 30 m and to be
   alive. Covered by 6 plus the existing leash; no new code.
8. **Skill-up farming.** Bind Affinity can be cast every 3 seconds for 30 mana. That is the
   same deal as any cheap spell, rationed by mana, and a refused bind rolls nothing because
   the refusal is in the pre-flight.
9. **The corpse run survives.** Gate moves the caster, never a corpse. A caster who bound near
   their hunting ground has a shorter run than a Warrior bound in town: intended, and limited
   by the clearance.
10. **Rate.** One `CastSpell` per caster per tick already holds; a teleport is bounded by the
    cooldown.
11. **Trade (when it lands).** A teleport takes the caster out of trade range, and the trade
    window's own range rule cancels it. One test on the trade branch when both exist.
12. **Evacuate (slice 2).** Only group members within range move; never a non-member, never a
    corpse. Tests when it is built.

Encumbrance is deliberately not a gate: a Wizard carrying the group's loot home is the class
doing its job.

## 7. Decisions for the user

Each has a recommendation; a one-word answer per line is enough.

- **D1. Where can Bind Affinity bind?**
  (a) Anywhere, as in EQ. (b) **Anywhere not within 60 m of a hostile spawn point**
  (recommended: keeps the perk, removes the self-built death loop). (c) Only beside a Soul
  Binder (which makes the spell pointless).
- **D2. Can a caster bind someone else?**
  (a) **Self only for now** (recommended: Sister Maelis already binds everyone for free, and
  binding another player somewhere bad is a grief tool). (b) Group members, and only beside a
  Soul Binder, as EQ limited it to cities.
- **D3. Gate with no bind point.**
  (a) **Goes to the starter spawn**, the same place Respawn would put you (recommended: one
  rule, and the spell never fails for a reason the player cannot see). (b) Refuses with "You
  have no bind point."
- **D4. What happens to your pet when you Gate?**
  (a) It always comes with you. (b) **It comes with you unless you parked it with guard or
  sit** (recommended: you parked it on purpose, and you can see it and call it now). (c) It is
  dismissed, as classic EQ lost pets on zoning.
- **D5. Succor and Evacuate.**
  (a) **Wait for the content pass** (recommended; see §4.4). (b) Build them now with the town
  as the safe point and today's numbers.
- **D6. Who gets Gate?** Today only Druid and Wizard have it, at level 8, while ten classes
  have Bind Affinity. EQ gives Gate to every caster at level 4 or 5. (a) Leave it as authored.
  (b) Give it to every class that has Bind Affinity. This is a content call and blocks
  nothing; the build is the same either way.

Not asked, noted: the Soul Binder is free today. SWG charged for it, and a small fee would
make Bind Affinity worth more. Worth a thought in the economy pass, not now.

## 8. Slices and cost

- **Slice 1: Bind Affinity and Gate.** Server: the `BIND` and `PORT` arms, the pre-flight
  cases, the clearance check, the hate wipe as a shared helper, Gate in `spells.toml`, and
  the ledger's tests. Client: stop acting locally online. About a day, one redeploy, one
  export, no protocol bump.
- **Slice 2: Succor and Evacuate.** A data change plus a safe point plus the group loop, after
  the content pass (D5).
- **Slice 3 (optional): a bind readout** on the character sheet, with a small new message on
  PD_W0028.

Out of scope: the seven zone ports (they need zones), and binding across zones (the multi-zone
epic owns that; `npcs.toml` already carries the warning that a position-only check collides
when zones overlap).

## Sources

- [Bind Affinity, Project 1999 Wiki](https://wiki.project1999.com/Bind_Affinity)
- [Gate, Project 1999 Wiki](https://wiki.project1999.com/Gate)
- [Succor, Project 1999 Wiki](https://wiki.project1999.com/Succor)
- [Evacuate, Project 1999 Wiki](https://wiki.project1999.com/Evacuate)
- [Cloning (Game Mechanics), SWGANH Wiki](http://wiki.swganh.org/index.php/Cloning_(Game_Mechanics))
- [Insurance (Game Mechanics), SWGANH Wiki](http://wiki.swganh.org/index.php/Insurance_(Game_Mechanics))
