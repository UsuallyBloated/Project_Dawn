# Quest Kill-Credit (online) — Playtest Checklist — 2026-07-07

**The bug:** in launcher (online) mode, `QuestManager.notify_kill` only fired for *local Test-Room*
enemies, never for server-driven kills, so a "kill N X" objective **never advanced** from real kills and
the quest could never complete naturally. (This is what you hit last pass.)

**The fix (wire PD_W0022 → PD_W0023):** the server now sends a **private `KillCredit { mob_name }`** to
whoever earned a kill, the solo killer, a pet's owner, or each online group member on the XP split, and the
client feeds it to `QuestManager.notify_kill` (the same call the local path uses). It's deliberately *not* the
public `EntityDied` broadcast, so a bystander who merely witnessed the death gets **no** credit.

**Build prerequisites (protocol bumped, so BOTH sides must update):**
- **Re-export / reload the client** so the rebuilt `gdext_net.dll` (PD_W0023) loads. Old clients won't talk to
  the new server.
- **Restart the server** (`$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`,
  `... | Tee-Object server.log`). Migration is untouched.

> **WHERE THE WOLVES COME FROM (new, same build):** the world has no authored Wolf camps, so the Test
> Panel spawn buttons now go **through the server** in launcher mode (`DevSpawnMob`, dev-gated). A
> panel-spawned Bandit/Grey Wolf/Skeleton/Gnoll is a REAL world creature — server combat, XP, loot, corpse,
> and quest kill credit — not a client-local puppet. **Requires `PD_DEV_CMDS=1` on the server** (same gate
> as Full Heal; without it the spawn button silently does nothing). One-shot spawns: they don't respawn.
> The wolf entry is named **"Grey Wolf"** (a bare "Wolf" is the Beast Master warder's reserved template
> name) — it still ticks "kill Wolf" objectives via the substring match. Named mobs stay client-local for
> now (a chat line says so) — don't use them for this test.
>
> **Also fixed by review before this playtest:** killing PETS or CHARMED mobs grants NO quest credit (a
> warder is literally named "Wolf" — PvP warder kills would have farmed the wolf quest). If you want, verify:
> kill a Beast Master's warder in PvP → your wolf objective does NOT advance.

Quickest quest to test with: Test Panel **add the test quest** (`test_q1`, "kill 5 Wolves") on a **fresh
character**, then **spawn Wolves from the Test Panel** and kill them.

## 1 — Solo melee kill-credit (the core fix)
- [x] With a "kill N Wolves" quest active, **melee a world Wolf to death** → the objective ticks **0/5 → 1/5**
  in the quest log (this did NOT happen before). notes:
- [x] Kill the rest → objective hits **5/5**, the quest **auto-completes**, and you get the **tier XP**
  (test_q1 = 300). notes:

## 2 — Solo spell kill-credit
- [ ] Kill a quest-target mob with a **spell** (not melee) → the objective advances the same way. notes:

## 3 — Pet kill-credit (pet class)
- [ ] On a pet class (Beast Master / Mage / Necro…), let your **pet land the killing blow** on a quest mob →
  **you** (the owner) get the objective credit, even though the pet did the killing. notes:

## 4 — Group kill-credit + witness exclusion
- [x] Two players **in a group**, both with the same kill quest: when **either** kills a target, **both**
  objectives advance (credit follows the XP split). notes: Only one member is getting kill credit for quest mobs.
- [x] A **third player NOT in the group**, standing right there, does **not** get credit for the kill (only
  participants, not witnesses). notes: Third player, outside of group, does not receive credit for quest mobs.

## 5 — Sanity
- [x] Killing a mob that is **not** a quest target does nothing to the quest (name match still works). notes:
- [x] No script errors; `server.log` shows the kill still awards XP normally alongside the credit. notes:  This appears to work, please double check.

---

# Round 2 additions — 2026-07-08 (same build/wire; re-export client + restart server)

## 6 — Group credit unification (re-test of section 4's finding)
The group XP split + quest credit now applies to ALL THREE kill methods (it was melee-only — that's why only
one member advanced when killing blows landed via spells).

> **Two deliberate behavior changes from review (expected, not bugs):**
> 1. A **grouped** caster/pet kill now SPLITS the XP (duo = 0.6x base each + both get quest credit) instead of
>    the killer keeping 1.0x and the groupmate getting nothing — matches melee + classic EQ. Solo unchanged.
> 2. Killing a **player's pet or a charmed mob** now awards **NOTHING** — no XP, no quest credit. (A warder
>    respawns free every ~15s; pet kills paying XP was an infinite leveling loop. And the warder is literally
>    named "Wolf".)
- [x] Two grouped players, same quest: a **melee** killing blow advances **both** objectives. notes:
- [x] Same, but the killing blow is a **spell** → **both** advance (this was the broken case). notes:
- [x] (pet class handy?) A **pet** killing blow → both group members advance. notes:
- [x] Grouped kills now show the split in server.log for spell kills too (`kill credit granted ... members=2`). notes:

## 7 — Quest XP exploit fix (server-authoritative rewards)
Quest rewards are now SERVER-authored: the client reports only a quest id (`CompleteQuest`); the server
computes the XP from its own `data/quests.toml` (mirror of QuestDefinitions) and records the completion —
**a quest pays once per character, ever**. The raw `GrantQuestXp` amount message is now DEV-gated (it's what
the Test Panel leveling buttons use).
- [x] Normal turn-in still works: complete the test quest → **300 XP** arrives, server.log shows
  `quest completed ... reward=300` (not `dev quest xp grant`). notes:  I believe this works.
  -> LOG-CONFIRMED: `quest completed char_id=99 quest_id=test_q1 reward=300` at 21:09:56; the grouped
  wolf_threat completions also show BOTH members paid 300 each (chars 99+100, 2ms apart).
- [x] **The relog farm is dead:** after completing the test quest, **log out and back in** (quest log wipes —
  known issue), re-add the test quest, complete it again → **NO XP** arrives; server.log shows
  `quest turn-in rejected — already completed`. notes: I'm not sure if this works.  Completed quests appears
  to clear when player logs out, please look into this.
  -> IT WORKED, LOG-CONFIRMED: your re-complete after the relog was REJECTED — `quest turn-in rejected —
  already completed char_id=99 quest_id=test_q1` at 21:10:33, 37s after the paid completion. What clears on
  logout is the client-side quest JOURNAL (known phase-2 issue); the SERVER's completed record persisted,
  which is exactly why the repeat paid nothing. Farm dead.
- [x] **Server restart:** completed quests survive it (repeat turn-in still rejected after a restart). notes: Looking good
  (power cut before this row — conveniently, the restart you're about to do IS this test: log the same char
  in, re-add + re-complete the test quest → should reject again)
- [x] Test Panel **"Level Up"** and **"Grant 250 XP"** still work (dev-gated; needs `PD_DEV_CMDS=1`).  notes:
  -> LOG-CONFIRMED: `dev quest xp grant` lines with the exact cubic bands (1000/19000/37000/61000) = the
  Level Up button climbing through the dev-gated path.

## Notes / observations
- Quests appear to be deleted from the player's log when the character logs out.  Please have a look into this.
  -> CONFIRMED (quest log is client-memory only in launcher mode). Proper fix = server-side quest objective
  tracking (phase 2, planned); the once-per-character server record above already kills the XP-farm half.