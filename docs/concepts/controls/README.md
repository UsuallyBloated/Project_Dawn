# Controls & Keybindings

The control scheme is modeled on classic EverQuest-era MMOs: a rebindable keyboard
layout plus a three-state mouse rig (left-drag, right-drag, both-buttons) that lets you
move, steer, and look around independently.

This doc is the **design spec + reference** for that scheme. It tracks both what exists
today and the EQ-style target we're building toward.

**Sources of truth (don't let this doc drift from them):**
- Keyboard binds — `autoloads/settings.gd` → `REBINDABLE_ACTIONS` (the rebind UI in
  `scripts/options_screen.gd` writes these; they persist to `user://settings.cfg`).
- Mouse / camera rig — `scripts/player.gd` (`_input`, `_unhandled_input`, `_physics_process`).
- A few diagnostic keys are hardcoded on purpose (see *Non-rebindable keys* below).

---

## The mouse scheme (the EQ feel we want)

Classic EQ's mouse control separates **where the camera looks** from **where the
character faces**, and uses both buttons together as a "run" pedal. Three states:

| Input | Effect | Character facing? |
|---|---|---|
| **Right-button hold + drag** | **Mouselook / steer.** Camera *and* character body turn together. Release and the character stays pointed where you left it. | **Yes** — body turns |
| **Left-button hold + drag** | **Camera-only orbit.** The camera swings around the character so you can glance around (e.g. look behind while running forward). Body keeps its facing. | **No** — body unchanged |
| **Both buttons held** | **Run forward.** Character runs forward continuously; steer with the right button while holding both. | Follows right-button steer |

Mnemonic players used: the right button is the steering wheel, both-buttons is the gas pedal.

Supporting bits:
- **Wheel** — zoom the third-person camera in/out (through first-person at the near end).
- **Mouselook toggle** — a sticky version of right-button mouselook so you don't have to
  hold the button. EQ default `F12`. Frees the cursor for UI when toggled off.
- **UI gating** — left/right drag only drive the camera when the drag *starts over the 3D
  world*, never when it starts over a HUD widget or window. This is what lets "free mouse
  to click UI" coexist with drag-to-look. (Already implemented for right-click; the same
  `gui_get_hovered_control() == null` gate applies to the new left-drag and both-buttons.)

### Implementation status

| Feature | State | Where |
|---|---|---|
| Right-button mouselook (turns body, pitches camera) | ✅ Done | `player.gd::_input` |
| Wheel zoom, clamped, UI-gated | ✅ Done | `player.gd::_unhandled_input` |
| Right-click UI gate + cursor capture/restore | ✅ Done | `player.gd::_update_mouse_camera` |
| **Both-buttons run forward** | ✅ Done | `player.gd::_physics_process` (`mouse_run`) |
| **Left-button camera-only orbit** | ✅ Done | `player.gd::_update_mouse_camera` + `_input` |
| **Mouselook toggle (`F12`)** | ✅ Done | `player.gd` (`_mouselook_toggled`) + `settings.gd` |

### How it works now (`scripts/player.gd`)

The whole rig lives in `_update_mouse_camera()` (polled every physics tick so it survives
UI panels eating the button event) plus the motion handler in `_input()`:

- **Camera state is two explicit Euler floats** — `_cam_pitch` (shared) and `_cam_yaw`
  (offset behind the body, left-drag only) — applied via `_apply_camera_pivot()`. Holding
  them as floats instead of calling `rotate_x`/`rotate_y` on the pivot means re-centering
  can't accumulate roll.
- **Right-drag** turns the body (`rotate_y` on the `CharacterBody3D`); the pivot stays
  locked behind it and `_cam_yaw` re-centers to 0.
- **Left-drag** moves only `_cam_yaw`. It engages **only after the cursor passes
  `CAMERA_DRAG_THRESHOLD`** while the left button is held — below that, the press is a
  clean click and falls through to `Targeting.click_target()` for target selection. This
  is why target-select moved from press-time (in `targeting.gd`) to release-time
  (in `player.gd`): a left-drag to look around must not clobber your target.
- **Both buttons** = `mouse_run`: when right-button mouselook is active and left is also
  held, the body runs forward (steered by the right-button look). Works regardless of
  chat focus since it's an explicit mouse gesture, not a key that could leak from typing.
- **Re-center**: `_cam_yaw` lerps back to 0 (`CAM_YAW_RECENTER_RATE`) whenever you steer
  or move, and holds wherever you leave it when you stand still — EQ's "glance around,
  snaps back when you run."
- **Mouselook toggle** (`F12`, rebindable as `toggle_mouselook`): `_mouselook_toggled`
  latches the right-drag steer on hands-free — it acts like a held right button so the
  body steers with the mouse while you move on the keyboard. It **stands down while a text
  field is focused** so the cursor frees up for chat/UI, then re-engages when you close it.
- **UI gating**: every drag mode only engages when `gui_get_hovered_control()` is null at
  press time, so clicking HUD/windows still works. `_update_mouse_camera` is the single
  owner of `Input.mouse_mode` (capture on drag, restore the cursor to the press point).

The EQ-style mouse scheme is now feature-complete; remaining parity items are
keyboard-side (see the reference section below).

