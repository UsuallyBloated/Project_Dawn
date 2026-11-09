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

> **Run through `bump_build_master_checklist.md` (2026-11-06):** this sheet's rows are in the
> master in sitting order, each tagged `F<section>.<row>` (`FS.n` for Setup). Fill the master;
> the marks are copied back here.

## Setup
- [x] **Redeploy from the merged branch and read the boot line** → it carries
      `terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"` and `dev_cmds=false`. notes: [the 11-05 deploy's boot line, `build="267065f"`, no restart since.]
- [x] **On the client checkout, `.\tools\check_all.ps1`** (after the merge the default server
      path is right) → all 15 PASS, among them `check_terrain_lockstep.gd` (1681 heights, the
      collider rebuilt, 6 NPCs on the ground) and `check_terrain_sight.gd`. notes: [11-09: all 15 PASS on the checkout at `4e4505c`.]
- [x] **Note the start time** for the journal check at the end. notes: [15:21 UTC (parts B and C) and 17:24 UTC (parts D and E), 11-09.]

## 1 — The look and the town
- [x] **Log in and look around the town** → flat as before; the hills visible in the distance,
      flat-shaded (faceted) and tinted green low, grey-brown high; the ground is solid
      underfoot and from above (never seen through, never the far slopes from behind). notes: PASS (11-06, master F1.1).
- [x] **Walk onto a hilltop and stand still, then jump** → you stand on the surface (feet on
      it, not sunk into it) and jump from it as on flat ground. notes: PASS (11-09, master F1.2).
- [x] **Vendor, bank, Sister Maelis's bind, a quest turn-in** → served as before; the NPCs stand
      on the ground. notes: PASS (11-06, master F1.3); the placeholder capsules sit half in the ground, see the
      height sheet's §5 note and the To-Do.
- [x] **Walk the first two rings' camps (the Bonepile, Wolf Run, the Rat Warrens, the Shallow
      Graves, the gnoll raiders, the Boar Thicket, the Festering Mound)** → flat ground, play as
      before. notes: PASS (11-09, master F1.4 / H3.1).

## 2 — The routes out
- [x] **Walk from the town to the bandit knoll, the old rocks, the spiders' rise and the war
      camp's shelf** → uphill is slower (a 30° slope costs about a quarter of the speed),
      downhill full speed; no rubber-banding, no pull forward or back. notes: PASS (11-09, master F2.1).
- [x] **North to the Greywood ridge, then into its side** → the ridge cannot be walked up: the
      body slides back and stays at its foot. notes: PASS (11-09, master F2.2). The user: "Player can push into geometry if they walk continuously
      against the wall, when player stops walking they are pushed out of the wall. Player cannot
      climb steep areas in most places, but is able to climb the side of the wall at touches the
      bandit knoll". Filed on the height model entry: the knoll (radius 25 at z = 60) reaches
      the ridge's foot and lifts it under the 60° rule there; the push-in is the client's body
      against the face until the server's position pulls it back.
- [x] **Through the pass at x = 0 to the Broken Crypt** → a flat way through at walking speed;
      the crypt in its bowl beyond. notes: PASS (11-09, master F2.3).
- [x] **West to the Sunken Barrow and the Ossuary** → up the western hills, down into the pit
      and out again (its walls are steep but walkable), on up to the Ossuary. notes: PASS (11-09, master F2.4).
- [x] **East to the Wraith Gate, up its south ramp** → a long climb onto the flat top. notes: PASS (11-09, master F2.5).

## 3 — Fighting on the hills
- [x] **Fight at the bandit knoll, the spiders' rise and the war camp's shelf** → mobs stand on
      the slope where they spawn, chase you up and down it, fight and walk home as before.
      notes: PASS (11-09, master F3.1).
- [x] **Fight in the Sunken Barrow** → the zombies come up out of the pit after you. notes: PASS (11-09, master F3.2).
- [x] **Pull a mob from above or below a slope and run** → it follows over the ground and
      leashes home as before. notes: PASS (11-09, master F3.3).

## 4 — The Wraith Gate cliff
- [x] **From the plateau, walk off its west edge (x = 150)** → the fall: "You hit the ground
      hard for N damage." with N about 40% of max HP, and the HP bar drops by that. notes: PASS (11-09, master F4.1; the journal: a 17.78 m drop for 131 of 331 HP, later 160 of 406,
      39.4% both times, the formula to the point).
