# Project Dawn — Pre-Alpha Tester Guide

Welcome, and thank you for kicking the tyres on **Project Dawn**.

This is a **pre-alpha** build. The world is small, the rough edges are real, and **your save file will be wiped** when the multiplayer server arrives in roughly four weeks. Treat any character you make as throwaway. The point of this build is to find bugs and shake out the core feel before the server comes online.

---

## System requirements

- **OS**: Windows 10 or 11 (64-bit). Mac/Linux builds will follow.
- **CPU**: Anything from the last decade. Single-threaded performance dominates.
- **GPU**: A discrete card or modern integrated GPU that supports Vulkan / Forward+. Anything from ~2017 onward is fine.
- **RAM**: 4 GB free.
- **Disk**: ~250 MB for the game; saves live in `%APPDATA%\Godot\app_userdata\Project_Dawn\`.

---

## How to launch

1. Unzip the build wherever you want it (Desktop is fine).
2. Double-click `ProjectDawn.exe`.
3. You'll land on the lobby screen.

There is **no installer**, no launcher, no auto-update yet. To get a new version, delete the folder and unzip the new one.

---

## First five minutes

The fastest path to gameplay:

1. From the lobby, click **Test Room**.
2. You'll spawn as **Chortle**, a level 50 Troll Shadow Knight, in the open test world. Existing save? You'll resume that character instead.
3. Walk around. Punch a wolf. Cast a spell. Talk to Aldric the Guard near spawn.

### Default controls

| Key | Action |
|---|---|
| **W A S D** | Move |
| **Space** | Jump |
| **X** | Crouch |
| **Z** | Sit / Rest (boosts HP/MP regen 5×) |
| **Right-click + drag** | Camera control |
| **Left-click** | Click-target an enemy or NPC |
| **Tab** | Cycle target |
| **F1** | Target self |
| **F** | Interact / Talk to targeted NPC |
| **Enter** | Open chat input |
| **C / I / P / K / B / J** | Character / Inventory / Paperdoll / Tradeskill / Spellbook / Quest Journal |
| **Esc** | Options menu |

All keybinds are rebindable in **Options → Keybinds** (except Enter / Numpad Enter / Escape, which the chat and menu systems own).

---

## Saving

Saving is automatic. The game saves on:

- **Level up**
- **Zone change**
- **Quit** (whether you click the X button, hit Quit Game in Options, or close the launcher)

Save file lives at `%APPDATA%\Godot\app_userdata\Project_Dawn\character.save`. There's also a `.bak` rotated one alongside it in case the primary corrupts.

To start fresh, click **Delete Save** on the lobby screen, then **Test Room**.

---

## What works

A lot, actually:

- Combat: auto-attack, ~150 spells across 18 classes, active skills, crits, procs, slows/roots/stuns, AoE, damage shields, elemental resists.
- Inventory + 8-slot bag system with drag/drop, stacking, and a trash slot.
- Equipment / paperdoll with dual-wield gating.
- 4 starter quests with NPC dialogue trees (Aldric the Guard, Brom the Provisioner, Elara the General Merchant).
- Crafting: 15 tradeskills with stations and material gathering.
- Mining + skinning corpses.
- Day/night cycle with race vision (infravision / ultravision).
- 5 named/boss mobs with rare drops.
- Bind point + bind-affinity respawn.
- HUD scaling (Options → Graphics → UI Scale, 75 %–150 %).
- Settings persistence (keybinds, window mode, UI scale, panel positions).

## Known limitations

- **No multiplayer.** The lobby's Host/Join buttons exist but the server doesn't yet — Test Room is the only working entry point.
- **No sound** for combat, spells, ambience, or music. Coming.
- **No tutorial / signposting.** The world expects you to poke things.
- **No mounts, weather, or swimming** yet.
- **Player portrait / target-of-target frames** are stubs.
- **Faction / PvP** is not implemented.

The full backlog is in `CLAUDE.md` if you're curious.

---

## How to report a bug

**Easiest path:** in-game, hit **Esc** → **Report a Bug**. That opens our Discord invite in your browser:

> https://discord.gg/T77GRKNv

When you report, please include:

1. **What you were doing** when it happened.
2. **What you expected** vs. **what actually happened**.
3. **The debug log file**, attached to the message:
   - Path: `%APPDATA%\Godot\app_userdata\Project_Dawn\debug.log`
   - (Paste that into the Windows Explorer address bar — it'll open the right folder.)
4. **A screenshot or short video clip** if it's something visual.

Crashes, soft-locks, items disappearing, quests stuck, weird damage numbers, anything that feels wrong — we want all of it.

---

## UI feels too small or too big

Open **Esc → Options → Graphics → UI Scale** and drag the slider (75 %–150 %), then **Apply**. The HUD, windows, and chat scale together; the 3D world is unaffected.

If the whole window is wrong, change **Window Mode** and **Resolution** in the same panel.

---

Thanks for testing. Have fun — and break things.
