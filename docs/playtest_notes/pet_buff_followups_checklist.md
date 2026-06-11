# Pet Buff Follow-ups Playtest Checklist — 2026-06-10

Two follow-ups on top of pet buffs: **Thorns reflect on pets** (now reflects, was deferred)
and **target-frame buff icons** (replaces the text list). **Re-export Project_Dawn + restart
the server** (server `tick.rs` / `entity.rs`, client `hud.gd` / `remote_player_manager.gd`
changed).

Tip: server logs the reflect as a HealthUpdate on the attacker (its HP bar drops). The owner
also gets a combat-log line "X has been hit by N damage from your pet's Thorns."

## Setup
- [x] Re-export Project_Dawn
- [x] Restart server (release build)
- [x] A summons a pet and Full Heals for mana notes: Full heal is a lie.
- [x] Pull an enemy onto the pet so it's actively trading blows

## 1 — Thorns reflect on a pet (now live)
- [x] Cast **Thorns** on the pet, then let an enemy hit the pet → the **enemy takes damage**
  (its HP bar ticks down on each hit it lands on the pet). notes:
- [x] The owner sees a combat-log line: "<enemy> has been hit by N damage from your pet's
  Thorns" + a floating number on the enemy. notes:
- [x] A low-HP enemy meleeing a Thorns'd pet eventually **dies to the reflect** (no XP/loot,
  same as the player Thorns path). No crash. notes:
- [x] Unshielded pet (no Thorns) → enemies take **no** reflect (regression). notes:

## 2 — Target-frame buff icons
- [x] Target a buffed **pet** → buffs show as a row of small colored-border **icons** (not a
  text list), with countdowns. notes:
- [x] Target a buffed **peer player** → same icon row (icons work for peers too). notes:
- [x] Colors roughly match the player's main buff bar (gold stat / blue Clarity / yellow
  Haste / green Spirit of Wolf / orange Thorns); HoTs/unknown = green. notes:
- [x] Many buffs at once → the row **wraps** to a second line, stays inside the target frame. notes:
- [x] Hover an icon → tooltip shows the full buff name (names are truncated to ~4 chars on
  the icon). notes: Hovering over an icon does not show the full buff name.
- [x] Switch/clear target → icons clear; re-targeting rebuilds them. notes:

## Notes / observations
-
