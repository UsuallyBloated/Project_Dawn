# The 4 km Starting Zone Playtest Checklist — 2026-11-13

The starting zone is rebuilt at 4 x 4 km from the composition sketches
(`docs/design/starting_area_comp_sketches.html`): the same 20 camps and 54 spawns, about ten
times further apart, on new ground (the western hills, the Greywood ridge and its pass, the
Wraith Gate plateau, mountains round the edge), with a walled town, a planted wood and a set
piece at every camp. This sheet verifies that the ground the client draws is the ground the
server stands everyone on, that every camp is where its scenery is, and that nothing about the
bigger world opened a hole.

**Build prerequisite: both sides move together.** The server from `feat/zone-4km` (boot line
`terrain=400x400 cells of 10 m, floor 0, hash 35a3f1a15f4f`) and a client export from
`feat/zone-4km`. An older client against this server walks on the old 400 m ground while the
server stands it on the new one.

| Place | Level | Where (x east, z north) | Run from the town |
|---|---|---|---|
| Bonepile | 1 | (-220, 120) | 50 s |
| Wolf Run | 1 | (280, -200) | 1 min 10 s |
| Rat Warrens | 2 | (150, 120) | 40 s |
| Shallow Graves | 3 | (400, 330) | 1 min 45 s |
| Gnoll Raider Camp | 3 | (560, 70) | 1 min 50 s |
| Boar Thicket | 4 | (-420, -340) | 1 min 50 s |
| Bat Hollow, Sable's roost | 4 | (-130, 540), (-180, 640) | 1 min 50 s |
| Bandit Outpost | 5 | (-600, 640) | 2 min 55 s |
| Rotfang's Den | 5 | (60, -800) | 2 min 40 s |
| Festering Mound | 6 | (640, -620) | 3 min |
| Spider Copse, the Crawler's burrow | 7 | (1120, 60), (1210, -10) | 3 min 45 s |
| The Broken Crypt | 9 | (20, 1250) | 4 min 10 s |
| Gnoll War Camp, Greth's tent | 10 | (20, -1500), (40, -1620) | 5 min |
| The Sunken Barrow, the Undying | 12 | (-1480, -60), (-1560, -60) | 5 min |
| Ossuary | 14 | (-1740, 90) | 5 min 50 s |
| Wraith Gate | 16 | (1570, -40), on the plateau | 5 min 15 s |

Tip: `/loc` prints where you stand, paste-ready. A GM's Test Panel has Fling 5 m and 20 m for
the fall rows. Server journal anchors: `terrain=` on the boot line, `world health` (its
`slope_refusals` should stay 0 for honest play on floors), `Attack rejected`, `kill credit
granted`.

## Setup
- [ ] Server built from `feat/zone-4km` and restarted; the boot line reads `dev_cmds=false`
  and `terrain=400x400 cells of 10 m, floor 0, hash 35a3f1a15f4f`. notes:
- [ ] Client exported from `feat/zone-4km`; the login screen shows the stamp, no `-debug`. notes:
- [ ] One GM account and one plain account, both with a character past level 5 (or the GM's
  Level Up). notes:

> **Known gotcha:** the walls, the trees and every set piece are scenery. You walk through
> them. That is deliberate for now (the server knows the ground, not what stands on it); a row
> below is there to confirm it, not to report it.

## 1 — The town and the first minute
- [ ] **Log in** → you stand in the town square, the six NPCs in their row in front of you,
  the forge behind Hadrik, the shrine stone behind Sister Maelis, the watchtower with the
  green banner to the east. The world loads in a few seconds at most. notes:
- [ ] **Talk to each NPC, buy and sell, bank, bind** → all as before (their positions did not
  move). notes:
- [ ] **Walk out of each of the four gates** → the road leaves each gate; no rubber-banding,
  no snapping back as you pass through a gate or a wall. notes:
- [ ] **Walk straight through a wall, a house and a tree on purpose** → you pass through,
  smoothly, and your partner sees you do the same (no jitter on their screen). notes:
