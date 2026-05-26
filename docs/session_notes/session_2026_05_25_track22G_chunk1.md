# Session 2026-05-25 — Track 22.G chunk 1: multi-window chat framework

Date: 2026-05-25.

Track 22.G ("EQ-style multi-window chat system") is the last open piece
of the Track 22 menu and the largest by far. The to-do list splits it
into three chunks — this session lands chunk 1 (framework + create /
rename / delete + layout persistence). Chunks 2 (per-window filters)
and 3 (per-window display settings) carry forward.

## Architecture change

`scripts/combat_log.gd` — the `CombatLog` autoload — used to be a
`CanvasLayer` that owned both the chat data path (signal subscriptions
to every gameplay system) and the chat UI (single ScrollContainer +
LineEdit). After this session it is a plain `Node` and a pure broker:
it still subscribes to all the gameplay signals, but instead of
rendering it emits `line_added(text: String, type: int)`. The UI moved
to a new `ChatWindow` class managed by a new `ChatWindowManager`
autoload.

Public API on `CombatLog` is preserved bit-for-bit — `add_line`,
`add_damage_out`, `add_evade`, `MsgType`, `chat_submitted` (signal),
`show_chat_input`, `is_chat_input_focused`. ~30 caller files were
unaffected.

## Files

New:
- `scripts/chat_window.gd` — `ChatWindow` extends `DraggablePanel`.
  Title bar (renameable), scroll + vbox for output, "▼ latest"
  auto-scroll button, per-window LineEdit at the bottom. Subscribes to
  `CombatLog.line_added` in `_ready`. Right-click on the panel emits
  `context_menu_requested(id, screen_pos)`; left-click emits
  `focus_requested(id)`. Mirrors the legacy `_color_for` switch so
  rendering can diverge per-window later (chunk 3).
- `autoloads/chat_window_manager.gd` — `ChatWindowManager` extends
  `CanvasLayer` (takes over the screen-attached role `CombatLog` used
  to have). Owns N `ChatWindow` instances, tracks the active window,
  builds the right-click `PopupMenu` (New / Rename / Delete; Delete
  disabled when only one window remains), owns the rename
  `AcceptDialog`. Persists layout through `GameSettings.chat_windows`
  on every rename / create / delete and on `_exit_tree`.

Refactored:
- `scripts/combat_log.gd` — dropped all UI code. `extends Node` (was
  `CanvasLayer`). New signals `line_added(text, type)` and
  `show_chat_input_requested()`. `show_chat_input()` emits the request;
  `is_chat_input_focused()` delegates to `ChatWindowManager`.
- `autoloads/settings.gd` — new `chat_windows: Array` field with
  load / save through the `[chat] windows` ConfigFile key.
- `project.godot` — `ChatWindowManager` registered as autoload at the
  end of the list (after `GameSettings`, since the manager reads
  `GameSettings.chat_windows` in `_ready`).
- `scripts/player.gd` line 95 — `CombatLog.visible = true` →
  `ChatWindowManager.visible = true`.
- `scripts/character_creation.gd` line 44 — same retarget for the
  hide-at-lobby case.
- `CLAUDE.md` — autoload table updated (`CombatLog` description now
  reflects broker role; `ChatWindowManager` added); chunk 1 checkbox
  ticked under the multi-window chat to-do entry.

## What works after this session

- Single default chat window with the legacy position / size on first
  run. Behaves identically to today for typing, scrolling, and the
  ▼-latest button.
- Right-click any window → New / Rename / Delete context menu.
- New windows cascade-offset by (24, 24) so they don't stack on top
  of each other.
- Rename via `AcceptDialog` with a `LineEdit` child; the title bar
  updates live.
- Delete frees the window (cannot delete the last one).
- Drag / resize via inherited `DraggablePanel` works.
- Layout persists across game restarts. Final state on quit is
  captured in `_exit_tree`.

## What's deferred to chunks 2 and 3

- Per-window message filters (chunk 2). Right now every window
  receives every line via the `CombatLog.line_added` subscription. The
  hook for filtering is `ChatWindow.add_line` — chunk 2 adds a filter
  set to each window and short-circuits before rendering.
- Per-window display settings (chunk 3) — alpha, font size, default
  channel.
- Tab docking. The handoff suggested it as part of chunk 1 but it's a
  meaningfully separate UI piece (drag-to-tab, tab strip, undock).
  Floating-only for now.

## Verification

Godot is not on the PATH on this workstation, so no automated checks.
Manual verification checklist for next playtest:

1. Launch the game. Confirm chat is hidden on the lobby / Enter World
   screen (matches legacy behaviour).
2. Enter world. Confirm a single chat window appears in the legacy
   bottom-left position, with the same colour scheme and message
   types as before.
3. Issue commands (e.g. `/say hello`, `/who`, attack a mob). Confirm
   lines render with the right colours.
4. Right-click the chat window. Confirm New / Rename / Delete menu;
   Delete should be greyed.
5. Pick **New Window**. Confirm a second window appears
   cascade-offset. Both windows receive every subsequent line.
6. Drag the second window. Confirm DraggablePanel cursor + resize
   margins still work.
7. Right-click the second window → Rename. Type "Combat" + Enter.
   Confirm title bar updates.
8. Right-click the second window → Delete. Confirm it goes away and
   the first window's Delete is still greyed.
9. Quit and relaunch. Confirm rename + position survive (read
   `user://settings.cfg` `[chat] windows` to see the dict array).

## Carry-forward

- Chunk 2 (per-window message filters): add a `MsgType` bitmask per
  window, a "Filters..." item in the context menu opening a
  multi-checkbox dialog, and a filter check at the top of
  `ChatWindow.add_line` before label creation.
- Chunk 3 (per-window display settings): add alpha / font size /
  default channel fields to `ChatWindow`, persist alongside layout,
  expose through a "Settings..." context menu item.
- Tab docking: separate UI piece. Drag-to-dock by detecting drop on
  another window's title bar; tab strip at the top; per-tab
  visibility toggle.
- Active-window tracking is currently first-window-default and
  last-mouse-down. `show_chat_input` focuses the active window's
  LineEdit. Chunk 3's default-channel field will key off the same
  active pointer.
