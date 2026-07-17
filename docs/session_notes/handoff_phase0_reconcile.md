# Handoff: Phase 0 — Reconcile the picture

**Next session's plan.** Roughly a day. Doc reconciliation plus one server constant.
Written 2026-07-16, after the schedule landed (`cc5f23d`). Retire this file when Phase 0 closes.

**Read first:** `docs/schedule.md` §3 Phase 0 (what this is) and §1 (why the dates are what they
are). The schedule is new; it did not exist before `cc5f23d`.

Everything below was verified against real source. Where a claim is **unverified**, it says so
in bold. Line numbers are current as of `cc5f23d`.

---

## The tick rule changed. Read it before ticking anything.

`CLAUDE.md:193`, Session workflow step 6. An item earns `[x]` only when a filled checklist in
`docs/playtest_notes/` shows it passing. Not on a green build, not on a commit. You propose the
tick and cite the checklist row; the user's playtest is the evidence.

There is **one** checkbox list: the `CLAUDE.md` To-Do. `docs/schedule.md` holds no boxes; its
§7 status table is a readout of what the To-Do already says.

> This gate caught an error in the first draft of this very handoff. It claimed the quest
> checklists were "filled and passing, tickable today." Counting the rows showed 4 open and 1
> failed. Don't take the summary below on trust either. Open the checklists.

---

## 1. Quest phase 2 is done; the To-Do still says it is open

