# Handoff: ten UI themes and the picker in Options, Interface

*Written 2026-11-18 for whichever session continues it (the user: "I would like the other
UI options you listed designed and the option to change added to the options screen ->
interface. You might want to write a plan that an opus 5.5 could follow."). Each step says
what exists when it is done and how it is checked, so a fresh session can pick up at any
line. Work on `feat/ui-theme` in `F:\Projects\Project_Dawn-theme` (client only; merges at
the bump after the door). Read `session_2026_11_18_r5_ui_theme.md` first: it says how the
one theme that exists was built and what holds it.*

## 0. What exists at the start

- `assets/ui/dark_wood_brass.tres`, hand-written: the project theme (`project.godot`,
  `gui/theme/custom`). Eight variations (`WindowPanel`, `SectionPanel`, `SlotCell`,
  `Tooltip`, `SpeechPanel`, `BarStrip`, `TitleLabel`, `CoinsLabel`) and type defaults
  (Label, Button, CheckBox, CheckButton, ItemList, LineEdit, TabBar, TabContainer).
- `scripts/ui_theme.gd` (`UITheme`): `const` colours the runtime code reads (bars, states,
  rarities, the character creation screen).
- `tools/check_ui_theme_lockstep.gd`: the theme's values equal `UITheme`'s; every
  variation a script names is defined.
- `tools/probe_window_geometry.gd` + `tools/fixtures/window_geometry.txt`: the layout net.
  **Every theme must keep the structural numbers identical** (border widths, content
  margins) so one fixture holds for all ten; only colours, corner radii and shadows vary.
- `tools/shot_windows.gd`: screenshots from a windowed run (`-- --out <dir>`).
- `autoloads/settings.gd` (`GameSettings`): `user://settings.cfg`, `apply_all()` at boot and
  on Apply, `load_settings()` / `save_settings()`.
- `scripts/options_screen.gd`: the Interface tab is `_build_interface_tab()`;
  `_load_from_settings()` and `_on_apply()` move the values.

## 1. The shape (decided here, not open)

1. **Palettes as data, themes generated.** `data/ui_theme_palettes.gd` holds the ten
   palettes (about sixteen colours each plus a corner radius and a shadow size).
   `tools/author_ui_themes.gd` renders every palette into
   `assets/ui/themes/<id>.tres` through ONE template, so the structure (and the
   structural numbers) cannot drift between themes. The hand-written file is replaced by
   the generated `dark_wood_brass` (same values; the diff shows it).
2. **`UITheme` becomes runtime.** Its `const` colours become `static var`s with the dark
   wood values as defaults, and `UITheme.apply_palette(id)` sets them from the palette
   table. Every `UITheme.C_X` read in the scripts keeps compiling unchanged.
3. **Switching.** `GameSettings.ui_theme` (a palette id, default `dark_wood_brass`),
   persisted; `GameSettings.apply_ui_theme()` loads the theme file, sets
   `get_tree().root.theme` (the root Window's theme covers every Control) and calls
   `UITheme.apply_palette`. `apply_all()` calls it, so it applies at boot and on Apply.
   `project.godot` keeps `gui/theme/custom` on dark wood: what headless checks and the
   first frame see before settings load.
4. **The picker.** Options, Interface: a "UI theme" row with an `OptionButton` of the ten
   display names, under the floating-text block. Apply sets it. One line of small text
   under it: panels built from the palette at runtime (bars, slot tints) take the new
   colours on the next login; everything theme-driven changes at once.
5. **The check.** `check_ui_theme_lockstep.gd` grows: for every palette the rendered text
   equals the file on disk (a stale file says "run the author tool"); every variation a
   script names exists in every theme; the structural numbers of every theme equal the
   reference's; `UITheme`'s defaults equal the dark wood palette; the default id is a known
   palette.
6. **Screenshots.** `shot_windows.gd` takes `-- --theme <id>` and shoots each theme; the
   ten pairs go to the user to pick, keep or retune.

## 2. Steps, each its own commit

| # | Step | Done when | Checked by |
|---|---|---|---|
| 1 | `data/ui_theme_palettes.gd` with the ten palettes and `tools/author_ui_themes.gd`; run it; delete the hand-written file; `project.godot` points at `assets/ui/themes/dark_wood_brass.tres` | ten files under `assets/ui/themes/`, the dark wood one equal in values to the old | the lockstep check still green; `git diff` on the dark wood values |
| 2 | `UITheme` to `static var` + `apply_palette`; the check compares its defaults to the palette | nothing else changes | all checks and probes green |
| 3 | `GameSettings.ui_theme` + `apply_ui_theme()` in `apply_all()`, load and save | a hand-edited `settings.cfg` with another id boots into that theme | a probe: set the id, call apply, read `root.theme.resource_path` and a `UITheme` colour |
| 4 | the Interface tab row, load and apply | pick a theme, Apply, every window changes; relaunch keeps it | the probe extended through the options screen; `probe_ui_scale_persists.gd` as the pattern |
| 5 | the check's new rows | a planted stale file, a missing variation in one theme, a changed border width each fail | run the check with each fault planted |
| 6 | `shot_windows.gd -- --theme`; shoot all ten; send to the user | twenty PNGs | the user's eye |
| 7 | records: session note, To-Do entry (the UI theme entry under UI polish), `commands.md` for the author tool and the shot tool, memory | | |

## 2b. Status

Steps 1 to 6 DONE 2026-11-18 the same night (branch `feat/ui-theme`, commits `3445bfb` and the one after); step 7's records in `session_2026_11_18_r5_ui_theme.md` §7, `commands.md` and the To-Do entry. One trap found on the way is now the first bullet below.

## 3. Traps

- **An unstyled `Panel` or `PanelContainer` shows the engine's grey under every theme.** The template now gives `Panel` the section box as its type default; a `PanelContainer` built in code with no variation (the login frame was one) still needs a variation named, because a `PanelContainer` default would move every container's contents by its margins.
- **A Control under a `CanvasLayer` inherits nothing from the root window's `theme`**: it has no theme owner and falls back to the project theme. Switching themes at runtime means pouring the chosen theme INTO the project theme resource (`ThemeDB.get_project_theme()`, `clear()`, `merge_with()`), never setting `root.theme`. The first build set the root and every HUD window stayed walnut; a probe under the root alone passed, so the probe now tests under a CanvasLayer.

- `theme_type_variation` on a node whose class differs from the variation's base still
  resolves (the lookup walks the variation first); the editor merely filters the list.
- A `StyleBoxFlat` with no content margins uses its border width as the margin: a
  `PanelContainer` (tooltip, speech, the notice) moves its children when the border width
  changes. Keep border widths identical across themes; vary colours, radii and shadows only.
- `CheckBox` and `CheckButton` inherit `Button`'s boxes through the class chain: give them
  empty boxes with 4 px margins or they grow brass plates (and shrink by 7 px without the
  margins).
- `TabContainer/styles/panel` content margins move the tab contents; 0 keeps them.
- The headless `--import` must run once in a cold worktree before any check.
- `python3` in bash is the Store alias; use the full path under `AppData\Local\Programs`.
- Python cannot read bash's `/tmp`; put scratch files in the scratchpad directory.
- Cut by function name, never by span: the vendor conversion once removed `open_for` that
  sat between two build functions (caught by a probe within the minute).
