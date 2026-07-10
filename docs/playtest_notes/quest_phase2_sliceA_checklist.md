# Quest Phase 2 Slice A Playtest Checklist — 2026-07-09

Quest objective STATE moved server-side (PD_W0024). The server now counts quest kills itself
(`active_quests` table + per-kill `QuestProgress`), the journal is seeded from a server
`QuestSnapshot` on every login (survives relog AND server restart), turn-ins are rejected until
every objective is met (a forged `CompleteQuest` pays nothing), rejections print a visible
combat-log reason, and quests complete at the NPC turn-in (classic EQ: killing the last wolf
marks the quest "Ready", the reward pays when you return to the giver). The journal also grew
an Abandon Quest button.

**Build prerequisites (all three):**
- Re-export / reload Project_Dawn in Godot (the gdext_net.dll was rebuilt — restart the editor
  if it was open during the build).
- Rebuild + restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from
  `F:\Projects\server`, piped to `Tee-Object server.log`. Migration 0010 auto-applies on boot.
- Client and server MUST both be on PD_W0024 (a stale DLL fails the connect handshake).

| Quest | Server objective | Turn-in |
|---|---|---|
| wolf_threat (L1) | kill Wolf x5 | Aldric the Guard |
| rat_infestation (L1) | kill Rat x8 | Brom (dialogue NOT wired yet — slice D) |
| gnoll_raiders (L3) | kill Gnoll x8 | Brom (dialogue NOT wired yet — slice D) |
| rotfang_hunt (L5) | kill Rotfang x1 | Aldric the Guard |
| test_q1 (L1) | kill Wolf x5 | Test Panel "Complete Test Quest" button |

Diagnostics: in-game console (backtick) for client state; server.log anchors: `quest accepted`,
`quest progress` (none — progress has no log line; look for) `quest completed`,
`quest turn-in rejected`, `quest abandoned`, `quest accept rejected`.

## Setup
- [x] Re-export Project_Dawn (fresh gdext_net.dll picked up; Godot editor restarted)
- [x] Rebuild + restart server with `PD_DEV_CMDS=1` (watch boot log for migration 0010)
- [x] Two clients on separate accounts; one fresh/low-level character each

> **Known gotcha:** Brom is still a vendor-only NPC (his quest dialogue wires up in slice D),
> so rat_infestation / gnoll_raiders can only be accepted via… nothing. Test with wolf_threat
> (Aldric), rotfang_hunt (Aldric, needs L5), and test_q1 (Test Panel). Also: quests accepted
> BEFORE this build (old client-only journal) are gone — that's expected, they were never
> server-tracked.

## 1 — Accept + server-side counting (the headline)
- [x] **Talk to Aldric, accept The Wolf Threat** → quest appears in the journal (J);
  server.log shows `quest accepted char_id=… quest_id=wolf_threat`. notes:
- [x] **Kill a world Wolf (melee)** → journal ticks 1/5 WITHOUT any client-side counting
  (this is now the server's `QuestProgress`). notes:
- [x] **Kill a Wolf with a spell** → ticks the same. notes:
- [x] **Pet class: let the pet land the killing blow** → owner's objective ticks. notes:
- [x] **Kill the 5th wolf** → journal shows the quest as "(Ready)" in the list, the detail
  panel says "Ready to turn in: return to Aldric the Guard.", and a combat-log line announces
  it. The quest does NOT auto-complete and NO XP arrives yet. notes:

## 2 — NPC turn-in (classic EQ flow)
- [x] **Return to Aldric while Ready** → the "The wolves are dealt with." dialogue option is
  now visible (it is NOT visible before the 5th kill). notes:
- [x] **Click through the turn-in** → "Quest complete: The Wolf Threat!" in the combat log,
  300 XP arrives, quest moves to the Completed tab; server.log shows `quest completed …
  reward=300`. notes: When a player completes a quest it should say "You gained X quest experience!"  to ensure clarity.  Right now it says "You gained X party experience" which is not exactly accurate.
- [x] **Talk to Aldric again** → the turn-in option is gone (quest is COMPLETED); the offer
  does not reappear. notes:

## 3 — The journal survives relog + restart (the phase-2 headline fix)
- [x] **Accept wolf_threat on a fresh char, kill 2 wolves, log out, log back in** → the journal
  shows the quest at 2/5 (not wiped, not reset). notes:
- [x] **Stop the server, restart it, log in** → journal still shows 2/5. notes:
- [x] **Complete a quest, relog** → it's in the Completed tab after the relog. notes:  This works, the quest is listed in the "Completed" section.  Something off that I noticed:  In the Completed quest's description it shows "Objectives: Kill wolves near Valdis: 0/5"  I would like the completed quest's description to show "Objectives: Kill wolves near Valdis: 5/5".  Let me know if this makes sense.

## 4 — Visible rejections (no more silent nothing)
- [x] **Test Panel: Add Test Quest, then immediately Complete Test Quest (0 wolves killed)**
  → combat log prints "Slay the Infected Wolves: Quest objectives are not complete." and NO
  XP arrives; server.log shows `quest turn-in rejected — objectives incomplete`. notes:
- [x] **Kill 5 dev-spawned Wolves, then Complete Test Quest** → 300 XP arrives, `quest
  completed` in server.log. (Test Panel wolves count because DevSpawnMob mobs are real world
  mobs.) notes:
- [x] **Complete Test Quest AGAIN (same character)** → visible line "You have already
  completed this quest." and no XP. notes: This partially works.  Clicking "Add Test Quest" button displays line "Quest already in journal."   Clicking "Complete Test Quest" button does not display any message.
- [x] **On a character below L5, try to accept rotfang_hunt from Aldric** → the offer response
  appears (dialogue doesn't level-gate yet) but the accept is refused with a visible "You are
  too low level for this quest." line and the quest does NOT stay in the journal. notes: This works.  Sidenote:  dialog proceeds as if player accepted quest.  Would prefer if the NPC responded with the "You are not prepared for this endeavor, traveler.  Return to me when you are more powerful." instead of the display line in chat.  Let me know if this makes sense.

## 5 — Abandon
- [x] **Accept wolf_threat, kill 2 wolves, open the journal, Abandon Quest** → quest leaves
  the journal; combat log "Quest abandoned"; server.log `quest abandoned`. notes:
- [x] **Re-accept it from Aldric** → progress starts at 0/5 (abandon reset it). notes:
- [x] **Complete it, then abandon-and-redo hunting** → impossible: a completed quest offers no
  abandon and re-completing pays nothing (pay-once record is permanent). notes:

## 6 — Group split
- [x] **Two grouped clients, both with wolf_threat active, kill wolves together** → BOTH
  journals tick on every credited kill (each member gets private QuestProgress). notes: Tested in first server.log
- [ ] **A third ungrouped bystander with the quest watches a kill** → their journal does NOT
  tick (no credit for witnesses). notes: I didnt do this.  We can do it on the next play test.

## 7 — Regression: nearby behavior unchanged
- [x] **Kill XP still arrives** (XpGained line + bar move on every kill). notes:
- [x] **Test Panel "Level Up" / "Grant 250 XP"** still work (dev-gated). notes:
- [ ] **Test Room (no launcher): add test quest, kill 5 Test-Room wolves** → local counting
  still auto-completes it there (Test Room keeps the old flow; no server). notes: Test room (no launcher)?  Not sure what you are refering to.
- [x] **Loot, coins, bank, corpse loot** unaffected by the wire bump (spot-check one loot
  pickup + one bank open). notes: loot, coins, and corpse loot seem unaffected.  When i try to place items into bank they disapear.  To be more specific:
  
    Open bank window
    Left click "Items" tab
    Right click item in inventory for example Sinew or Iron Short Sword, item does not display in bank slots.
    Server log shows "bank store item..." message

    Open bank window
    Left click "items" tab
    Left click item in inventory
    move cursor to open bank slot
    left click open bank slot
    item deposits back into player's inventory, not bank

  Let me know if this test description is clear to you.


## Notes / observations
-