`CLAUDE.md:297` lists **Quest system phase 2** as open with all six sub-items (journal wipes on
logout, completed set not synced, item rewards Test-Room-only, kill quests auto-complete, no
abandon button, Brom's dialogue unwired). All six shipped:

| Slice | Date | Client | Server |
|---|---|---|---|
| A (server objective tracking, PD_W0024) | 2026-07-10 | `31066c1` | `72bdcf1` |
| B (server-granted item rewards) | 2026-07-11 | `b2cf5cc` | `ea1db4c` |
| D (Brom's dialogue wired) | 2026-07-15 | `6076f7c` | n/a |

Evidence: `session_2026_07_09.md` (slice A), `session_2026_07_10.md` (slice B),
`session_2026_07_11_quest_sliceD.md` (slice D: *"Closes the last of the plan's 7 root problems"*).

**Per workflow step 6**, move the "what exists" note into `systems_overview.md`, not back into
the To-Do.

### Checklist state (verified by row count, do not skip this)

| Checklist | Done | Open | Failed |
|---|---|---|---|
| `quest_sliceD_brom_checklist.md` | 16 | 0 | 0 |
| `quest_phase2_sliceA_checklist.md` | 25 | 2 | 0 |
| `quest_phase2_sliceB_checklist.md` | 12 | 2 | **1** |

Each of the six sub-items has a passing row behind it, so the entry is very likely tickable. But
the leftovers are **not** all noise, and one is a live failure. Look before you tick:

- `sliceA:90` — ungrouped bystander gets no kill credit. Open because the tester deliberately
  deferred it ("I didnt do this. We can do it on the next play test."). Not a failure.
- `sliceA:96` — "Test Room (no launcher)" dev-path row. `session_2026_07_09.md` suggests
  clarifying or dropping it.
- `sliceB:27` — a **Setup** row ("a character that can accept wolf_threat"), unchecked. The test
  rows under it pass, so setup clearly happened. Bookkeeping miss.
- `sliceB:60` — `rat_infestation` XP-only-no-item case. Genuinely untested.
- `sliceB:35` — **`[-]` FAILED.** See item 2 below; this one is stale, but confirm it.

### One caveat

A "slice C" UX polish item was logged once and never picked up: refusing a too-low-level quest
inside the NPC's dialogue rather than via a chat line after the fact
(`session_2026_07_09.md:179-181`). It is **deliberately cut** from the friends build
(`docs/schedule.md` §6). Don't let it block ticking phase 2, and don't silently fold it in.

### Warning

`31df439` was a pass aimed *specifically* at stale `CLAUDE.md` claims. It fixed real ones (wire
protocol was ten versions behind at PD_W0014, autoload count, corpse epic status) and walked
straight past this entry. Do not assume the rest of the To-Do is clean because that commit ran.

---

## 2. Three stale checklists read as failures for work that shipped

**Not two. The third was found while double-checking this handoff.**

- **`corpse_slice3_checklist.md`** reads FAILED (Cleric res rejected, no Accept/Decline prompt,
  higher tiers erroring, only Paladin Reclaim Soul working). It is stale:
  `session_2026_06_25.md:72` reads *"**PLAYTESTED + COMMITTED 2026-06-26.** Two-client run
  confirmed the full machinery: all FOUR tiers..."*. **Verified.** Annotate it; do not re-open
  the work.

- **`quest_phase2_sliceB_checklist.md:35`** is `[-]` FAILED with the note: *"Rotfang appears to
  need an update. killing the enemy that is spawned in by the dev panel does not grant kill
  credit for the quest. Also Rotfang drops the old floating golden orb."*
  Both of those specific complaints were closed by `5ae6808` (dev panel, 2026-07-16):
  `session_2026_07_11_dev_panel.md:65` records *"Rat and Rotfang full quest loops complete
  (`rat_infestation` reward 150, `rotfang_hunt` reward ...)"*. **Verified.**
  **But do not blind-annotate.** The row's actual expectation is that a **Hunter's Medal**
  (STR +2, CON +2) lands on turn-in, and the dev-panel note only evidences kill credit and the
  XP reward, not the item. **Re-test this row rather than ticking it from the note.**

- **`pet_pvp_inheritance_checklist.md:30-31`** reads *"melee and frost bolt do damage, but
  Inferno does not do damage"* / *"Frost Bolt, but not Inferno"*. **Line numbers verified; the
  claim that it is stale is NOT.** It is *probably* closed by the same-day 2026-06-11 AOE
  pet-PvP fix, but nobody has checked the code. **Verify in source before annotating.** If it is
  still real, this is a live AOE bug, not a stale doc, and it does not belong in Phase 0.

---

## 3. Raise the player-corpse decay timer

> **READ THIS BEFORE YOU GREP.** There are **two** constants named `CORPSE_LINGER_SECS` in the
> server, with different values and unrelated meanings. Grepping the name returns both.

| Constant | Value | Means |
|---|---|---|
| `world/corpses.rs:25` | `300.0` | **Player corpse decay. This is the one to raise.** |
| `world/mod.rs:97` | `5.0` | How long a dead **enemy** holds at its death position before `EntityDespawn`. **Do not touch.** |

They coexist because the corpse epic (June) added a second constant in a new module beside the
older Track 5 one (May). `tick.rs` disambiguates by path: `tick.rs:7101` uses the bare import
(the enemy one), `tick.rs:7903` uses the fully-qualified `super::corpses::CORPSE_LINGER_SECS`
(the player one). Changing the wrong one silently breaks mob despawn timing and does nothing for
corpses. `CLAUDE.md` is precise about this and says `corpses::CORPSE_LINGER_SECS`; casual
references elsewhere are not.

Tests are safe: `world_two_clients.rs:817` and `:908` refer to the **enemy** constant
("`EntityDespawn` arrives after the corpse linger (CORPSE_LINGER_SECS = 5 s server-side)"), so
raising `corpses.rs:25` will not break them. **Verified.**

**The value is a design call. Ask the user.** EQ used tens of minutes to days. `CLAUDE.md`
already flags this as needing a production raise; the schedule's argument is only about *when*.
At 5 minutes, a friend who dies deep and cannot run back loses their gear permanently, on day
one. That is a first-friend problem, not a launch problem.

Server change, so it wants a real playtest before ticking.

**Worth raising with the user separately:** the duplicate constant name is a latent trap
regardless of this task. A rename (`ENEMY_DESPAWN_LINGER_SECS`?) is not Phase 0 scope, but it is
cheap and it will bite someone eventually.

---

## 4. Give the schedule's orphans a home in the To-Do

`docs/schedule.md` sequences these, but they have **no To-Do entry at all**. Under the one-home
rule they have nowhere to be ticked, and their absence is exactly why the keystone stayed
invisible until someone went looking.

### Per-account `is_gm` (add under Security / exploits, `CLAUDE.md:307`)

**This is the keystone of the entire schedule.** `is_dev` is process-global (`PD_DEV_CMDS`), so a
shared friends server is all-or-nothing: either every connected player gets `/heal`, dev spawn
and instant levels, or you lose your own tools during the playtest you are hosting. The
`accounts.is_gm` column already exists and is returned at login; it is simply never plumbed into
`PerConnection`. See `docs/security/exploit_audit_2026-07-08.md`, the "Intentional dev tooling"
operational caveat, which names this directly.

### Hosting / deployment (no category for this exists in the To-Do)

Phase 2 of the schedule: deploy target, netcode key handling, production env without
`PD_DEV_CMDS`, client build pointed at a real host, refresh `README_FOR_TESTERS.md` (it predates
about ten weeks of work). This is the schedule's highest-risk phase precisely because nothing in
the repo's history is a deployment.

### Four open playtest bugs

- **Bank Items-tab does not live-refresh on deposit.** Items appear to vanish. The server stores
  them correctly and they return on relog, so nothing is lost, but no tester will believe that.
  Highest perceived severity on the list. Client-side `BankWindow` refresh.
- **Unclean-kill relogin was not refused.** `banker_slice2_checklist.md:54`: the row is ticked
  `[x]` but its own note reads *"Killed A's client, then immediately logged back in
  successfully"*, which contradicts the row's stated expectation and the design. **Verified.**
  Security-adjacent (this guard blocks the Lineage II force-off pattern). Re-test before fixing;
  it may not reproduce.
- **Bags open on left-click instead of right-click.** `banker_slice2_checklist.md:57`. Untriaged.
  The tester's own guess is that these are stale pre-grammar bags.
- **Named mobs lost enrage and guaranteed drops.** Client-only in `named_mob_definitions.gd`,
  no server side, so every named mob is currently a generic mob wearing a name. Already listed
  as an open follow-up in `session_2026_07_11_dev_panel.md:79`.

---

## Scope

Phase 0 is doc reconciliation plus one server constant. **Do not start Phase 1** (the exploit
gate: `is_gm`, swing-rate limit, Respawn dead-check, cast class/level gate, weapon_path, login
rate limiting, attack-while-seated). It is its own two-week phase and wants its own playtest.

## If Phase 0 closes

Update §7 Status in `docs/schedule.md` **and** the matching row in `docs/schedule.html`, then
republish the Artifact **passing the URL recorded at the top of `docs/schedule.md`**. Publishing
without it mints a new link and the one already shared with a reviewer goes stale.

## Practical

- Use `git commit -F <file>` for the commit message. A PowerShell here-string mangles anything
  containing a `;` (the fragments get read as pathspecs). Hit this on `cc5f23d`.
- The **doc-sweeper** subagent (`.claude/agents/`) is cheap for "where did we document X" sweeps.
  Don't burn the main model on it. But verify what it returns: two of its line-number claims fed
  the first draft of this handoff, and while both happened to be exact, its summary of the quest
  checklists as clean was wrong.