- [ ] **Stand at the east gate at sunset** (the Test Panel's clock, or wait) → the sun sets
  over the western hills, behind the town from the east road. notes:

## 2 — The ground is the server's ground
- [ ] **Run the west road to the Sunken Barrow** (5 min) → you climb the hills and descend
  into the pit without sinking into the ground or floating over it; your partner sees you on
  the ground the whole way. notes:
- [ ] **In the pit, fight a Barrow Zombie** → it stands on the pit's floor, reaches you, and
  follows you up the pit's wall if you back up it. notes:
- [ ] **Walk at the Greywood ridge's face** (anywhere along z = 790) → you stop at its foot;
  holding forward does nothing; no climbing by zigzag or by jumping. notes:
- [ ] **Take the pass north** (x = 0, z = 790 to 1010) → a flat road between two walls, into
  the wood; the walls cannot be climbed from inside either. notes:
- [ ] **Climb the Wraith Gate plateau by its north ramp** (from about (1700, 470)) → a steady
  climb to the top; the arch stands at the cliff's lip with its light. notes:
- [ ] **GM: walk off the plateau's west cliff** (60 m) → you die; "You hit the ground hard"
  for your whole health; the corpse lies at the cliff's foot; loot it back. notes:
- [ ] **Walk at the mountains on any edge** → you stop at their foot, about 70 m from the
  plate's edge; nobody gets over or out. notes:
- [ ] **Stand under a face and cast at a mob on top of it out of sight** (the plateau's lip
  from its foot) → "You cannot see your target.", no mana spent. notes:

## 3 — Every camp is where its scenery is
One visit each: the mobs stand at the set piece, on the ground, and fight normally.
- [ ] **Bonepile, Wolf Run, Rat Warrens** (the three nearest) → skeletons among the bone
  heaps, wolves at the rocks, rats at the burrows. notes:
- [ ] **Shallow Graves, Gnoll Raider Camp** → skeletons among the grave markers; raiders
  among the tents and the fire, the wagon wreck by the east road. notes:
- [ ] **Boar Thicket, Bat Hollow and Sable** → boars in the scrub; bats in the hollow, Sable
  at the crag beyond it. notes:
- [ ] **Bandit Outpost** → scouts on the knoll, by the lookout and the stake wall. notes:
- [ ] **Rotfang's Den** → dire wolves among the standing rocks, Rotfang at the lair behind. notes:
- [ ] **Festering Mound, Spider Copse and the Crawler** → zombies on the sick ground; spiders
  under the webbed trees, the Crawler at its pit. notes:
- [ ] **The Broken Crypt** (through the pass) → champions in the ruin in the wood's bowl. notes:
- [ ] **Gnoll War Camp and Greth** → brutes inside the stake ring (its gate faces north),
  Greth at the big tent behind. notes:
- [ ] **The Undying, the Ossuary, the Wraith Gate** → each at its place (the pit's west end
  by the glowing door; the pale spires on the crest; the plateau behind the arch). notes:
- [ ] **A quest per giver** (wolf_threat, rat_infestation, gnoll_raiders, rotfang_hunt) → the
  targets are where the dialogue's direction says (north, east, south of the mill...), the
  kills count, the turn-in pays. notes:

## 4 — The bigger world's rules
- [ ] **Die far out** (the war camp, 1.5 km) **and respawn** → you return at your bind (the
  town, or where Sister Maelis or Bind Affinity put it); the corpse is where you died, and the
  run back to it is the walk it looks like. notes:
- [ ] **Gate from the war camp** (a caster past level 8) → you land at your bind; the mob you
  left forgets you. notes:
- [ ] **Two players, 150 m apart, one kills** → the other shares the XP (the 200 m rule);
  at 250 m they do not. notes:
- [ ] **A partner walks out of sight and back** (the server shows you players and mobs out
  to between 120 and 240 m, as before) → they vanish and reappear cleanly; a mob that chases
  them into your view appears with them. Say how the distance feels in a world this size. notes:
- [ ] **Drop an item in the Greywood, walk 400 m away and back** → it is still there to pick
  up. notes:
- [ ] **`/camp` at the Ossuary, log back in** → you are at the Ossuary, on the ground. notes:

## 5 — How it runs and looks
- [ ] **Frame rate in the town, in the Greywood, and looking across the flats from the
  plateau** → note the numbers (and the machine); nothing drops to a crawl. notes:
- [ ] **Look for pop-in while running** → trees switch from simple to full at about 450 m;
  say if it is distracting. notes:
- [ ] **Night** → the fires (the forge, the camps, the pass's braziers) and the two lights
  (the barrow's door, the Wraith Gate) show; the town's windows glow. notes:
- [ ] **From the east road at dusk** → the Ossuary's spires are on the skyline over the
  town, the Wraith Gate's light behind you on the plateau. notes:

## 6 — Regression: what did not change
- [ ] Combat, casting, looting, trading, banking and grouping in and near the town → as on
  the last build. notes:
- [ ] The journal after the sitting: no `ERROR`, `slope_refusals` 0 on the `world health`
  lines apart from the rows above where someone pushed at a face, `ledger check
  mismatches=0`. notes:

## Notes / observations
-
