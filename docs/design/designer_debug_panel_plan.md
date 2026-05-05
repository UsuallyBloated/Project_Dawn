# Designer Debug Panel Expansion — Implementation Plan

## Context

`scripts/test_panel.gd` already exists as a CanvasLayer with a DraggablePanel child. It's flat and limited. Playtest notes request a tighter layout and additional tester controls — time of day control was the most explicitly requested. This plan expands the panel into a collapsible accordion of 7 named sections and adds 4 small flag additions to autoloads that the new sections depend on.

**Files changed:** 5 total — 4 autoloads (~3 lines each), 1 main rewrite (`test_panel.gd`).

---

## Step 1: Autoload flag additions (independent — do these first)

### `autoloads/combat.gd`
After `var _last_crit: bool = false` (~line 33), add:
```gdscript
var god_mode: bool = false
```
In `receive_player_damage()`, after the `PlayerDeath.is_dead` guard, insert:
```gdscript
if god_mode:
    return
```
Place before the attacker-signal emit so signals also suppress.

### `autoloads/spells.gd`
After `var _hit_during_cast: bool = false` (~line 15), add:
```gdscript
var no_cooldowns: bool = false
```
In `cast_spell()`, change the cooldown check:
```gdscript
# before
if _cooldowns.is_active(spell.spell_name):
# after
if _cooldowns.is_active(spell.spell_name) and not no_cooldowns:
```
Leave `_cooldowns.start()` in `_finish_cast()` untouched — timers still run, they just don't block.

### `autoloads/skills.gd`
Same pattern — add `var no_cooldowns: bool = false` after `var available`. Change cooldown guard in `use_skill()`:
```gdscript
if _cooldowns.is_active(skill.skill_name) and not no_cooldowns:
```

### `autoloads/time_of_day.gd`
After `var time_of_day: float = START_HOUR / 24.0` (~line 9), add:
```gdscript
var paused: bool = false
```
First line of `_process()`:
```gdscript
if paused:
    return
```
Sky and hour signal stay frozen while paused.

---

## Step 2: Refactor `scripts/test_panel.gd`

All existing color constants (`C_BG`, `C_BORDER`, `C_TITLE`, `C_TEXT`, `C_DIE`), helper methods (`_make_btn`, `_make_step_btn`, `_make_label`), and all existing action methods (`_full_heal`, `_trigger_death`, `_give_bags`, etc.) are **unchanged**. Only `_build_ui()` is rewritten and new members/methods are added.

### New file-level constants (add near top of file)

```gdscript
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const NORMAL_MOBS := [
    {"name":"Bandit",   "level":3, "max_hp":60.0,  "base_damage":8,  "xp_reward":30, "move_speed":3.0, "aggro_range":8.0},
    {"name":"Wolf",     "level":2, "max_hp":45.0,  "base_damage":6,  "xp_reward":20, "move_speed":4.0, "aggro_range":10.0},
    {"name":"Skeleton", "level":4, "max_hp":55.0,  "base_damage":9,  "xp_reward":35, "move_speed":2.8, "aggro_range":7.0},
    {"name":"Gnoll",    "level":5, "max_hp":80.0,  "base_damage":12, "xp_reward":45, "move_speed":3.2, "aggro_range":9.0},
]

const ZONES := [
    {"name": "World (Test Room)",  "path": "res://scenes/world.tscn",        "entry": "default"},
    {"name": "Dungeon World",      "path": "res://scenes/dungeon_world.tscn", "entry": "default"},
]

const STAT_KEYS := ["strength", "dexterity", "agility", "intelligence", "wisdom", "constitution"]
const STAT_ABBR := ["STR", "DEX", "AGI", "INT", "WIS", "CON"]
```

> **Note:** GDScript 4 does not allow `const` inside function bodies — all panel-specific constants must live at file scope.

### New member variables (add after existing declarations)

```gdscript
# Section content containers
var _sec_character: VBoxContainer
var _sec_resources: VBoxContainer
var _sec_time: VBoxContainer
var _sec_zone: VBoxContainer
var _sec_enemy: VBoxContainer
var _sec_stats: VBoxContainer
var _sec_combat: VBoxContainer

# Time section
var _time_label: Label
var _time_slider: HSlider

# Enemy section
var _normal_mob_opt: OptionButton
var _named_mob_opt: OptionButton

# Stats section
var _stat_labels: Array[Label] = []
```

### New helper: `_make_section(title: String, start_open: bool = false) -> VBoxContainer`

Add immediately after `_make_label()`. Appends a styled header Button + VBoxContainer to `_body`. Returns the VBoxContainer for the caller to populate.

```gdscript
func _make_section(title: String, start_open: bool = false) -> VBoxContainer:
    var header_btn := Button.new()
    header_btn.text = ("▾ " if start_open else "▸ ") + title
    header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_btn.focus_mode = Control.FOCUS_NONE
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.14, 0.11, 0.07, 1.0)
    s.border_color = C_TITLE
    s.set_border_width_all(1)
    s.set_corner_radius_all(3)
    s.content_margin_left = 6; s.content_margin_top = 4
    s.content_margin_right = 6; s.content_margin_bottom = 4
    header_btn.add_theme_stylebox_override("normal", s)
    header_btn.add_theme_stylebox_override("focus", s)
    var h := s.duplicate() as StyleBoxFlat
    h.bg_color = Color(0.22, 0.17, 0.09, 1.0)
    header_btn.add_theme_stylebox_override("hover", h)
    header_btn.add_theme_stylebox_override("pressed", h)
    header_btn.add_theme_color_override("font_color", C_TITLE)
    header_btn.add_theme_font_size_override("font_size", 11)
    _body.add_child(header_btn)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    content.visible = start_open
    _body.add_child(content)

    header_btn.pressed.connect(func():
        content.visible = not content.visible
        header_btn.text = ("▾ " if content.visible else "▸ ") + title
    )
    return content
```

### Rewrite `_build_ui()`

Change panel size to `Vector2(240, 640)`. Keep the DraggablePanel / MarginContainer / header-HBox / collapse-button structure **identical to today**. Replace the flat body contents with:

```gdscript
_sec_character = _make_section("CHARACTER", true)
_sec_resources = _make_section("RESOURCES", true)
_sec_time      = _make_section("TIME & WORLD")
_sec_zone      = _make_section("ZONE TRAVEL")
_sec_enemy     = _make_section("ENEMY SPAWN")
_sec_stats     = _make_section("STATS OVERRIDE")
_sec_combat    = _make_section("COMBAT FLAGS")
_build_character_section()
_build_resources_section()
_build_time_section()
_build_zone_section()
_build_enemy_section()
_build_stats_section()
_build_combat_section()
```

The `start_open: true` parameter sets both `content.visible = true` and the correct `▾` header text automatically.

---

### Section builders

#### `_build_character_section()`
Move existing race OptionButton, class OptionButton, level step-buttons+label, and Apply button verbatim into `_sec_character`. No behavior changes.

#### `_build_resources_section()`
Move all 8 existing item/heal/give buttons verbatim into `_sec_resources`. No behavior changes.

#### `_build_time_section()`
Populate `_sec_time`:
- `_time_label = _make_label("Current: " + TimeOfDay.get_time_string())`
- `_time_slider`: HSlider, `min_value=0.0`, `max_value=23.75`, `step=0.25`, `value=float(TimeOfDay.get_hour())`, SIZE_EXPAND_FILL; connect `value_changed` → `_on_time_slider_changed`
- Preset HBox with 4 step-style buttons (SIZE_EXPAND_FILL): **Dawn**(6), **Noon**(12), **Dusk**(18), **Night**(23) — each calls `_set_time(hour)`
- "Pause Cycle" CheckButton; `toggled` → `TimeOfDay.paused = on`

New methods:
```gdscript
func _on_time_slider_changed(value: float) -> void:
    TimeOfDay.time_of_day = value / 24.0
    _time_label.text = "Current: " + TimeOfDay.get_time_string()

func _set_time(hour: float) -> void:
    TimeOfDay.time_of_day = hour / 24.0
    _time_slider.value = hour
    _time_label.text = "Current: " + TimeOfDay.get_time_string()
```

Add `_process()` to keep the time label live while the section is visible:
```gdscript
func _process(_delta: float) -> void:
    if _collapsed or _time_label == null or not _sec_time.visible:
        return
    _time_label.text = "Current: " + TimeOfDay.get_time_string()
```
`_collapsed` is the existing bool on `test_panel.gd` that tracks the outer collapse state.

