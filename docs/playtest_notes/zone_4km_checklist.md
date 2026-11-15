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

**Since the compass build (2026-11-14, section 8), run every section on it:** the zone was a
mirror image of its map until then, so the ground, the camps and the doors all moved across
the north-south line. The R720's boot line must read `terrain=400x400 cells of 10 m, floor 0,
hash 6bedde1c663e`, and the zip must be the one exported from the compass build.

| Place | Level | Where (`/loc`: north, west) | Run from the town |
|---|---|---|---|
| Bonepile | 1 | (120, 220) | 50 s |
| Wolf Run | 1 | (-200, -280) | 1 min 10 s |
| Rat Warrens | 2 | (120, -150) | 40 s |
| Shallow Graves | 3 | (330, -400) | 1 min 45 s |
| Gnoll Raider Camp | 3 | (70, -560) | 1 min 50 s |
| Boar Thicket | 4 | (-340, 420) | 1 min 50 s |
| Bat Hollow, Sable's roost | 4 | (540, 130), (640, 180) | 1 min 50 s |
| Bandit Outpost | 5 | (640, 600) | 2 min 55 s |
| Rotfang's Den | 5 | (-800, -60) | 2 min 40 s |
| Festering Mound | 6 | (-620, -640) | 3 min |
| Spider Copse, the Crawler's burrow | 7 | (60, -1120), (-10, -1210) | 3 min 45 s |
| The Broken Crypt | 9 | (1250, -20) | 4 min 10 s |
| Gnoll War Camp, Greth's tent | 10 | (-1500, -20), (-1620, -40) | 5 min |
| The Sunken Barrow, the Undying | 12 | (-60, 1480), (-60, 1560) | 5 min |
| Ossuary | 14 | (90, 1740) | 5 min 50 s |
| Wraith Gate | 16 | (-40, -1570), on the plateau | 5 min 15 s |

Tip: `/loc` prints where you stand as EverQuest did: metres north, then west, then height
(negative is south or east); `/loc raw` prints the world's x, y, z, paste-ready for the
server's files. A GM's Test Panel has Fling 5 m and 20 m for
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
- [ ] **Walk at the Greywood ridge's face** (anywhere `/loc`'s first number is 790) → you stop at its foot;
  holding forward does nothing; no climbing by zigzag or by jumping. notes:
- [ ] **Take the pass north** (`/loc` 790 to 1010 north, 0 west) → a flat road between two walls, into
  the wood; the walls cannot be climbed from inside either. notes:
- [ ] **Climb the Wraith Gate plateau by its north ramp** (from about `/loc` 470, -1700) → a steady
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

## 7 — The edge, the roads and the doors (the outline build of 2026-11-14)

> Needs the zip exported from the outline build and the R720's boot line reading
> `terrain=400x400 cells of 10 m, floor 0, hash a9942be36dff`. The zone is now two basins the
> mountains close round, joined only by the pass; the old square edge is gone. Positions are
> as `/loc` prints them since the compass build (section 8): north, west.

- [ ] **Leave by the north gate and follow the road to its end** → it bends east of Bat Hollow,
      runs the pass with no dip going in and no bank coming out (the floor is level with the
      ground now), swings east round the Broken Crypt's bowl with the crypt in view on your
      left, and ends at fallen trees under the mountains (`/loc` about 1880, 0). notes:
- [ ] **The east road to its end** → past the raiders' wagon wreck, south of the Spider Copse,
      along under the Wraith Gate cliff with the arch above you, and into a narrowing arm that
      ends at a rockslide (`/loc` about -900, -1890). notes:
- [ ] **The south road to its end** → by the mill, west of Rotfang's rocks, then round the foot
      of the war camp's shelf with the gnolls above you on your right, ending at a barricade of
      sharpened stakes (`/loc` about -1838, -98). notes:
- [ ] **The barrow track to its end** → out by the lane between the fields, north of the bone
      fields, up the hill to a ring of waystones (`/loc` about 250, 1370) with the barrow's pit
      below you and the Ossuary on the crest above. notes:
- [ ] **On each road, watch the camps you pass** → nothing comes for you from the road: Rotfang's
      den, the war camp and the Broken Crypt are each about 200 m off it. notes:
- [ ] **Run at the mountains and hold forward, then zigzag, in four places: the end of the east
      arm, the war camp's vale, a corner of the Greywood, the barrow hills' west side** → the
      foot is a cliff you do not climb; `/loc` stops moving outward; you slide along it at most.
      notes:
- [ ] **Try to go round the ridge: follow its south foot east until `/loc`'s second number passes
      -1300, then west until it passes 1300** → the mountains meet the ridge at both ends; the pass is the only way north.
      notes:
- [ ] **At each door, walk into the rocks, the trees, the stakes** → the pieces are scenery (you
      pass through them); the cliff behind them stops you. notes:
- [ ] **Look round from the town square and from inside the Greywood** → mountains on every
      side, bare rock with snow on the tops, no trees and no forest floor on them, no strip of
      sky under them. notes:
- [ ] **Two seats: one stands still at a door, the other watches them from 50 m** → the partner
      stands on the ground at the cliff's foot, not in it and not above it. notes:
- [ ] **(GM) `Fling 20 m` beside the mountains; then log out standing against the cliff and log
      back in** → you land where you stood and log in where you stood; nothing puts you on the
      mountains. notes:
- [ ] The journal: `slope_refusals` on the `world health` lines only for the minutes someone
      pushed at a cliff; no `ERROR`; `ledger check mismatches=0`. notes:

## 8 — The compass (2026-11-14)

> The world is now its map the right way round: north is -z, east +x, so facing north, east is
> on your right, as on the comp. Needs the boot line `hash 6bedde1c663e` and the compass zip.
> At the redeploy every saved position was mirrored with the world, so nobody logs in inside
> the mountains.

- [ ] **Log in where you logged out (any character from before the redeploy)** → you stand
      on the ground in the same place relative to the town, the camps and the roads as before;
      not in a mountain and not in the air. Your bind still returns you there. notes:
- [ ] **In the town square, face the Greywood ridge (the wall with the pass in it) and type
      `/sense`** → "North" (with the skill high enough to be sure). The Gnoll Raider Camp's
      road, the east road with the tall tower by its gate, leaves on your right. notes:
- [ ] **Face the east gate (the one by the tall tower) and `/sense`** → "East"; the sun rises
      behind that gate in the morning. notes:
- [ ] **`/loc` in the square, then walk north towards the pass and `/loc` again** → the first
      number grows going north; walking east the second number falls (it counts west, as
      EverQuest's did); the third is your height. notes:
- [ ] **`/loc raw`** → "Your world position is x, y, z"; walking north, its z falls. notes:
- [ ] **Hold the comp map beside the game (`docs/design/starting_area_comp_sketches.html`)** →
      every camp, the barrow to the west, the Wraith Gate to the east, the war camp to the south
      and the Greywood beyond the ridge to the north are where the map has them, and on the
      same side of each other. notes:
- [ ] **Walk the town's walls from outside** → the battlements are on the outer side of every
      wall; the gates and the tower stand as before. notes:
- [ ] **Two seats: both log in, group, and kill something at the Bonepile** → the partner sees
      you where you are and the mob where it is; nobody floats or stands inside the ground.
      notes:

## Notes / observations
-
