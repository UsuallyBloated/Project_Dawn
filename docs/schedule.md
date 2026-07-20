# Project Dawn: Schedule to a Playable Friends Build

**Target:** a small group of trusted friends can log in from their own homes, group up,
level, die, corpse-run, and quest for an evening without hitting a wall or breaking the game.

**Created:** 2026-07-16. **Target date:** 2026-09-14 (roughly 8.5 weeks).
**Working assumption:** ~30 hrs/week.

### The readable copy

`docs/schedule.html`, right next to this file, is a rendered version for reviewers who'd rather
not read raw markdown. Open it in any browser (double-click, or "Open with" a browser). It's a
standalone page with everything inlined, so it works offline and can be emailed as-is.

This markdown file is canonical; the HTML is a rendering of it. If they disagree, this one wins,
so update `schedule.html` in the same pass whenever you change the plan here.

### How this doc is tracked

**This doc tracks phases. `CLAUDE.md`'s To-Do tracks items.** One home per fact, so the two
can't drift against each other — which is the exact failure Phase 0 exists to clean up.

- The bullets under each phase are the **plan** for that phase, not a checklist. Their `[ ]`
  status lives in the `CLAUDE.md` To-Do.
- **§7 Status is the tick target.** A phase closes when its To-Do items are ticked.
- Nothing gets ticked in either place until a filled checklist in `docs/playtest_notes/` shows
  it passing. See the gate in `CLAUDE.md` → **Session workflow** step 6. Built is not done.
- Time-boxed to the 2026-09-14 target. When it lands, fold anything unfinished back into the
  To-Do and retire this doc rather than letting it rot.

Completed detail moves to `session_notes/`, the same as everything else.

> Scope note: "playable for friends" is not "public alpha." The difference is trust. Friends
> will not fuzz the wire protocol, so the exploit work here is about the gates a *curious*
> player trips and the ones that decide whether the server can be exposed at all. Public
> alpha is a separate, much longer target.

---

## 1. Where the estimates come from

These are not guesses. Every epic below is bounded by its own dated commits across both repos,
first commit to last, over the most recent month. Each is a cross-wire feature: server, client,
playtest, review pass.

| Epic | Dates | Calendar days |
|---|---|---|
| Group loot rights + coin drops | Jun 15 to Jun 17 | 3 |
| Banker NPC (2 slices) | Jun 17 to Jun 19 | 3 |
| Camp + linkdead (2 slices) | Jun 19 to Jun 20 | 2 |
| Corpse epic (slices 0 to 3 + orb unification) | Jun 22 to Jun 26 | 5 |
| EQ-authentic XP leveling overhaul | Jun 26 | 1 |
| Quest phase 1 (kill credit + server rewards) | Jul 6 to Jul 8 | 3 |
| Quest phase 2 (slices A, B, D) | Jul 9 to Jul 15 | 7 |

**Measured: 7 epics in 4.3 weeks (Jun 15 to Jul 15).** Typical span 3 days, longest 7.

Deliberately the recent stretch, not a ten-week average, because recent work predicts better.
Two large May efforts are excluded on purpose: the network foundation (tracks 1 to 22, May 5 to
May 28) was the initial build-out and is not steady-state work, and the currency/encumbrance
work (May 21 to Jun 13) interleaved with other tracks throughout, so it cannot be honestly
bounded and would only distort the average.

**Planning number used below: each phase bundles 1 to 2 epics into a 2-week window**, roughly
double the measured pace. The slack is intentional: the history also contains real gaps of 3 and
10 days (Jul 11 to Jul 14, and Jun 26 to Jul 6), and pretending those will not recur is how
schedules break.

---

## 2. The critical path

Only one chain actually has to happen in order. Everything else can move.

1. **Per-account `is_gm`** gates whether a shared server can run at all with your tools intact.
2. **Hosting** cannot safely happen until 1 is done.
3. **The first outside friend session** cannot happen until 2 is done.
4. **The fix list** is largely written by what 3 surfaces.
5. **Opening to the whole group** waits on 4.