#### `_build_zone_section()`
Uses the file-level `ZONES` const (see above).

```gdscript
var zone_opt := OptionButton.new()
zone_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
zone_opt.focus_mode = Control.FOCUS_NONE
for z in ZONES:
    zone_opt.add_item(z["name"])
_sec_zone.add_child(zone_opt)

var teleport_btn := _make_btn("Teleport", Color(0.20, 0.45, 0.75, 1.0))
teleport_btn.pressed.connect(func():
    if ZoneLoader._transitioning:
        return
    var z: Dictionary = ZONES[zone_opt.selected]
    ZoneLoader.travel_to(z["path"], z["entry"], z["name"])
)
_sec_zone.add_child(teleport_btn)
```
`zone_opt` is a local variable captured by the lambda — no member variable needed.

#### `_build_enemy_section()`
Uses `NORMAL_MOBS` and `ENEMY_SCENE` file-level constants.

```gdscript
_sec_enemy.add_child(_make_label("Normal Mob"))
_normal_mob_opt = OptionButton.new()
_normal_mob_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
for mob in NORMAL_MOBS:
    _normal_mob_opt.add_item(mob["name"])
_sec_enemy.add_child(_normal_mob_opt)
_sec_enemy.add_child(_make_btn("Spawn Normal", Color(0.35, 0.55, 0.20, 1.0)))
# wire: pressed → _spawn_normal_enemy

_sec_enemy.add_child(_make_label("Named Mob"))
_named_mob_opt = OptionButton.new()
_named_mob_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
_sec_enemy.add_child(_named_mob_opt)
# _named_mob_opt is populated in _populate_options() → NamedMobDefinitions.ALL.keys()
_sec_enemy.add_child(_make_btn("Spawn Named", Color(0.65, 0.45, 0.10, 1.0)))
# wire: pressed → _spawn_named_enemy

_sec_enemy.add_child(HSeparator.new())
_sec_enemy.add_child(_make_btn("Despawn All Enemies", C_DIE))
# wire: pressed → _despawn_all_enemies
```

New methods:
```gdscript
func _get_spawn_pos() -> Vector3:
    var players := get_tree().get_nodes_in_group("player")
    if players.is_empty():
        CombatLog.add_line("TestPanel: no player found for spawn position", CombatLog.MsgType.SYSTEM)
        return Vector3.ZERO
    var p := players[0] as Node3D
    return p.global_position + (-p.transform.basis.z.normalized() * 3.0)

func _spawn_normal_enemy() -> void:
    var data: Dictionary = NORMAL_MOBS[_normal_mob_opt.selected]
    var e = ENEMY_SCENE.instantiate()
    e.mob_name    = data["name"]
    e.level       = data["level"]
    e.max_hp      = data["max_hp"]
    e.base_damage = data["base_damage"]
    e.xp_reward   = data["xp_reward"]
    e.move_speed  = data["move_speed"]
    e.aggro_range = data["aggro_range"]
    get_tree().current_scene.add_child(e)
    e.global_position = _get_spawn_pos()

func _spawn_named_enemy() -> void:
    var keys: Array = NamedMobDefinitions.ALL.keys()
    var e = ENEMY_SCENE.instantiate()
    get_tree().current_scene.add_child(e)
    e.global_position = _get_spawn_pos()
    e.apply_named(keys[_named_mob_opt.selected])    # MUST be after add_child

func _despawn_all_enemies() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(enemy):
            enemy.queue_free()
```

In `_populate_options()`, add after existing race/class population:
```gdscript
for key in NamedMobDefinitions.ALL.keys():
    _named_mob_opt.add_item(key)
```

#### `_build_stats_section()`
Loop `STAT_KEYS` to build 6 rows, each: abbr label (min_width 28) + `−` step btn + value label (EXPAND_FILL, C_TITLE, font size 13) + `+` step btn. Value label appended to `_stat_labels`. "Reset Stats" button at bottom.