- [x] **At the foot, try to walk back up the cliff, straight and at an angle** → it cannot be
      climbed either way; the body slides back. The way up is the south or north ramp. notes: PASS (11-09, master F4.2; the `world health` lines counted the attempts as `slope_refusals`:
      13, 149, 118 and 325 in the minutes at the face).
- [x] **Below 40% HP, step off the edge again** → you die of the fall; the corpse lies at the
      foot of the cliff. notes: PASS (11-09, master F4.3; the journal: a 17.96 m drop for 162 at 135 HP, the death at level
      17, corpse 2000000068 with 12 stacks).
- [x] **Respawn and run back to the corpse** → it is at the foot; loot it as usual. notes: PASS (11-09, master F4.4; seven pieces back on, the corpse looted empty).

## 5 — Sight through the terrain (two seats)
The Wraith Gate's cliff hides the plateau's top from its foot: from about (138, 0) at the foot
to about (158, 0) on the top is 27 m, inside every spell's 30 m, with the lip some 6 m above the
line between them. (The ridge's own flanks are faces nobody stands on, and from flat ground on
either side its 30 m base puts any target out of reach, so it is no place for this test.)

- [x] **B stands on the plateau near the west edge at about (158, 0); A, at the cliff's foot at
      about (138, 0), targets B and casts a heal (or any spell on a group-mate)** → "You cannot
      see your target." at once: no cast bar, no mana spent. notes: PASS (11-09, master F5.1).
- [x] **A walks round and up the south ramp and casts the same at B from the top** → it lands.
      notes: PASS (11-09, master F5.2).
- [x] **B walks to the lip right above A, about (151, 0), and A casts again from the foot** → a
      steep line up the face: refused or landed, and the server agrees with the client (no
      `cannot see` in the journal after a cast the client let through). notes: PASS (11-09, master F5.3); no `cannot see` line anywhere in the journal.
- [x] **A bow at a mob the terrain hides, inside bow range** (if one is to hand) → the server
      answers "You miss" (bows have no client sight check yet; the swing goes out and misses).
      notes: PASS (11-09, master F5.4). User: "this appears to be true".

## 6 — The Sunken Barrow and the rim
- [x] **Stand on the Sunken Barrow's rim and look in** → the zombies below; nukes from the rim
      land where the rim does not hide them. notes: PASS (11-09, master F6.1).
- [x] **Walk to the plate's edge anywhere and try to climb the rim, straight and at an angle**
      → the ground rises steeply from about 180 m out and becomes a face; the body slides back
      down; nobody gets over it. notes: PASS (11-09, master F6.2 / H1.4).

## 7 — The Fling tool (a GM)
- [x] **Test Panel, Fling 5 m, anywhere** → the body goes up 5 m and drops: "You hit the ground
      hard for N damage." with N about 7.5% of max HP. notes: PASS (11-06, master F7.1).
- [x] **Fling 20 m** → about 45% of max HP, the line, the HP bar. notes: PASS (11-06, master F7.2).
- [-] **On a plain account, the Test Panel's Fling** (if you have one) → nothing happens.
      notes: not run 11-06 (no plain account at the seat; the master row now says how).

## 8 — Regression
- [x] **Die anywhere and respawn** → the respawn lands at the bind on the ground. notes: PASS (11-09, master O2.7 / F8.1).
- [x] **Gate, and be resurrected (two seats)** → you land on the ground. notes: [11-09: Gate and Succor PASS (master H4.3 / F8.2); the resurrection PASS the same day, two seats (master H4.4 / F8.2, from the journal): `resurrection accepted char_id=36 corpse_id=2000000076 xp_percent=25` at 17:57:29, the gear back on from the corpse at 17:58:22. The character landed at a quarter HP beside the skeleton that killed it and died again twelve seconds later, the P99 landing by design.]
- [x] **Summon a pet and walk it over the hills** → it follows, standing on the ground. notes: PASS (11-09, master F8.3).

## 9 — Two seats
- [x] **A partner walks up a hill, stands on it and jumps on it** → drawn on the ground all the
      way, the jump seen. notes: PASS (11-09, master F9.1 / R3.1).
- [x] **The partner walks off the Wraith Gate's west edge** → seen falling and landing at the
      foot. notes: PASS (11-09, master F9.2); the journal: `fall damage char_id=36 drop_m=18.0 ... damage=41.0` at 18:02:09 and 18:04:30, `char_id=48 drop_m=18.0 ... damage=135.0` at 18:04:08.
