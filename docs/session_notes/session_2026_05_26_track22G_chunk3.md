# Session 2026-05-26 — Track 22.G chunk 3: per-window display settings

Date: 2026-05-26.

Final chunk of the multi-window chat plan. Each `ChatWindow` now has
its own background opacity, font opacity, font size, and default chat
channel. Tab docking remains as a separate follow-up — the three
chunks specified in the to-do list are all closed.

## Architecture

Four new instance fields on `ChatWindow`: `bg_alpha` (0–100),
`font_alpha` (10–100), `font_size` (9–21), `default_channel`
(`""`, `"say"`, `"shout"`, `"ooc"`, `"group"`). All persist through
the existing `get_layout` / `set_display_settings` dict round-trip
that chunks 1 and 2 already use.

`apply_display_settings` re-renders the panel (alpha) and walks
existing `_msg_vbox` labels to update font size and re-derive color
at the new alpha. The colour re-derivation needs the original
`MsgType` — once alpha has been baked into a `Color` it isn't
recoverable — so every label tags itself with `msg_type` meta at
`add_line` time and `apply_display_settings` reads it back via
`_color_with_alpha(type)`.

Default-channel routing lives entirely on the window side. When the
user submits a non-slash line and `default_channel` is set,
`_on_chat_text_submitted` prepends `/<channel> ` before emitting
`text_submitted`. Anything starting with `/` passes through, so a
user with a Say-default window can still type `/tell name ...` to
break out. The placeholder text on the LineEdit updates to
`[Say] Press Enter to type...` (or whichever channel) for visual
confirmation.

## Files

Touched:
- `scripts/chat_window.gd` — fields, constants (`BG_ALPHA_DEFAULT`,
  `FONT_ALPHA_DEFAULT`, `FONT_SIZE_DEFAULT`, `FONT_SIZE_MIN/MAX`,
  `FONT_ALPHA_MIN`, `CHANNEL_KEYS`, `CHANNEL_LABELS`),
  `_apply_panel_style` (alpha-driven), `_apply_input_placeholder`,
  `_color_with_alpha`, `apply_display_settings`, `set_display_settings`,
  `add_line` (font_size + alpha + msg_type meta),
  `_on_chat_text_submitted` (channel prepend), `get_layout` /
  `apply_layout` carry the four new fields.
- `autoloads/chat_window_manager.gd` — `_MENU_ID_DISPLAY` between
  Filters and Delete; `_build_display_dialog` (HSlider × 2, SpinBox,
  OptionButton); `_open_display_dialog` / `_on_display_confirmed`;
  small `_build_label` / `_build_slider_row` / `_attach_value_label`
  helpers to keep the builder readable. Restore path now also calls
  `w.set_display_settings(d)`.
- `CLAUDE.md` — chunk 3 + parent multi-window chat checkboxes ticked
  (tab docking called out as separate pending work).

## What works after this session

- Right-click any chat window → **Display...** opens the new dialog
  with two opacity sliders (live "%d" labels next to each), a font
  size SpinBox (9–21), and a default channel OptionButton (Default
  passthrough / Say / Shout / OOC / Group).
- OK applies and saves; existing rendered lines re-tint and resize
  in-place.
- Picking a default channel makes the input bar show
  `[Channel] Press Enter to type...`. Typing `hello` and Enter sends
  `/channel hello` through the existing hud command parser. Typing
  `/tell name hi` bypasses the default.
- All four fields persist across game restarts in
  `GameSettings.chat_windows`.

## What's deferred

- Tab docking. Drag-onto-title-bar to merge, tab strip rendering,
  undock drag to detach — design pass first, then implementation.

## Verification (manual)

1. Launch + enter world. Single default chat window with no visual
   change from chunk 2 (defaults match).
2. Right-click → confirm menu: New Window / Rename... / Filters... /
   Display... / Delete.
3. Pick **Display...**. Dialog shows two sliders at 80 and 100, font
   size 12, channel "Default (passthrough)".
4. Drag Window Opacity slider to ~30 → OK. Panel background goes
   visibly more transparent.
5. Re-open Display. Set Font Opacity to 30 → OK. Existing chat lines
   fade. New incoming lines also faded.
6. Re-open Display. Set Font Size to 18 → OK. Lines grow in place.
7. Re-open Display. Pick "OOC" as the default channel → OK. Press
   Enter; the input placeholder should read `[OOC] Press Enter to
   type...`. Type `hello` + Enter → confirm the chat log shows
   `[OOC] you: hello` (the same shape as if you'd typed `/ooc hello`).
8. With OOC default still set, type `/say hi` + Enter → confirm it
   went through Say, not OOC (slash-prefix override).
9. Quit + relaunch. All four settings survive. The dialog re-opens
   showing the persisted values.
10. Open the saved `settings.cfg` `[chat] windows=` entry — each
    window dict now has `bg_alpha`, `font_alpha`, `font_size`,
    `default_channel` keys.

## Carry-forward

- **Tab docking** is the last bit of the original multi-window chat
  ambition. Probably its own 1–2 session piece given drag-to-merge
  ergonomics and the visual tab strip.
- **"Enable All" / "Disable All" shortcut** in the Filters dialog —
  noted in chunk 2's carry-forward, still worth doing if 14
  checkboxes feels tedious.
- **`combat_log.gd` lives in `scripts/`** but is registered as an
  autoload — one-line `git mv` + `project.godot` update when we
  touch that area again.
