# Say Range — 2026-10-27

A `/say` now carries 50 m from the speaker (user: "the volume of a conversation"), where it
used to reach the speaker's whole 3x3 AOI neighbourhood of 120 m cells (anyone 120 to 240 m
away, depending on where the speaker stood in the cell). The eating emote and the jump relay
reach the same 50 m. Server only; no export.

**Needs the redeploy** (server `build=` on the boot line). Two seats; `/loc` on each to read
the distance (the two positions' straight-line distance).

## Setup
- [x] Server on the R720 from this build (boot line `build=`, `dev_cmds=false`). notes: journal: `build="2157fd9" dev_cmds=false`, the 10-27 22:51 UTC boot.
- [x] Two seats in the open, `/loc` on both. notes: CHAT (char 15, account 2) and CHATTOO (char 16, account 1), 17:52 to 18:07 UTC on 2026-10-29.

## 1 — The reach
- [x] **Stand 40 m apart, `/say hello`** → the partner hears it. notes:
- [x] **Stand 60 m apart, `/say hello`** → the partner hears nothing; a `/shout` still arrives. notes:
- [x] **Walk back in to 45 m, `/say` again** → heard again. notes:

## 2 — The room follows
- [x] **At 40 m, eat a Bread Loaf** → the partner sees "Chomp, chomp, chomp..."; at 60 m they do not. notes:
- [x] **At 40 m, jump** → the partner sees the hop; at 60 m (still in view) they do not. notes: When my friends and i play games like this we use a "jump check" when we see someone in the distance but we arent sure if that person is our friend or not.  I would like for jump to be broadcasted further.  Let me know if this makes sense, and if  you want to work on it now or make note for future work. [Claude, 10-29: it makes sense, and the 50 m was my call on 10-27 when the say range went in (the relay used the say audience before and after). A jump is a thing you SEE, not hear: the cue should reach everyone the server already sends the jumper's position to (the view, 120 to 240 m), while the eating emote stays at the say range. Server only, a few lines; filed as its own To-Do entry, waiting on the go.]

## 3 — Regression
- [x] **`/shout`, `/ooc`, `/g` while grouped, `/t`** → unchanged: shout and OOC reach everyone, group the group, a tell its target. notes:
- [x] **Talk to an NPC from 10 m** → as before (the NPC gate is its own range). notes:

## Notes / observations
- (Claude, 10-29) Chat is not logged server-side, so the reach rows rest on the two screens; the journal corroborates the sitting around them: the two seats, the group forming for the `/g` row (`GroupAccept ... gid=2`, 18:06:51), two hand-eats behind the emote row (`UseConsumable applied ... bread_loaf`, 18:01:01 and 18:01:20).
- (Claude, 10-29) Seen in the journal ahead of their own checklists, all behaving: the Beast Master's warder respawned at owner-1 after each Level Up (level 9 at owner 10, 14 at 15); Claw Rake, Primal Instinct and Warder's Fury ran as server skills (`skill used`); Primal Bond's 40-point absorb soaked five boar hits to `reduced=0` and the sixth to 2; the group's first kill went round-robin to the partner and the owner's two loot tries were refused (`not your turn`); Warder's Mend and Spirit Mend healed the pet by their listed numbers.
