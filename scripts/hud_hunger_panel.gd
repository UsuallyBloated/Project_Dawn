extends DraggablePanel

# The hunger window (docs/design/food_and_water.md section 8): two rows, a
# label and a bar each, for the local player's food and water. The server owns
# the counters and the rule (no food, no HP regen; no water, no mana regen);
# this panel only draws them. It is fed by Net.world_hunger, which the server
# sends on entering the world, after any eat or drink, on a stage change, on
# death and respawn, and about once a minute; between sends the bars run down
# at the rate the server gave, so they move smoothly and the next send only
# corrects drift. Hidden until the first update, so the offline Test Room
# (no server) never shows an empty window.

# Must match HUNGRY_AT_SECS in the server's world/hunger.rs (twelve 144 s
# units): the bar turns amber when the server would say "You are hungry."
const HUNGRY_AT_SECS := 1728.0
# How close to the cap counts as full when a hand-eat is asked for. The
# server refuses within half a second of the cap; the client's bar can trail
# the server by a round trip of drain, so it allows a little more.
const FULL_MARGIN_SECS := 2.0
const TOOLTIP_REFRESH_SECS := 1.0
const FLASH_SECS := 0.18

const C_FED := Color(0.35, 0.70, 0.30)
const C_HUNGRY := Color(0.90, 0.60, 0.10)
const C_OUT := Color(0.80, 0.10, 0.10)
const C_FLASH := Color(1.6, 1.6, 1.6)

@onready var _food_bar: ProgressBar = $VBox/FoodRow/FoodBar
@onready var _drink_bar: ProgressBar = $VBox/DrinkRow/DrinkBar
@onready var _food_label: Label = $VBox/FoodRow/FoodLabel
@onready var _drink_label: Label = $VBox/DrinkRow/DrinkLabel

var _hunger: float = 0.0
var _thirst: float = 0.0
var _cap: float = 1.0
var _rate: float = 0.0
var _tooltip_timer: float = 0.0
var _food_fill: StyleBoxFlat = null
var _drink_fill: StyleBoxFlat = null


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.02, 0.80)
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)
	for label in [_food_label, _drink_label]:
		label.add_theme_color_override("font_color", UITheme.C_TEXT)
	UITheme.style_bar(_food_bar, C_FED, false)
	UITheme.style_bar(_drink_bar, C_FED, false)
	_food_fill = _food_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_drink_fill = _drink_bar.get_theme_stylebox("fill") as StyleBoxFlat
	Net.world_hunger.connect(apply_update)
	Net.hand_eat_requested.connect(_on_hand_eat_requested)


## Adopt the server's values. Public so a headless probe can drive it.
func apply_update(hunger_secs: float, thirst_secs: float, cap_secs: float, drain_per_sec: float) -> void:
	_hunger = maxf(hunger_secs, 0.0)
	_thirst = maxf(thirst_secs, 0.0)
	_cap = maxf(cap_secs, 1.0)
	_rate = maxf(drain_per_sec, 0.0)
	visible = true
	_redraw()
	_refresh_tooltips()


func _process(delta: float) -> void:
	if not visible:
		return
	if _rate > 0.0:
		_hunger = maxf(_hunger - _rate * delta, 0.0)
		_thirst = maxf(_thirst - _rate * delta, 0.0)
		_redraw()
	_tooltip_timer += delta
	if _tooltip_timer >= TOOLTIP_REFRESH_SECS:
		_tooltip_timer = 0.0
		_refresh_tooltips()


func _redraw() -> void:
	_food_bar.value = 100.0 * _hunger / _cap
	_drink_bar.value = 100.0 * _thirst / _cap
	_food_fill.bg_color = _stage_color(_hunger)
	_drink_fill.bg_color = _stage_color(_thirst)


func _refresh_tooltips() -> void:
	_food_bar.tooltip_text = describe(_hunger, _rate, true)
	_drink_bar.tooltip_text = describe(_thirst, _rate, false)
	_food_label.tooltip_text = _food_bar.tooltip_text
	_drink_label.tooltip_text = _drink_bar.tooltip_text


static func _stage_color(secs: float) -> Color:
	if secs <= 0.0:
		return C_OUT
	if secs < HUNGRY_AT_SECS:
		return C_HUNGRY
	return C_FED


## The hover text: the stage in words and the real time left at this rate.
static func describe(secs: float, rate: float, is_food: bool) -> String:
	if secs <= 0.0:
		return "Out of food" if is_food else "Out of water"
	var left := ""
	if rate > 0.0:
		left = _duration_text(secs / rate)
	if secs < HUNGRY_AT_SECS:
		var stage := "Hungry" if is_food else "Thirsty"
		return "%s, %s left" % [stage, left] if left != "" else stage
	return "Fed, about %s" % left if left != "" else "Fed"


static func _duration_text(real_secs: float) -> String:
	var minutes := int(ceil(real_secs / 60.0))
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %d min" % [floori(minutes / 60.0), minutes % 60]


## A hand-eat asked for while the bar is full: the server will refuse with
## EQ's "you would explode" line, and the bar flashes so the eye finds why.
func _on_hand_eat_requested(is_food: bool, is_drink: bool) -> void:
	if not visible:
		return
	if is_food and _hunger >= _cap - FULL_MARGIN_SECS:
		_flash(_food_bar)
	if is_drink and _thirst >= _cap - FULL_MARGIN_SECS:
		_flash(_drink_bar)


func _flash(bar: ProgressBar) -> void:
	var tween := create_tween()
	for i in 2:
		tween.tween_property(bar, "modulate", C_FLASH, FLASH_SECS)
		tween.tween_property(bar, "modulate", Color.WHITE, FLASH_SECS)
