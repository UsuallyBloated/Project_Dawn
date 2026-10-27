# Say Range — 2026-10-27

A `/say` now carries 50 m from the speaker (user: "the volume of a conversation"), where it
used to reach the speaker's whole 3x3 AOI neighbourhood of 120 m cells (anyone 120 to 240 m
away, depending on where the speaker stood in the cell). The eating emote and the jump relay
reach the same 50 m. Server only; no export.

**Needs the redeploy** (server `build=` on the boot line). Two seats; `/loc` on each to read
the distance (the two positions' straight-line distance).

## Setup
- [ ] Server on the R720 from this build (boot line `build=`, `dev_cmds=false`). notes:
- [ ] Two seats in the open, `/loc` on both. notes:

## 1 — The reach
- [ ] **Stand 40 m apart, `/say hello`** → the partner hears it. notes:
- [ ] **Stand 60 m apart, `/say hello`** → the partner hears nothing; a `/shout` still arrives. notes:
- [ ] **Walk back in to 45 m, `/say` again** → heard again. notes:

## 2 — The room follows
- [ ] **At 40 m, eat a Bread Loaf** → the partner sees "Chomp, chomp, chomp..."; at 60 m they do not. notes:
- [ ] **At 40 m, jump** → the partner sees the hop; at 60 m (still in view) they do not. notes:

## 3 — Regression
- [ ] **`/shout`, `/ooc`, `/g` while grouped, `/t`** → unchanged: shout and OOC reach everyone, group the group, a tell its target. notes:
- [ ] **Talk to an NPC from 10 m** → as before (the NPC gate is its own range). notes:

## Notes / observations
-
