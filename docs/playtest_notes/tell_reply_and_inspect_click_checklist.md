# Tell Reply, TAB Cycling and Right-Click Inspect Playtest Checklist — 2026-10-02

Three small chat and mouse additions, all client-only: `/r` answers the last person who sent
you a tell, TAB in the chat line walks everyone who has sent you one this session, and a
right-click on another player opens the inspect window. **Needs a fresh client export; the
server needs nothing** (the R720's current build already carries the inspect range gate).

| Thing | Effect | Notes |
|---|---|---|
| `/r <message>` (or `/reply`) | Sends a tell to the most recent tell sender | "No one has sent you a tell yet." when nobody has. The recipient is whoever is newest when you press Enter (EQ's classic mis-tell); use bare `/r` or TAB to see the name first |
| `/r` alone | Reopens the chat line holding `/tell <name> ` | Type the message and press Enter |
| TAB in the chat line | Empty line: `/tell <newest sender> `. On a tell: next older sender, message kept | Leaves `/say`, plain text, and a message to someone outside the list alone; never drops focus out of the line |
| Right-click a player | Targets them and opens inspect | 20 m client range, 30 m server backstop |

Tip: this needs two accounts in the world (two-boxing works). Client state shows in the in-game
console (backtick). Tells that never arrive: grep `server.log` for `ChatMessage` and the
target name.

## Setup
- [ ] Re-export Project_Dawn (confirm `[BuildStamp] stamped <sha>` in the export log)
- [ ] Two characters in the world, A and B, standing near each other. A third (C) helps §2 but is optional.

## 1 — `/r` reply
- [ ] **On A, before anyone has sent a tell, type `/r hello`** → "No one has sent you a tell yet." and nothing is sent. notes:
- [ ] **B sends `/tell A hi`; on A type `/r hello back`** → A sees "You -> B: hello back"; B sees "A tells you, 'hello back'". notes:
- [ ] **On A type `/r` alone and press Enter** → the chat line reopens already holding `/tell B ` with the caret at the end; type a message, press Enter, B receives it. notes:
- [ ] **`/reply` works the same as `/r`** → same result as the two rows above. notes:

## 2 — TAB cycles the senders
- [ ] **With one sender (B), press Enter then TAB on the empty line** → the line becomes `/tell B `. notes:
- [ ] **With two senders (B, then C most recently), press Enter then TAB, TAB, TAB** → `/tell C `, then `/tell B `, then back to `/tell C `. (Skip if no third character.) notes:
- [ ] **Type `/tell B where are you` and press TAB** → the name changes to the next sender and "where are you" stays. (With one sender the line simply stays as it is.) notes:
- [ ] **Type `/tell <someone who has never sent you a tell> hello` and press TAB** → nothing changes: a message written to someone else is never re-addressed. notes:
- [ ] **Type `/say hello` and press TAB** → nothing changes, and the chat line stays open and focused (before this build TAB dropped focus and hid the line). notes:
- [ ] **With the chat line closed, press TAB** → still cycles enemy targets as before. notes:

## 3 — Right-click inspect
- [ ] **Right-click (tap) B from a few metres away** → B becomes the target and the inspect window opens showing B's worn gear. notes:
- [ ] **Right-click B from beyond 20 m** → B is targeted, no window, "You are too far away to inspect B." notes:
- [ ] **Hold right-click and drag starting on B** → the camera turns; no inspect window. notes:
- [ ] **With the cursor on B, press and hold right, then left (the both-buttons run), then release both without moving the mouse** → you run forward; no inspect window on release. (Same for an NPC or a corpse under the cursor: no dialogue, no loot window.) notes:
- [ ] **`/inspect` with B targeted** → still works exactly as before. notes:
- [ ] **Left-click B** → targets only, no window. notes:

## 4 — Chat tab memory
- [ ] **With two chat windows docked as tabs, click the second tab, then close the game with the window X (not /camp) and relaunch** → the second tab is the one showing. notes:

## 5 — Regression: nearby behavior unchanged
- [ ] **`/tell B hi` and `/t B hi`** → both still send; `/tell B` with no message still prints the usage line. notes:
- [ ] **Right-click an NPC, a corpse and a loot bag** → talk / loot exactly as before. notes:
- [ ] **Log out and in on the same client as a different character, then press Enter, TAB** → the line stays empty: the previous character's tell partners are gone. (Only reachable once a return-to-lobby flow exists; today a relaunch clears it anyway. Mark `[-]` if not testable.) notes:

## Notes / observations
-