```gdscript
func _change_stat(idx: int, delta: int) -> void:
    var key := STAT_KEYS[idx]
    PlayerStats.set(key, clampi(int(PlayerStats.get(key)) + delta, 1, 255))
    _stat_labels[idx].text = str(int(PlayerStats.get(key)))
    PlayerStats.stats_changed.emit()

func _reset_stats() -> void:
    PlayerStats.apply_character(PlayerStats.race, PlayerStats.player_class, PlayerStats.level)
    for i in STAT_KEYS.size():
        _stat_labels[i].text = str(int(PlayerStats.get(STAT_KEYS[i])))
```

#### `_build_combat_section()`
```gdscript
# God Mode CheckButton
var god_check := CheckButton.new()
god_check.text = "God Mode"
god_check.focus_mode = Control.FOCUS_NONE
god_check.add_theme_color_override("font_color", C_TEXT)
god_check.toggled.connect(func(on: bool): Combat.god_mode = on)
_sec_combat.add_child(god_check)

# No Cooldowns CheckButton
var cd_check := CheckButton.new()
cd_check.text = "No Cooldowns"
cd_check.focus_mode = Control.FOCUS_NONE
cd_check.add_theme_color_override("font_color", C_TEXT)
cd_check.toggled.connect(func(on: bool):
    Spells.no_cooldowns = on
    Skills.no_cooldowns = on
)
_sec_combat.add_child(cd_check)

# Clear All Buffs
var clear_btn := _make_btn("Clear All Buffs", Color(0.60, 0.20, 0.50, 1.0))
clear_btn.pressed.connect(func(): BuffManager.clear_all())
_sec_combat.add_child(clear_btn)
```

---

## Critical Files

| File | Change |
|---|---|
| `autoloads/combat.gd` | +`god_mode` var, +guard in `receive_player_damage()` |
| `autoloads/spells.gd` | +`no_cooldowns` var, cooldown bypass in `cast_spell()` |
| `autoloads/skills.gd` | +`no_cooldowns` var, cooldown bypass in `use_skill()` |
| `autoloads/time_of_day.gd` | +`paused` var, early return in `_process()` |
| `scripts/test_panel.gd` | Rewrite `_build_ui()`, add section builders + new action methods |

**Read-only references (do not modify):**
- `scripts/draggable_panel.gd` — `setup()`, `apply_style()` API
- `data/named_mob_definitions.gd` — `NamedMobDefinitions.ALL.keys()`
- `scenes/enemy.tscn` — preloaded for spawn
- `autoloads/buff_manager.gd` — `clear_all()`
- `autoloads/zone_loader.gd` — `travel_to()`, `_transitioning`

---

## Implementation Order

1. `combat.gd`, `spells.gd`, `skills.gd`, `time_of_day.gd` — all independent, can be done in any order or simultaneously
2. `test_panel.gd` — depends on all four autoload changes being present so GDScript type-checking passes

---

## Verification Checklist

- [ ] **God Mode**: enable, walk into enemy — no HP loss; disable — damage lands
- [ ] **No Cooldowns**: cast spell to put on CD, toggle on, re-cast immediately — no "on cooldown" message
- [ ] **Time slider**: drag to 12.0 — sky transitions to noon, label updates live
- [ ] **Presets**: Dawn/Noon/Dusk/Night each snap sky correctly
- [ ] **Pause Cycle**: wait 30s — `get_time_string()` unchanged; unpause — time resumes
- [ ] **Zone Travel**: teleport to Dungeon World — transition fires, player arrives
- [ ] **Teleport mid-transition**: press Teleport while transitioning — no-op (guarded)
- [ ] **Spawn Normal**: each archetype spawns 3m in front of player with correct stats
- [ ] **Spawn Named "rotfang"**: gold nameplate, scaled HP/damage
- [ ] **Despawn All**: clears all enemies from scene
- [ ] **Stats ±**: increment STR 5 times — `PlayerStats.strength` increments, HUD updates
- [ ] **Reset Stats**: values return to class baseline via `apply_character()`
- [ ] **Clear All Buffs**: active buffs removed from buff bar
- [ ] **Accordion**: CHARACTER + RESOURCES open by default (▾); all others collapsed (▸); headers toggle independently
- [ ] **Outer collapse (−/+)**: hides entire body including all sections
- [ ] **Existing buttons**: Full Heal, Give Items, etc. work identically after refactor
