# Session 2026-05-26 — Track 22.G chunk 4: tab docking

Date: 2026-05-26.

Final chunk of the multi-window chat work. Users can now dock multiple
chat windows together as tabs in a single window frame, save screen
real estate, and reorganize on the fly via drag.

## Architecture

Every `ChatWindow` carries a `group_id: int`. Solo windows live in a
group of 1 keyed by their own `window_id` — the keys-equal-window-id
invariant lets `new_window` allocate a fresh group id for free.
Multi-tab groups share a position and size: the active member renders
the panel + tab strip; non-active members are entirely hidden
(`visible = false`) so the panel doesn't double-render.

`ChatWindowManager._groups: Dictionary[int, {members, active}]` is the
authoritative grouping state. Three ops mutate it:

- `dock(source_id, target_group_id)` — remove from old group, append
  to target, snap pos/size to the target's active, and make the
  newly docked tab the active one.
- `undock(member_id, screen_pos)` — remove from group, allocate a
  new group keyed by member_id, drop the window at the cursor.
- `set_active_tab(group_id, new_active_id)` — swap visibility,
  carrying the old active's pos/size over to the new active so the
  frame stays put when tabs switch.

Each op ends with `_refresh_group` calls on the affected groups,
which iterate members and call `ChatWindow.set_group_state(members,
active_id)` so each window can choose between solo rendering (title
bar) and grouped rendering (tab strip).

## Drag UX

Two distinct gestures:

1. **Window drag → merge.** `ChatWindow` overrides `DraggablePanel`'s
   `_stop_interaction` and emits `drag_ended(id, drop_pos)` only when
   the interaction was a drag (not a resize). The manager hit-tests
   the drop point against every other window's `get_drop_target_rect()`
   (title bar when solo, tab strip when grouped), excluding the
   source's own group; first hit triggers `dock`.

2. **Tab drag → undock.** Tab buttons in the strip connect to a
   `gui_input` handler that distinguishes click from drag by motion
   distance (`_TAB_DRAG_THRESHOLD = 8 px`). A click activates the
   tab; a drag that ends outside the strip emits
   `tab_dragged_out(member_id, drop_pos)` which the manager routes to
   `undock`. A drag that stays in the strip is currently a no-op (a
   future polish pass could implement intra-strip reordering here).

