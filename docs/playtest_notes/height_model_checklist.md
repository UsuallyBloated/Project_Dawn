# Height Model Playtest Checklist — 2026-11-04

Slices 0 and 1 of the server height model (`docs/design/server_height_model.md`): the server
now carries the client's ground (`terrain.toml`, exported from `world.tscn` and compiled in),
stands every player, mob, pet, corpse, NPC and safe area on it, takes a player's step as the
client's body does (three quarters of the flat distance up a 30° slope, none up a face past
60°), checks line of sight through the terrain for every targeted spell (heals and buffs
too), each AoE victim, ranged attacks, an idle mob's scan and a song's pulse, and (slice 2,
built the same day) runs a player's fall off an edge itself and charges the landing as a share
of max HP (`docs/design/server_fall_damage.md`).

**On today's flat world none of that changes anything, and that is what this sheet proves.** A
regression pass: every row below is ordinary play that must read exactly as before. The proof
of the rules themselves is the integration tests on a ramp and a ridge
(`tests/world/height.rs`, nine tests, each failing on the previous server) and the unit tests
in `world/terrain.rs`.

**Build prerequisite:** the R720 on the November bump plus the `feat/height-model` merge
(server only; no export: the client half is tooling). The boot line names the ground:
`terrain="20x20 cells of 20 m, floor 0, hash 41470a9d8190"`. One seat is enough; two for
section 6.