- [x] **A mob below a face that cannot reach you** (B walks onto the Greywood ridge from its
      east end and along the crest to its north edge at about (25, 89.7): the very edge, `/loc`
      z between 89.5 and 89.9, since a step back and the crest hides the foot. A, a GM, in the
      crypt's bowl below at about (25, 108), spawns a Test Panel mob, which turns on A; B nukes
      it once and takes it; A walks 20 m east) → the mob walks to the foot of the ridge under B
      (about z = 100) and stops there; about 8 s later it turns away, walks home and its HP bar
      refills to full when it gets there. notes: PASS (11-09, master F9.3).
- [x] **The same, and B nukes it again once it has stood at the foot a second or two, and once
      more on its walk home** → "Your target is evading." each time, at once, no mana spent,
      the mob's HP bar unchanged. notes: PASS (11-09, master F9.4). User: "tested with physical attack instead of nuke." [The nuke half is in the journal from the plateau rows: `CastSpell refused — target pre-flight char_id=48 spell=Smite Rk. II ... reason=Your target is evading.` at 18:20:40 and 18:20:57, the caster at (150, 18, -35) on the plateau and the mobs at x 147 below its edge; and char 38's Soul Drain at 18:27:53 and 18:27:59, the mob at x 140 then 132 walking home.]
- [x] **The same, but A hits the mob once as it walks to the foot, then stands beside it there
      and keeps swinging; B keeps the most hate** → from its first second at the foot every
      swing reads "<mob> evades your attack." and does nothing; when it gives up on B it turns
      on A (A's first hit put A on its list) and fights. notes: PASS (11-09, master F9.5).
- [x] **One seat: pull a mob, run until it turns for home, then hit or nuke it on its walk
      back** → "<mob> evades your attack." or "Your target is evading."; it heals to full at
      home and fights normally when pulled again. notes: PASS (11-09, master F9.6; the journal: `CastSpell refused — target pre-flight ... reason=Your
      target is evading.`, a Call Lightning at a Decrepit Skeleton walking home).
- [x] **Two seats, anywhere: both of you hit a mob, then the one it is fighting dies (Trigger
      Death on a GM) or Gates** → the mob turns on the other at once and fights; it walks home
      only when nobody who hit it is left. notes: PASS (11-09, master F9.7). User: "When a charmed mob vanishes and the player who charmed it hasnt engaged with the enemy, the enemy does not aggro the player when the charm wears off. Does this make sense?" [No charm was cast in this sitting (none in the journal 17:24 to 18:40), so this is the morning's Sable event: the charmed pet died, the charm ran out on the dead body, and the server handed back a dead mob (the loot-faucet bug filed under Security the same day); a living pet whose charm runs out on a present, living charmer turns on them (the 10-07 rule). Whether a pet's OWNER should be on a mob's hate list the moment the pet engages is a design call, filed under Combat.]
- [x] **The same, but the one it is fighting runs until it turns away** → it turns on the
      other instead of walking home. notes: PASS (11-09, master F9.8).
- [x] **A pet that cannot reach its owner** (an owner with a pet at the cliff's foot walks round
      and up the ramp to the lip above it, or Gates to a bind on the plateau) → the pet stops at
      the foot, and about 8 s later appears beside its owner. notes: PASS (11-09, master F9.9). User: "This appears to work." [A skeleton summoned at 18:23 on the plateau, its commands in the journal; the warp itself writes no line.]

## 10 — The record
- [x] **The journal since the start time** → no `ERROR`; no `cannot see` line for a cast the
      client let through (the client refuses its own first); a `fall damage` line for each fall
      taken and none else; `dev_fling` rows only for the GM's Fling presses; `slope_refusals`
      on the hills is a curiosity; paste any `WARN`. notes: PASS (11-09, master O2.9 / H7.1 / F10.1, both sittings 15:21 to 16:17 and 17:24 to 18:40 UTC): no `ERROR`, `WARN` or panic; no `cannot see`; `fall damage` lines only for the cliff (18 m, 40% of max HP, five of them across both seats) and the flings (part C), none on flat ground; `dev_fling` rows only on part C's presses; one `world health` line on the hills at `slope_refusals=1` (18:08), the rest 0.

## Notes / observations
-
