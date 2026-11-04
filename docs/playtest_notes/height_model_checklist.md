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

Diagnostics: `journalctl -u projectdawn --since "<start>" | grep -E "ERROR|WARN|cannot see|no sight|fall damage|slope_refusals=[1-9]"`.
A sight refusal on the flat world would be a bug. A slope refusal is counted on the
once-a-minute `world health` line as `slope_refusals`, which must read 0 on the flat world
(nothing there is steep enough to refuse): a count means a terrain the client has and the
server does not (a scene edit nobody exported) or a modified client. On hills, later, an
honest player holding a key into a cliff counts too, since a Move carries the input.

## Setup
- [ ] **Redeploy from the merged branch and read the boot line** → it carries
      `terrain="20x20 cells of 20 m, floor 0, hash 41470a9d8190"` and `dev_cmds=false`. notes:
- [ ] **On the client checkout, `.\tools\check_all.ps1`** → `PASS  check_terrain_lockstep.gd`
      among the checks (441 heights, the collider rebuilt, 6 NPCs on the ground). notes:
- [ ] **Note the start time** for the journal check at the end. notes:

## 1 — Movement
- [ ] **Walk and run in every direction, turn in place, strafe** → the speed and the feel as
      before; no rubber-banding, no pull forward or back. notes:
- [ ] **Run under Spirit of Wolf or Selos' Melody** (if a caster is to hand) → the buffed speed
      as before. notes:
- [ ] **Jump while running** → as before (the jump stays cosmetic; nothing on the server reads
      it). notes:
- [ ] **Walk to the terrain's edge (about 200 m out) and past it** → the ground carries on
      flat; nothing odd at the boundary. notes:
- [ ] **Jump about, run off the town's steps and bumps, Quit Game mid-jump and log back in**
      → never a "You hit the ground hard" line, HP untouched, the relogin ordinary (on the flat
      world the server's fall never begins: a drop needs more than the body's half-metre
      snap). notes:
- [ ] **Sit, stand, `/camp`** → as before. notes:

## 2 — Combat and spells
- [ ] **Melee a camp mob** → hits land as before. notes:
- [ ] **Cast a nuke at 25 to 30 m, and a heal or buff on a group-mate at range** → they land as
      before; no "You cannot see your target." anywhere on the flat world. notes:
- [ ] **A bow at range** (if one is to hand) → arrows land as before. notes:
- [ ] **A point-blank AoE** (a caster at level: Nature's Wrath, Ice Storm, Inferno) → every mob
      inside the radius is hit. notes:
- [ ] **A Bard: Aria of Dismay on a mob** → the slow pulses as before. notes:

## 3 — Camps and pets
- [ ] **Watch a camp** → mobs stand on the ground where they spawn, notice you at their aggro
      radius, chase, fight and walk home as before. notes:
- [ ] **Summon a pet (or the warder)** → it appears beside you on the ground, follows, and
      attacks on `/pet attack`. notes:
- [ ] **Charm a mob and let the charm end** → the mob comes back where it stood. notes:

## 4 — Death, corpses, ports
- [ ] **Die and respawn** → the corpse lies at the death spot; the respawn lands at the bind.
      notes:
- [ ] **Walk back and loot the corpse** → as before. notes:
- [ ] **Gate (and Succor, if a Druid or Wizard is to hand)** → the arrival at the bind or the
      town square, on the ground, the pet along. notes:
- [ ] **Be resurrected** (two seats) → you land beside the corpse. notes:

## 5 — NPC services
- [ ] **Vendor, bank, Sister Maelis's bind, a quest turn-in** → served as before (the NPCs'
      heights are now derived from the ground; on the flat world the same 0). notes:

## 6 — Two seats (optional)
- [ ] **A partner's body, pet and corpse** → drawn where they are, on the ground, as before.
      notes:

## 7 — The record
- [ ] **The journal since the start time** → no `ERROR`; no `cannot see`, `no sight` or
      `fall damage` line for anyone; every `world health` line reads `slope_refusals=0`; paste
      any `WARN`. notes:

## Notes / observations
-