> **Updated 2026-11-04 (night): the first hills ride the same merge** (slice 3,
> `first_hills_checklist.md`), so the world this sheet meets is no longer flat everywhere.
> The boot line reads `terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"` and the
> lockstep check counts 1681 heights. The town and the first two rings of camps (to about
> 60 m out) stay flat: run this sheet's rows there. "Walk past the edge" now meets the rim
> (the hills sheet's §6), and sight refusals, falls and slope refusals out on the hills are
> the hills sheet's to judge, not regressions here.

Diagnostics: `journalctl -u projectdawn --since "<start>" | grep -E "ERROR|WARN|cannot see|no sight|fall damage|slope_refusals=[1-9]"`.
A sight refusal on the flat world would be a bug. A slope refusal is counted on the
once-a-minute `world health` line as `slope_refusals`, which must read 0 on the flat world
(nothing there is steep enough to refuse): a count means a terrain the client has and the
server does not (a scene edit nobody exported) or a modified client. On hills, later, an
honest player holding a key into a cliff counts too, since a Move carries the input.

> **Run through `bump_build_master_checklist.md` (2026-11-06):** this sheet's rows are in the
> master in sitting order, each tagged `H<section>.<row>` (`HS.n` for Setup). Fill the master;
> the marks are copied back here.

## Setup
- [x] **Redeploy from the merged branch and read the boot line** → it carries
      `terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"` (the first hills; before
      them it was `20x20 cells of 20 m, ... 41470a9d8190`) and `dev_cmds=false`. notes: [the 11-05 deploy's boot line, `build="267065f" dev_cmds=false terrain="40x40 cells of 10 m, floor 0, hash f2bd278da1c3"`, no restart since.]
- [x] **On the client checkout, `.\tools\check_all.ps1`** → `PASS  check_terrain_lockstep.gd`
      among the checks (1681 heights, the collider rebuilt, 6 NPCs on the ground). notes: [11-09: all 15 PASS on the checkout at `4e4505c`, `check_terrain_lockstep.gd` among them.]
- [x] **Note the start time** for the journal check at the end. notes: [15:21 UTC (parts B and C) and 17:24 UTC (parts D and E), 11-09.]

## 1 — Movement
- [x] **Walk and run in every direction, turn in place, strafe** → the speed and the feel as
      before; no rubber-banding, no pull forward or back. notes: PASS (11-09, master H1.1).
- [x] **Run under Spirit of Wolf or Selos' Melody** (if a caster is to hand) → the buffed speed
      as before. notes: PASS (11-09, master H1.2). The user: "Selos appears to start working before the spell has
      completed casting"; the server pulses a song only at its release, after the 3 s sing, so
      the speed seen during a bar is the previous pulse's 12 s linger when the song is re-sung
      inside it. Open: whether it was seen on a first sing from cold.
- [x] **Jump while running** → as before (the jump stays cosmetic; nothing on the server reads
      it). notes: PASS (11-09, master H1.3).
- [x] **Walk to the terrain's edge (about 200 m out) and past it** → the ground carries on
      flat; nothing odd at the boundary. notes: PASS (11-09, master F6.2 / H1.4: the rim now, which the body slides back down).
- [x] **Jump about, run off the town's steps and bumps, Quit Game mid-jump and log back in**
      → never a "You hit the ground hard" line, HP untouched, the relogin ordinary (on the flat
      world the server's fall never begins: a drop needs more than the body's half-metre
      snap). notes: PASS (11-09, master H1.5). The user: "The town has no steps. These poor people have no homes
      or structures."
- [x] **Sit, stand, `/camp`** → as before. notes: [11-06: sit and stand PASS (master O3.7); `/camp` PASS 11-09 (master O2.8 / H1.6): `camp window elapsed — client logs out char_id=38` at 18:40:58.]

## 2 — Combat and spells
- [x] **Melee a camp mob** → hits land as before. notes: PASS (11-09, master O2.2 / H2.1).
- [x] **Cast a nuke at 25 to 30 m, and a heal or buff on a group-mate at range** → they land as
      before; no "You cannot see your target." anywhere on the flat world. notes: [11-09: the nuke and a self heal PASS (master O2.3 / H2.2); the group-mate heal at
      range PASS the same day, two seats (master H2.2): `ALLY heal applied char_id=48 target=36 spell=Greater Heal heal=50.0`, no `cannot see` line in the journal.]
- [x] **A bow at range** (if one is to hand) → arrows land as before. notes: PASS (11-09, master H2.3). The user: "Bow fires and does damage, currently does not consume
      ammo. I also dont think we have an arrow item to act as the ammo." Filed: no ammo model on
      either side (the Arrow Bundle exists and nothing consumes it).
- [x] **A point-blank AoE** (a caster at level: Nature's Wrath, Ice Storm, Inferno) → every mob
      inside the radius is hit. notes: PASS (11-09, master H2.4; the journal: Nature's Wrath, radius 6, hits=3).
- [x] **A Bard: Aria of Dismay on a mob** → the slow pulses as before. notes: PASS (11-09, master H2.5).

## 3 — Camps and pets
- [x] **Watch a camp** → mobs stand on the ground where they spawn, notice you at their aggro
      radius, chase, fight and walk home as before. notes: PASS (11-09, master F1.4 / H3.1).
- [x] **Summon a pet (or the warder)** → it appears beside you on the ground, follows, and
      attacks on `/pet attack`. notes: PASS (11-09, master H3.2 / O3.4).
- [x] **Charm a mob and let the charm end** → the mob comes back where it stood. notes: PASS (11-09, master H3.3). The journal also shows a charmed pet that died 4 s before its
      charm expired coming back as a DEAD mob with a loot bag (Sable the Dark, 15:57 UTC): filed
      under Security.

## 4 — Death, corpses, ports
- [x] **Die and respawn** → the corpse lies at the death spot; the respawn lands at the bind.
      notes: PASS (11-09, master O2.7 / H4.1).
- [x] **Walk back and loot the corpse** → as before. notes: PASS (11-09, master H4.2).
- [x] **Gate (and Succor, if a Druid or Wizard is to hand)** → the arrival at the bind or the
      town square, on the ground, the pet along. notes: PASS (11-09, master H4.3 / F8.2: Gate and Succor both, a Druid; the journal: `PORT applied
      ... port=bind` and `port=safe`).
- [x] **Be resurrected** (two seats) → you land beside the corpse. notes: PASS (11-09, master H4.4 / F8.2, marked by Claude from the journal: the row came back blank): corpse 2000000076 at 17:57:06, the Cleric's first Resurrection (Minor) fizzled, the second was `offered ... xp_percent=25` and `accepted` at 17:57:29, the gear back on from the corpse at 17:58:22 (`reequipped=6`). The level 2 character landed at a quarter HP beside the Decrepit Skeleton that had killed it and died again twelve seconds later (three hits of 5; the P99 landing, by design, user call 2026-10-15), leaving a second, empty corpse.

## 5 — NPC services
- [x] **Vendor, bank, Sister Maelis's bind, a quest turn-in** → served as before (the NPCs'
      heights are now derived from the ground; on the flat world the same 0). notes: PASS (11-06, master H5.1). The NPC capsules sit half in the ground: the three NPC scenes draw a
      centred 1.8 m capsule at the node origin (always so, not the hills; the remote player's capsule
      is raised 1 m); a model with its origin at its feet stands right. Filed in the To-Do.

## 6 — Two seats (optional)
- [x] **A partner's body, pet and corpse** → drawn where they are, on the ground, as before.
      notes: PASS (11-09, master H6.1). User: "hard to tell facing of a pet." [Pets do turn (the client applies the server's yaw), but a capsule has no front; nothing to see until pets have models.]

## 7 — The record
- [x] **The journal since the start time** → no `ERROR`; no `cannot see`, `no sight` or
      `fall damage` line for anyone; every `world health` line reads `slope_refusals=0`; paste
      any `WARN`. notes: PASS (11-09, master O2.9 / H7.1, both sittings): no `ERROR`, `WARN` or panic; no `cannot see` or `no sight`. This row was written for the flat world: with the hills in the same build, the `fall damage` lines are the cliff's and the flings' (every one on the hills sheet's rows, none on flat ground) and one `world health` line on the hills read `slope_refusals=1` (18:08, a key held into a face); on the flat ground every line read 0.

## Notes / observations
-
