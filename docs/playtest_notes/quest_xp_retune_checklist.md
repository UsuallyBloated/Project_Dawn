# Quest XP Re-tune (tier-based) — Playtest Checklist — 2026-07-06

Quest rewards used to be flat constants (80/150/350/600) that collapsed to a rounding error
against the new cubic XP curve. They're now a **difficulty tier** = a % of ONE level at the
quest's `level_req` — fixed to the quest's level, so it's a meaningful chunk at that level and
"gray" (negligible) to a high-level character. The knobs live in one table (`REWARD_TIERS` in
`data/quest_definitions.gd`).

| Tier | % of a level | Quests using it |
|---|---|---|
| trivial | 15% | rat_infestation (L1) |
| standard | 30% | wolf_threat (L1), gnoll_raiders (L3), test_q1 (Test Panel, L1) |
| hard | 50% | (none yet) |
| named | 80% | rotfang_hunt (L5) |

**Expected XP at turn-in** (fixed to the quest's `level_req`, NOT the turn-in-er's level):

| Quest | Lvl | Tier | Expected XP |
|---|---|---|---|
| rat_infestation | 1 | trivial | **150** |
| wolf_threat | 1 | standard | **300** |
| test_q1 (Test Panel) | 1 | standard | **300** |
| gnoll_raiders | 3 | standard | **5,700** |
| rotfang_hunt | 5 | named | **48,800** |

**Build:** re-export / reload the client only (no server rebuild, no DLL). The server can be
running or not — quest XP grants through the normal path either way.

## 1 — The formula fires (quick check, Test Panel)
- [x] Test Panel → **add the test quest**, then **complete it** → the XP bar jumps by **~300**
  (30% of the level-1 band = 1,000), and a "Quest complete" line logs. notes: Ogre warrior @ level 1 +250 xp

## 2 — "Gray" to a high-level character (the key behavior)
- [ ] Use Test Panel **"Level Up"** to reach ~level 20+, then complete the **level-1 test quest**
  again → it grants the **same ~300**, now a negligible sliver of your huge band. That's the
  intended EQ gray-quest behavior: a low quest is not an XP shortcut for a high-level char. notes: I cannot use the "Add test quest" more than once.  I receive "Quest already in journal" message in chat log.  This made me realize we need an "abandon quest" button for the player.

## 3 — Real quest turn-ins at-level (fuller check, needs the NPC flow)
- [ ] Accept + complete + turn in **rat_infestation** (8 rats, from Brom) → **~150 XP**. notes: Brom is only a merchant, i dont see a quest option.
- [x] **wolf_threat** (5 wolves, from Aldric) → **~300 XP**. notes:
- [x] (if you can reach them) **gnoll_raiders** (L3) → **~5,700**; **rotfang_hunt** (L5 boss) →
  **~48,800** (a big chunk of a level, as a named-boss quest should be). notes: Partially complete, Rotfang quest complete, I dont know where to find the "Gnoll Raiders" quest.

## 4 — Sanity
- [x] No script errors on quest completion; the XP bar / level update correctly, and a turn-in can
  still **level you** if the reward crosses a band. notes: I didnt notice any script errors. 
- [x] A low quest's reward feels **meaningful at its level** but **trivial at high level** — the
  whole point of the re-tune. notes:  This appears correct.

## Notes / observations
- Quests should complete and give credit when they are turned in.

  