> Note: left-click is also the home of UI clicks, world-target selection, and (future,
> EQ-style) auto-attack engage. The click-vs-drag split in `_update_mouse_camera` keeps
> left-**drag** (camera) distinct from left-**click** (select), all behind the UI gate.

---

## Default keybindings

Rebindable in Options → Controls. Defaults below come from
`settings.gd::REBINDABLE_ACTIONS`.

### Movement
| Action | Default | Id |
|---|---|---|
| Move Forward | `W` | `move_forward` |
| Move Back | `S` | `move_backward` |
| Strafe Left | `A` | `move_left` |
| Strafe Right | `D` | `move_right` |
| Jump | `Space` | `jump` |
| Autorun | `\` | `toggle_autorun` |
| Crouch | `X` | `toggle_crouch` |
| Sit / Rest | `Z` | `toggle_sit` |

Autorun is a latched run-forward (EQ-style): tap it to start, tap `S` (back) or re-press
to cancel. It survives chat focus since it's latched state, not a held key.

### Combat / targeting
| Action | Default | Id |
|---|---|---|
| Cycle Target | `Tab` | `target_cycle` |
| Target Self | `F1` | `target_self` |
| Target Group 1–5 | `F2`–`F6` | `target_group_1` … `target_group_5` |
| Toggle Auto Attack | `Q` | `toggle_auto_attack` |

Group-target keys select the Nth *other* group member in roster order
(`autoloads/targeting.gd::_target_group_slot`). A member who isn't loaded in-zone has no
node to target, so it logs "not nearby" instead — our combat targeting is node-based.

### Camera
| Action | Default | Id |
|---|---|---|
| Toggle Mouselook | `F12` | `toggle_mouselook` |
| Cycle Camera View | `F9` | `cycle_view` |

`F9` cycles first-person → close third-person (3.0) → far third-person (7.0). First-person
hides the own capsule (`Visual`) once the camera is within `FIRST_PERSON_HIDE_DIST`; the
mouse wheel can also scroll all the way into first-person (`ZOOM_MIN` is 0).

### World
| Action | Default | Id |
|---|---|---|
| Interact / Talk | `F` | `interact` |

### Windows
| Action | Default | Id |
|---|---|---|
| Character Window | `C` | `toggle_character` |
| Inventory Window | `I` | `toggle_inventory` |
| Paperdoll Window | `P` | `toggle_paperdoll` |
| Tradeskill Window | `K` | `toggle_crafting` |
| Spellbook | `B` | `toggle_spell_book` |
| Quest Journal | `J` | `toggle_quest_journal` |

### Hotbar / hotkeys (hardcoded in `scripts/hotbar.gd`)
| Input | Effect |
|---|---|
| `1`–`0` | Fire social hotkey / hotbar slot 1–10 (`SocialHotkeys.execute_slot`) |
| `Alt`+`1`–`0` | Cast the memorized spell in spell-bar slot 1–10 (`SpellBar.cast_slot`) |

### Non-rebindable keys (reserved / diagnostic — intentionally fixed)
| Input | Effect | Why fixed |
|---|---|---|
| `Enter` / `KP Enter` | Open chat input | Reserved (`RESERVED_KEYS`) |
| `Esc` | Close top window → else toggle Options | Reserved (menu nav) |
| `` ` `` (backtick) | Toggle in-game debug console | Diagnostic tool, not a gameplay control (`scripts/debug_console.gd`). `F2` used to do this too but is now group-target 1. |
| `/console` (chat command) | Fallback console toggle when the keybind isn't reaching the window | Same |

---

## Reference: classic EverQuest default binds

For parity decisions as we flesh out targeting/camera. We don't have to match these
1:1 — they're the north star, not a spec. `/bind eqlist` in EQ dumps the full set.

- **Movement** — `W/A/S/D` or arrow keys; `Num Lock` = autorun toggle.
- **Targeting** — `F1` self, `F2`–`F6` group members 1–5, `F7` nearest PC, `F8` nearest NPC.
- **Camera / view** — `F9` cycle camera views, `F10` toggle UI, `F12` toggle mouselook,
  `Home`/`Num 5` recenter, `PgUp`/`PgDn` pitch, `Ins`/`Del` zoom.
- **Combat** — `Q` auto-attack, `H` hail, `Ctrl`+click force/PvP attack.
- **Windows** — `Alt+I` inventory, `Alt+S` spellbook, `Alt+B` buffs, `Alt+C` chat,
  `Alt+P` group, `Alt+T` target, `Alt+O` options.
- **Misc** — `R` reply to last `/tell`, hotbar on the number row.

All three of the keyboard-parity gaps once listed here are now implemented: group-member
target keys (`F2`–`F6`), the autorun toggle (`\`), and the camera-view cycle (`F9`).
Remaining EQ binds not yet mirrored: `F7`/`F8` nearest-PC/NPC target, `F10` UI toggle,
`H` hail, and the `Alt`+letter window shortcuts.

Sources:
[Movement and Commands — EverQuest Wiki](https://everquest.fandom.com/wiki/Movement_and_Commands) ·
[Controls/Mouselook — Project 1999](https://www.project1999.com/forums/showthread.php?t=33167) ·
[EverQuest Shortcut Hot Keys](https://www.onlinegamecommands.com/everquest-shortcut-hot-keys/)
