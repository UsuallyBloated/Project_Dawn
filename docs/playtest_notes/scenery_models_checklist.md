# Scenery Models Playtest Checklist — 2026-11-24

The zone's trees, rocks, bushes, scrub, bones, skeletons and grass are our own Blender models
now (`tools/blender/`, `assets/models/scenery/`), not the code placeholders. This verifies how
they look in place, that collision follows each model (trunks stop a body, crowns never do,
small bones are stepped over, big ribcages are not, grass blocks nothing), and that the zone
still runs well. Session note: `docs/session_notes/session_2026_11_24_scenery_generators.md`.

**Build prerequisite: the client and the server move together** (the obstacle file changed).
Either the dev loop (the server from `F:\Projects\server-scenery` with
`$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server`, the client from the Godot editor in
`F:\Projects\Project_Dawn-scenery`, logged in to localhost), or, after the merge, the R720
redeployed with the new zip. The server's boot line must read
`obstacles=45620 prisms (30512 walk, 32976 sight), hash c4df3370b3ca`.

Places, as `/loc` prints them (north, west):

| Where | `/loc` | What grows |
|---|---|---|
| The Greywood (north of the pass) | 1400, 0 | pines, tall pines, a few dead trees |
| The Spider Copse | 60, -1120 | dark trees |
| The Bonepile | 120, 220 | a ring of skeletons and beast bones |
| The bone fields | 0, 1000 | beast bones, a few skeletons |
| The Sunken Barrow | -60, 1480 | a ring of skeletons and bones round the pit |
| The Ossuary | 90, 1740 | a ring of skeletons and bones |
| The Broken Crypt | 1250, -20 | a ring of skeletons and bones in the wood |
| The Gnoll Flats | 50, -700 | boulders, scrub, dry grass |

Diagnostics: the in-game console (backtick) shows `ZoneFlora: N things in M batches` at load;
the Test Panel's **Obstacle Outlines** draws every prism (red stops a body, blue blocks sight
only). In the server journal, a sudden run of `slope_refusals` is unrelated to scenery; a body
stopped where nothing is drawn is the thing to note.

## Setup
- [ ] **Start the pair and check the boot line** → `hash c4df3370b3ca`, `dev_cmds` as you meant it. notes:
- [ ] **Log in and open the console** → a `ZoneFlora` line with about 16,500 things; no red error lines. notes:

## 1 — Trees
- [ ] **Walk into the Greywood** → pines of several shapes in each stand, tall pines among them, the forest floor's grass thin. notes:
- [ ] **Find a colossal tree** (about one in 40 is half again to twice the size) → it stands well above the rest of its stand. notes:
- [ ] **Walk into a pine's trunk** → you stop at the trunk; nothing stops you under the lowest branches. notes:
- [ ] **Walk under a dark tree's canopy in the Spider Copse** → you walk under the crown freely; only the twisted trunk stops you, and you slide round its bends. notes:
- [ ] **Walk into a dead tree and a broadleaf on the plain** → the trunk stops you; branches and the crown do not. notes:
- [ ] **From the town's north wall, look at the Greywood** → past about 450 m the trees become simple cones and lumps of the same size, with no visible jump in size as they switch. notes:

## 2 — Rocks, bushes and scrub
- [ ] **Walk into a boulder, large and small** → stopped at the rock's own outline. notes:
- [ ] **Walk into a bush** → stopped at the bush's mound; the berries on some bushes are visible. notes:
- [ ] **Walk into scrub on the Gnoll Flats** → stopped at the scrub; it reads as dry twigs over a low mound. notes:

## 3 — Bones and skeletons
- [ ] **Walk round the Bonepile's ring** → skeletons of different sizes (the races), each in its own pose, and beast piles among them; the camp's middle bare. notes:
- [ ] **Walk over a small skeleton** (a Fae's, a Gnome's or a Halfling's) → you step over it without stopping. notes:
- [ ] **Walk into a big skeleton's ribcage** (an Ogre's, a Troll's, a Minotaur's) → the ribs stop you; you can step over its low pieces (feet, hands, vertebrae). notes:
- [ ] **Walk through a beast pile's long bones and vertebrae** → the low pieces are stepped over, the ribs and the skull stop you. notes:
- [ ] **Find the horned and the antlered beast skulls** (bone fields, or the camp rings) → horns curl, antlers branch. notes:
- [ ] **Walk a road a while** → now and then a skeleton lies a few metres off the verge, never on the road. notes:
- [ ] **Visit the Sunken Barrow, the Ossuary and the Broken Crypt** → each has its ring of the dead; nothing blocks the camp's own middle. notes:
- [ ] **Pull a mob through a skeleton ring** → it comes to you round the pieces, as round trees. notes:

## 4 — Grass
- [ ] **Stand on an open meadow** → thick grass round you, thinning out into the distance and gone by about 60 m, fading rather than popping. notes:
- [ ] **Turn the camera quickly and run** → grass grows ahead of you with no gaps you can see. notes:
- [ ] **Compare the Greywood, the steppe and the western hills** → thin under the trees, straw-coloured on the steppe and the flats, drier and sparser as the hills climb. notes:
- [ ] **Look at a road, the town, a farm field and a camp's middle** → no grass on any of them. notes:
- [ ] **Walk through grass** → nothing stops you, and the grass hides no player or mob. notes:
- [ ] **Two seats: stand together on a meadow** (optional) → both see the same tufts in the same places. notes:

## 5 — Sight lines
- [ ] **Cast at a mob behind a big trunk** → refused ("You cannot see your target."), as with any solid. notes:
- [ ] **Cast at a mob across a skeleton or through grass** → lands; low bones and grass hide nothing. notes:

## 6 — Running well
- [ ] **Stand in the thickest Greywood and in the Bonepile's ring** → the frame rate feels as it did before. notes:
- [ ] **Log out and check the server journal** → no error since the boot. notes:
