# Pet PvP Inheritance Playtest Checklist — 2026-06-11

A player-owned pet now inherits its owner's `/pvp` flag — it's only damageable when the
attacker could attack the owner directly, and you can never damage your own pet. Melee +
single-target spell were already gated; this round closed the **AOE** hole. **Re-export
Project_Dawn + restart the server** (server `tick.rs` changed).

Server log anchors: `"PvP spell applied vs pet"` (spell landed on a pet), `"AOE spell
applied"` (with a `hits` count), and rejections fan an `"Unable to attack X's Y."` chat line
to the attacker (no server `tracing` line for the reject — watch the in-game chat).

## Setup
- [x] Re-export Project_Dawn
- [x] Server running with `$env:PD_DEV_CMDS=1` (so Full Heal tops mana for repeated casts)
- [x] Two clients: A (a caster with an AOE — e.g. Magician Inferno / Druid Nature's Wrath)
  and B (a class with a pet)
- [x] B summons a pet; position it near A so it's within A's AOE radius
- [x] Both `/pvp off` to start

## 1 — /pvp OFF: A cannot damage B's pet (all paths)
- [x] A melee auto-attacks B's pet → swings get "Unable to attack B's \<pet\>." in chat; pet
  HP unchanged. notes:
- [x] A casts a **single-target** damage spell on B's pet → rejected ("Unable to attack…");
  pet HP unchanged. notes: "PvP is off. Type /pvp on to attack other players."
- [x] A casts an **AOE** with B's pet in radius → pet HP **unchanged** (the new gate); any
  real enemies in range still take the AOE. notes:

## 2 — /pvp ON both: A CAN damage B's pet
- [x] `/pvp on` on both A and B. notes:
- [x] A melee / single-target spell / AOE on B's pet → pet **takes damage** on each path. notes:melee and frost bolt do damage, but Inferno does not do damage.
- [x] server.log shows `"PvP spell applied vs pet"` for the spell hit. notes: Frost Bolt, but not Inferno

## 3 — Own pet is never damageable (regardless of flags)
- [x] A summons its own pet. A melee-attacks it → rejected, no damage. notes:
- [x] A casts a single-target damage spell on its own pet → rejected, no damage. notes:
- [x] A casts an **AOE** with its own pet in radius → **own pet takes no damage** (the new
  gate also protects your own pet from your AOE). notes:

## 4 — Regression: world mobs + buffs/heals unaffected
- [x] A's AOE still damages regular enemies in range (the gate only touches player-owned
  pets). notes:
- [x] A can still **heal/buff** B's pet when grouped (ALLY routing) — the attack gate didn't
  break the beneficial-cast path. notes:

## Notes / observations
-looking good.  great work.
