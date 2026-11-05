# The First Hills Playtest Checklist — 2026-11-04

Height model slice 3 (`docs/design/first_hills_plan.md`): the starter zone's 400 m plate is no
longer flat. The relief is authored as data (`data/terrain_features.toml`, written into
`world.tscn` by `tools/author_terrain.gd`) and compiled into the server: the western hills
with the Sunken Barrow dug into them, the bandit knoll, Bat Hollow, the Greywood ridge with
its pass, the crypt's bowl, the spiders' rise, the old rocks, the war camp's shelf, the Wraith
Gate plateau with its one real cliff, and a rim round the edge. Also new: the client refuses a
cast it cannot see before the bar; a GM's Fling buttons; a mob held below a face gives up after
8 s and walks home, evading all damage from its first second at the foot until it is home, and a
pet warps to an owner it cannot reach; the slope rule refuses a
diagonal up a face, so nobody zigzags up a cliff.

**Build prerequisite:** the November bump's redeploy AND export, both from the merged
`feat/height-model`, with the wire DLL built from the height branch's server (the Fling
buttons need `send_dev_fling`). The boot line names the ground:
`terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"`. One seat for most of it, two for
sections 5 and 9; a GM account for sections 7 and 9.

Where things are (x east, z north, `/loc` reads them; the town is at the origin and stays flat
out to about 60 m):

| Feature | Where | What to expect |
|---|---|---|
| The western hills, the Sunken Barrow, the Ossuary | centred (-160, 0); the pit at (-150, -6); the Ossuary at (-170, 0) | a broad rise to about 25 m; a pit 12 m deep in it, walls 30 to 40°; the Ossuary on the high ground |
| The bandit knoll | (-58, 60) | the outpost on an 8 m rise |
| Bat Hollow | (3, 48) | a shallow dip with a low rim |
| The Greywood ridge and the pass | along z = 85 from x = -120 to 120; the pass at x = 0 | a wall about 18 m high with 61° sides; a flat gap 20 m wide at x = -10 to 10 |
| The Broken Crypt's bowl | (2, 118), north of the ridge | a dip with a low rim, out of sight from the south |
| The spiders' rise | (110, 2) | a 6 m rise |
| The Wraith Gate plateau | x 150 to 200, z -40 to 30 | flat at 18 m; ramps up its south side (z -70 to -40) and north side (z 30 to 60); its west edge (x = 150) a cliff |
| The old rocks (Rotfang) | (3, -72) | a 6 m rise |
| The war camp's shelf | (2, -150) | an 8 m rise |
| The rim | the outer 20 m of the plate | rising to 40 m at the edge, a face nobody climbs |

Fall costs (no armor, shield or attacker reduces them): nothing to 2 m, then 2.5% of max HP a
metre, all of it at 42 m. A 5 m fling costs 7.5%, a 20 m one 45%, the Wraith Gate's 18 m cliff
40%.

Diagnostics: `journalctl -u projectdawn --since "<start>" | grep -E "ERROR|WARN|cannot see|fall damage|slope_refusals=[1-9]|dev_fling"`.
`slope_refusals` on the once-a-minute `world health` line counts steps the slope rule refused;
on hills a key held into a cliff counts too, so a number there is a curiosity, not a fault.

## Setup
- [ ] **Redeploy from the merged branch and read the boot line** → it carries
      `terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"` and `dev_cmds=false`. notes:
- [ ] **On the client checkout, `.\tools\check_all.ps1`** (after the merge the default server
      path is right) → all 15 PASS, among them `check_terrain_lockstep.gd` (1681 heights, the
      collider rebuilt, 6 NPCs on the ground) and `check_terrain_sight.gd`. notes:
- [ ] **Note the start time** for the journal check at the end. notes:

## 1 — The look and the town
- [ ] **Log in and look around the town** → flat as before; the hills visible in the distance,
      flat-shaded (faceted) and tinted green low, grey-brown high; the ground is solid
      underfoot and from above (never seen through, never the far slopes from behind). notes:
- [ ] **Walk onto a hilltop and stand still, then jump** → you stand on the surface (feet on
      it, not sunk into it) and jump from it as on flat ground. notes:
- [ ] **Vendor, bank, Sister Maelis's bind, a quest turn-in** → served as before; the NPCs stand
      on the ground. notes:
- [ ] **Walk the first two rings' camps (the Bonepile, Wolf Run, the Rat Warrens, the Shallow
      Graves, the gnoll raiders, the Boar Thicket, the Festering Mound)** → flat ground, play as
      before. notes:

## 2 — The routes out
- [ ] **Walk from the town to the bandit knoll, the old rocks, the spiders' rise and the war
      camp's shelf** → uphill is slower (a 30° slope costs about a quarter of the speed),
      downhill full speed; no rubber-banding, no pull forward or back. notes:
- [ ] **North to the Greywood ridge, then into its side** → the ridge cannot be walked up: the
      body slides back and stays at its foot. notes:
- [ ] **Through the pass at x = 0 to the Broken Crypt** → a flat way through at walking speed;
      the crypt in its bowl beyond. notes:
- [ ] **West to the Sunken Barrow and the Ossuary** → up the western hills, down into the pit
      and out again (its walls are steep but walkable), on up to the Ossuary. notes:
- [ ] **East to the Wraith Gate, up its south ramp** → a long climb onto the flat top. notes:

## 3 — Fighting on the hills
- [ ] **Fight at the bandit knoll, the spiders' rise and the war camp's shelf** → mobs stand on
      the slope where they spawn, chase you up and down it, fight and walk home as before.
      notes:
- [ ] **Fight in the Sunken Barrow** → the zombies come up out of the pit after you. notes:
- [ ] **Pull a mob from above or below a slope and run** → it follows over the ground and
      leashes home as before. notes:

## 4 — The Wraith Gate cliff
- [ ] **From the plateau, walk off its west edge (x = 150)** → the fall: "You hit the ground
      hard for N damage." with N about 40% of max HP, and the HP bar drops by that. notes:
- [ ] **At the foot, try to walk back up the cliff, straight and at an angle** → it cannot be
      climbed either way; the body slides back. The way up is the south or north ramp. notes:
- [ ] **Below 40% HP, step off the edge again** → you die of the fall; the corpse lies at the
      foot of the cliff. notes:
- [ ] **Respawn and run back to the corpse** → it is at the foot; loot it as usual. notes:

## 5 — Sight through the terrain (two seats)
The Wraith Gate's cliff hides the plateau's top from its foot: from about (138, 0) at the foot
to about (158, 0) on the top is 27 m, inside every spell's 30 m, with the lip some 6 m above the
line between them. (The ridge's own flanks are faces nobody stands on, and from flat ground on
either side its 30 m base puts any target out of reach, so it is no place for this test.)

- [ ] **B stands on the plateau near the west edge at about (158, 0); A, at the cliff's foot at
      about (138, 0), targets B and casts a heal (or any spell on a group-mate)** → "You cannot
      see your target." at once: no cast bar, no mana spent. notes:
- [ ] **A walks round and up the south ramp and casts the same at B from the top** → it lands.
      notes:
- [ ] **B walks to the lip right above A, about (151, 0), and A casts again from the foot** → a
      steep line up the face: refused or landed, and the server agrees with the client (no
      `cannot see` in the journal after a cast the client let through). notes:
- [ ] **A bow at a mob the terrain hides, inside bow range** (if one is to hand) → the server
      answers "You miss" (bows have no client sight check yet; the swing goes out and misses).
      notes:

## 6 — The Sunken Barrow and the rim
- [ ] **Stand on the Sunken Barrow's rim and look in** → the zombies below; nukes from the rim
      land where the rim does not hide them. notes:
- [ ] **Walk to the plate's edge anywhere and try to climb the rim, straight and at an angle**
      → the ground rises steeply from about 180 m out and becomes a face; the body slides back
      down; nobody gets over it. notes:

## 7 — The Fling tool (a GM)
- [ ] **Test Panel, Fling 5 m, anywhere** → the body goes up 5 m and drops: "You hit the ground
      hard for N damage." with N about 7.5% of max HP. notes:
- [ ] **Fling 20 m** → about 45% of max HP, the line, the HP bar. notes:
- [ ] **On a plain account, the Test Panel's Fling** (if one is to hand) → nothing happens.
      notes:

## 8 — Regression
- [ ] **Die anywhere and respawn** → the respawn lands at the bind on the ground. notes:
- [ ] **Gate, and be resurrected (two seats)** → you land on the ground. notes:
- [ ] **Summon a pet and walk it over the hills** → it follows, standing on the ground. notes:

## 9 — Two seats
- [ ] **A partner walks up a hill, stands on it and jumps on it** → drawn on the ground all the
      way, the jump seen. notes:
- [ ] **The partner walks off the Wraith Gate's west edge** → seen falling and landing at the
      foot. notes:
- [ ] **A mob below a face that cannot reach you** (B walks onto the Greywood ridge from its
      east end and along the crest to its north edge at about (25, 89.7): the very edge, `/loc`
      z between 89.5 and 89.9, since a step back and the crest hides the foot. A, a GM, in the
      crypt's bowl below at about (25, 108), spawns a Test Panel mob, which turns on A; B nukes
      it once and takes it; A walks 20 m east) → the mob walks to the foot of the ridge under B
      (about z = 100) and stops there; about 8 s later it turns away, walks home and its HP bar
      refills to full when it gets there. notes:
- [ ] **The same, and B nukes it again once it has stood at the foot a second or two, and once
      more on its walk home** → "Your target is evading." each time, at once, no mana spent,
      the mob's HP bar unchanged. notes:
- [ ] **The same, but A hits the mob once as it walks to the foot, then stands beside it there
      and keeps swinging; B keeps the most hate** → from its first second at the foot every
      swing reads "<mob> evades your attack." and does nothing; when it gives up on B it turns
      on A (A's first hit put A on its list) and fights. notes:
- [ ] **One seat: pull a mob, run until it turns for home, then hit or nuke it on its walk
      back** → "<mob> evades your attack." or "Your target is evading."; it heals to full at
      home and fights normally when pulled again. notes:
- [ ] **Two seats, anywhere: both of you hit a mob, then the one it is fighting dies (Trigger
      Death on a GM) or Gates** → the mob turns on the other at once and fights; it walks home
      only when nobody who hit it is left. notes:
- [ ] **The same, but the one it is fighting runs until it turns away** → it turns on the
      other instead of walking home. notes:
- [ ] **A pet that cannot reach its owner** (an owner with a pet at the cliff's foot walks round
      and up the ramp to the lip above it, or Gates to a bind on the plateau) → the pet stops at
      the foot, and about 8 s later appears beside its owner. notes:

## 10 — The record
- [ ] **The journal since the start time** → no `ERROR`; no `cannot see` line for a cast the
      client let through (the client refuses its own first); a `fall damage` line for each fall
      taken and none else; `dev_fling` rows only for the GM's Fling presses; `slope_refusals`
      on the hills is a curiosity; paste any `WARN`. notes:

## Notes / observations
-