Hit-testing avoids the obvious dragged-window-on-top trap (Godot's
`gui_get_hovered_control` returns a child of the dragged window
because it's drawn last). Instead we iterate `_windows` directly and
ask each non-source window for its current drop rect.

## Persistence

`group_id` rides along on the existing per-window layout dict in
`GameSettings.chat_windows`. On restore, after every window has been
instantiated and added, the manager walks `_windows` and rebuilds
`_groups` by appending each window's id to its saved group_id's
members list. The first member encountered in each group becomes the
restored active (carry-forward: persisting the explicit active tab is
a small polish item — see notes).

## Files

Touched:
- `scripts/chat_window.gd` — `group_id` field, `is_active_tab` flag,
  `_title_bar` wrapper Control (for show/hide), `_tab_strip`
  HBoxContainer, `set_group_state` API (`_set_solo` / `_set_grouped`),
  `_populate_tab_strip`, `_on_tab_button_gui_input` (click-vs-drag
  gesture), `_stop_interaction` override emitting `drag_ended`,
  `get_drop_target_rect` helper. `get_layout` / `apply_layout` carry
  `group_id`. Three new signals: `drag_ended`, `tab_activated`,
  `tab_dragged_out`.
- `autoloads/chat_window_manager.gd` — `_groups` state, `dock` /
  `undock` / `set_active_tab` / `_refresh_group` /
  `_remove_from_group` / `_find_dock_target`. Three new handlers
  wired in `_wire_window_signals` (drag_ended, tab_activated,
  tab_dragged_out). `new_window` registers a solo group;
  `delete_window` removes from group with auto-dissolve;
  `rename_window` refreshes tab strips of siblings; restore rebuilds
  `_groups` and picks a visible initial active.
- `CLAUDE.md` — tab docking checkbox added to the multi-window chat
  to-do.

## What works after this session

- Right-click → New Window twice. Drag the second onto the first's
  title bar. Drop. Now one window frame with two tabs at the top.
- Click a tab to switch. The frame stays put; content changes.
- Drag any tab out of the strip and drop in empty screen space.
  Tab becomes a floating solo window at the cursor.
- Drag a tab onto a third window's title bar. Three tabs now.
- Lines accumulate into all group members' hidden vboxes — switching
  tabs shows the history that arrived while the tab was off-screen.
- All filters and display settings remain per-window; switching
  tabs applies the new active's bg_alpha / font_size / etc.
- Layout persists. Reload → same groups.

## What's deferred

- Persistence of the explicit active tab per group. Currently the
  first-encountered member is restored as active; if the user had
  switched to a non-first tab before quit, that doesn't survive.
  Small fix: add `active_tab: bool` to each window's layout dict and
  honor it during group rebuild.
- Visual drag preview / drop-zone highlight. Drops are silent — the
  user discovers a successful merge by the result, not by feedback
  during the drag.
- Intra-strip tab reorder (drag a tab to a new index in the same
  group).
- Context-menu fallback (`Dock to >` / `Undock`) — useful for
  accessibility if a user can't reliably drag. Easy to add later.

## Verification (manual)

1. Launch + enter world. Single chat window, title bar reads "Chat".
2. Right-click → New Window. Second window appears cascade-offset.
   Both show title bars.
3. Drag window 2's title bar onto window 1's title bar. Drop.
   Window 2 disappears as a separate frame; window 1's title bar is
   replaced by a tab strip with two buttons.
4. Click the inactive tab in the strip. Frame stays at the same
   position/size; the OTHER window's chat history is now visible.
5. Drag the now-active grouped window. The whole frame moves. Drop
   in empty space (not on another window). Position updates; no
   docking.
6. Right-click → New Window again. Window 3 spawns solo elsewhere.
7. Drag window 3 onto the grouped frame's tab strip. Three tabs now;
   window 3 is the new active (you dropped it, you see it).
8. Trigger a chat line (kill a mob, /say something). Confirm it
   appears in the solo window 1, and that switching the group to
   the previously-hidden tab also shows it (line was accumulated).
9. Grab the leftmost tab and drag it out of the strip, drop it on
   empty screen. That tab becomes a solo window at the drop point.
10. Quit and relaunch. Confirm the solo + grouped state survives,
    each window's filters and display settings restore.
11. Open `settings.cfg` `[chat] windows=` entry. Each dict has a
    `group_id` field; grouped windows share the same value.

## Bug fixes during playtest (2026-05-28)

Three issues surfaced once the user started exercising the dock UX:

1. **Group-key collision.** Group ids were keyed by `window_id` (the
   "keys-equal-window-id" invariant), but when window B docks onto
   window A's group, that group keeps key A. Undocking A then ran
   `_groups[A.window_id] = {...}` and overwrote the live merged
   group, orphaning B. Fix: separate `_next_group_seq` counter;
   `_allocate_group_id()` used in both `new_window` and `undock`.
   Restore bumps `_next_group_seq` past any saved id.
2. **Hidden tab as ghost dock target.** `get_drop_target_rect()`
   returned the tab strip's rect even when the panel was
   `visible=false`, because `_tab_strip.visible` stays true from
   when the window was last active. Added a `not visible` early-out.
3. **Right-click captured cursor on UI + cursor snapped to centre
   on release.** `player.gd._physics_process` unconditionally
   switched to `MOUSE_MODE_CAPTURED` on right-click hold, which
   (a) snapped the cursor to centre when the user only meant to
   open a chat context menu, and (b) Godot's `Input.warp_mouse` +
   `Viewport.get_mouse_position` round-trip drifted by a constant
   offset due to canvas vs window transform mismatch. Two-part fix
   in `player.gd`: gate the transition-into-camera-mode on
   `gui_get_hovered_control() == null` so right-clicks on UI don't
   capture, and use `DisplayServer.mouse_get_position` /
   `DisplayServer.warp_mouse` (raw screen coords, no transforms)
   for the save/restore round-trip.

## Carry-forward

- Persist active tab per group (small follow-up, ~5 minutes).
- Visual drag preview / drop-zone highlight (polish).
- Intra-strip reorder (small piece, mostly UX decision).
- Context-menu fallback for accessibility (optional).
- `combat_log.gd` still lives in `scripts/` but is registered as an
  autoload — one-line `git mv` + `project.godot` update when we
  next touch that area.