Content authoring (Phase 4) is the one big block that runs *parallel* to this chain. It is
authoring, not engineering, and it does not depend on the server being exposed.

---

## 3. Phases

### Phase 0: Reconcile the picture (Jul 16 to Jul 17, ~1 day)

Cheap, and it means the rest of the schedule starts from something true.

> Most of this was already done by `31df439` (2026-07-16, "fix stale CLAUDE.md claims"), which
> corrected the wire protocol version (PD_W0014 to PD_W0024, ten versions behind), the autoload
> count, and the corpse epic's status, and closed the client-local-leveling drift note. What
> follows is the remainder it did not reach.

- Update CLAUDE.md: **quest phase 2 is done** (slices A, B, D). `31df439` did not touch this
      entry; `CLAUDE.md:270` still lists all six sub-items as open. Move the "what exists" note
      into `systems_overview.md`, per the session workflow.
- Annotate **three** stale playtest checklists so the next reader does not re-open closed work:
      `corpse_slice3_checklist.md` reads as failed but was playtested clean and committed
      2026-06-26 (verified); `quest_phase2_sliceB_checklist.md:35` is a failed row whose specific
      complaints (no Rotfang kill credit, golden orb) were closed by `5ae6808`, though its actual
      expectation (the Hunter's Medal item) needs a re-test, not a blind tick;
      `pet_pvp_inheritance_checklist.md:30-31` shows an Inferno failure that the same-day AOE fix
      probably closed (verify in source, do not assume: if real it is a live bug, not a stale doc).
- Raise `corpses::CORPSE_LINGER_SECS` off the 300s test value (`world/corpses.rs:25`).
      `31df439` already flagged this in the to-do as needing a production raise; the argument here
      is only about *when*. It is not a production-launch concern, it is a first-friend concern.
      See §5. **Note the trap:** a second, unrelated `CORPSE_LINGER_SECS` (`world/mod.rs:97`,
      `5.0`) controls dead-*enemy* despawn. Grepping the name returns both. Changing the wrong one
      breaks mob despawn and does nothing for corpses.
- **Fold this schedule's orphans into the To-Do.** Several things below have no To-Do entry at
      all today, so under the one-home rule they have nowhere to be ticked: per-account `is_gm`
      (Phase 1), the whole of hosting/deployment (Phase 2, which has no category in the To-Do at
      all), and four playtest bugs (Phase 3: bank Items-tab refresh, unclean-kill relogin, bags
      opening on left-click, named-mob enrage and guaranteed drops). Their absence is why the
      keystone was invisible in the first place.

**Done means:** the to-do list matches reality, and every item this schedule sequences has a
row there to be ticked.

---

### Phase 1: Close the exploit gate (Jul 20 to Jul 31, 2 weeks)

The phase that decides whether anyone can be invited. Findings numbered per
`docs/security/exploit_audit_2026-07-08.md`.

- **Per-account `is_gm`** *(keystone, not currently on the to-do list)*. Thread the existing
      `accounts.is_gm` column from the signed world token into `PerConnection` and gate the dev
      commands on it instead of the process-wide `PD_DEV_CMDS`. This is what lets you keep
      `/heal`, spawn-mob, and Level Up on a server your friends are playing on.
- **Respawn dead-check** (finding 3, High). Gate on `conn.hp <= 0.0`. Small.
- **Melee swing-rate limit** (finding 2, High). Per-connection `next_swing_at` from the
      equipped weapon's delay. Small to medium.
- **CastSpell class/level gate** (finding 4, Medium). Apply the check the resurrection arm
      already does to the SELF / ALLY / ENEMY / AOE arms. Small.
- **`Attack` weapon_path** (finding 5, Medium). Read the server's tracked equipment instead
      of trusting the wire field. Small to medium.
- **Login rate limiting + auth timing equalization** (findings 6 and 9). Matters the moment
      the auth socket faces the internet. Medium.
- **Attack while seated.** Require standing to swing, and check whether the sit regen bonus
      still applies mid-fight. If it does, this is free in-combat regen, not an animation bug.

**Done means:** findings 2 through 6 and 9 are closed, `is_gm` is live, and the audit's threat
list has been re-run against the changed code.

**Risk:** low. These are small, well-understood server-side gates with a findings doc that
already names the file and line for each. `is_gm` is the only one that touches multiple layers.

---

### Phase 2: Host it, invite one person (Aug 3 to Aug 7, 1 week)

The riskiest estimate in this document, because it is the only phase with **no velocity data
behind it**. Nothing in ten weeks of history is a deployment. Everything so far has run on
localhost.

- Pick and stand up a deploy target (VPS, or port-forward from the dev box).
- Netcode private key handling for a real host (the server refuses to boot without it).
- Production env: `PD_DEV_CMDS` off, `is_gm` on your account only.
- Client build pointed at the real host; refresh `README_FOR_TESTERS.md` (it predates ~10
      weeks of work).
- Confirm the in-game bug-report button still routes somewhere you read.
- **One friend, one session.**

**Done means:** somebody who is not you, from a machine that is not yours, made an account,
made a character, killed something, and logged out clean.

**Risk: high on time, low on difficulty.** Deployment surprises are the norm. If this slips a
week, the whole schedule slips a week. It is also the phase most worth doing *early and badly*:
a rough hosted server that one friend can reach is worth more than a polished one nobody has
touched.

---

### Phase 3: Stop it eating their things (Aug 10 to Aug 21, 2 weeks)

Two categories: bugs that destroy or appear to destroy player property, and bugs that make a
new player think the game is broken. The first category is what loses you a tester permanently.

- **Bank Items-tab does not live-refresh on deposit.** A deposited item visibly *vanishes*.
      The server stores it correctly and it returns on relog, so nothing is actually lost, but
      no tester will believe that. Highest perceived severity on the list. Client-side
      `BankWindow` refresh.
- **Unclean-kill relogin was not refused** (`banker_slice2_checklist.md:54`). The tester
      killed their client and logged straight back in. The doc contradicts itself here and never
      reconciles. Security-adjacent: this guard is what blocks the Lineage II force-off pattern.
      Re-test first, it may not reproduce.
- **Atomic cross-store transfers** (finding 8, Low). Fold each bank/vendor transfer's two
      writes into one transaction, mirroring `db::apply_corpse_loot`.
- **Bags open on left-click instead of right-click.** Untriaged. The tester's guess is that
      these are stale pre-grammar bags.
- **Named mobs lost enrage and guaranteed drops.** Both live only in client-side
      `named_mob_definitions.gd` with no server side, so every named mob is currently a generic
      mob wearing a name. Rotfang's guaranteed fang did not drop in the last playtest.
- Whatever the Phase 2 session surfaces. **Leave room here.** It will find things.

**Done means:** nothing loses items, nothing appears to lose items, and a first-time player
does not hit an obvious "this is broken" moment in their first hour.

---

### Phase 4: An evening's worth of game (Aug 24 to Sep 11, 3 weeks, parallel-safe)

The mechanics are further along than the content. Four quests and one zone is maybe ninety
minutes before a friend runs dry. This phase is the difference between "I saw your game" and
"we played your game on Saturday."

- **Content: quests and mobs.** The quest system is fully server-authoritative now (journal
      persistence, NPC turn-in, item rewards, once-per-character dedup). It is authoring capacity
      that is missing, not engineering. This is the largest and most open-ended item here.
- **Respawn at bind / Soul Binder NPC.** Currently respawn honors the *client's*
      `PlayerStats.bind_zone_path`, and `BindAtCurrentLocation` is an inert wire variant with no
      server handler. With corpse runs as the death model, where you respawn matters a lot.
- **Tune `CORPSE_LINGER_SECS` for production** properly (Phase 0 is the emergency raise; this
      is the considered value).
- **Minimal sound pass.** See the open question in §4. Not yet committed to.

**Done means:** two friends can group and play three hours without running out of things to do.

---

### Phase 5: Open the door (Sep 14 onward)

- Full friend group.
- A real feedback loop: the playtest checklist format in `docs/playtest_notes/` already works
      well for this, and the per-row `notes:` hooks are what make a "didn't work" triage-able.

---

## 4. Open question (needs a decision, not blocking yet)

**Sound.** There is currently none: no combat, no spell, no ambient, no music. To a returning
developer this is invisible. To a friend logging in for the first time, total silence is one of
the loudest things about the build. But the to-do item as written ("combat/spell/ambient/music")
is a multi-week subsystem, not a polish task.

The middle path is a *minimal* pass: swing, hit, spell cast, death, and one ambient loop. Maybe
three days rather than three weeks. That is what Phase 4 assumes. If you would rather ship the
friends build silent and treat audio as its own epic afterward, Phase 4 shortens by roughly half
a week and the target date pulls in.

---

## 5. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Hosting (Phase 2) has no prior art in this project** | Slips the whole chain | Start it early and accept a rough first version. It is the only phase with no velocity data. |
| **`CORPSE_LINGER_SECS` is 300s** | Loses a tester permanently, on their first death | One-line fix, pulled forward into Phase 0. EQ used tens of minutes to days. At 5 minutes, a friend who dies in a dungeon and cannot run back in time loses their gear forever, on day one. |
| **Content (Phase 4) is open-ended** | Target date | It is the one phase that can run parallel to the critical path, so it absorbs slack from the others rather than adding to it. |
| **Historical gaps of 3 to 10 days** | ~1 week of drift per 6 | Already priced in: the 2-week phase windows are roughly double the measured epic pace. |
| **`world_two_clients.rs` integration tests are timing-flaky** | Noise during Phase 1 | Known, documented in `server/docs/flaky_integration_tests.md`. Re-run individually before blaming a change. |

---

## 6. Explicitly cut from this target

Naming these is the point of the exercise. All are real work; none of them decide whether four
friends can play on a Saturday.

**Systems:** bard song rework, two-handed cleave, mount system completion, faction system,
weather, water and swimming, doors and locks, guild system, LFG flag, dueling, auction/bazaar,
player inspect completion, language system wiring, EQ-style food/water regen gating.

**Death and corpse follow-ups:** res-sickness, corpse auto-re-equip on loot, per-creature corpse
models.

**Tradeskills:** consumables, bookbinding, clockwork engineering prestige.

**Content and art:** race expansion (Aerathi, Vesperin, Sylphari), remaining per-race models,
player portrait art, map/minimap, zone transition effects, UI theming pass.

**Quest polish:** the "slice C" item, refusing a too-low-level quest inside the NPC's dialogue
rather than via a chat line after the fact.

---

## 7. Status

| Phase | Window | Status |
|---|---|---|
| 0. Reconcile | Jul 16 to Jul 17 | **Done (2026-07-17)** — doc reconciliation complete; `CORPSE_LINGER_SECS` raised to 7 days (user-accepted, pure value change); duplicate-name trap resolved via rename |
| 1. Exploit gate | Jul 20 to Jul 31 | **In progress** — keystone (`is_gm`) done 07-19; Respawn dead-check done + playtested 07-20. Remaining: attack-while-seated, cast class/level gate, weapon_path, swing-rate, login rate-limit |
| 2. Host + first friend | Aug 3 to Aug 7 | Not started |
| 3. Stop it eating things | Aug 10 to Aug 21 | Not started |
| 4. An evening's worth | Aug 24 to Sep 11 | Not started |
| 5. Open the door | Sep 14 onward | Not started |
