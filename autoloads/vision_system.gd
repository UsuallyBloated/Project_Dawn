extends Node

# Vision types (stored per race in CharacterData.RACE_DATA["vision"]):
#   "normal"      — no boost; world is dark at night (Human, Minotaur, Half-Ogre)
#   "infravision" — partial boost + green tint (Elf, Dwarf, Gnome, Wood Elf, Halfling, Half-Elf, Fae, Felhari, Kobold)
#   "ultravision" — near-full brightness at night (Dark Elf, Ogre, Troll, Kel`varath, Revenant)

var _environment: Environment = null
var _tint_layer: CanvasLayer = null
var _tint_rect: ColorRect = null

func _ready() -> void:
	_setup_tint_layer()
	call_deferred("_find_environment")
	ZoneLoader.zone_ready.connect(_find_environment)

func _setup_tint_layer() -> void:
	_tint_layer = CanvasLayer.new()
	_tint_layer.layer = 0
	add_child(_tint_layer)
	_tint_rect = ColorRect.new()
	_tint_rect.color = Color(0, 0, 0, 0)
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_layer.add_child(_tint_rect)

func _find_environment() -> void:
	var env_node: WorldEnvironment = get_tree().get_first_node_in_group("world_environment")
	if env_node:
		_environment = env_node.environment

func _process(_delta: float) -> void:
	var night_t := TimeOfDay.night_factor()
	var vision: String = CharacterData.RACE_DATA.get(PlayerStats.race, {}).get("vision", "normal")

	match vision:
		"ultravision":
			if _environment:
				_environment.adjustment_brightness = lerpf(1.0, 4.0, night_t)
			_tint_rect.color = Color(0, 0, 0, 0)
		"infravision":
			if _environment:
				_environment.adjustment_brightness = lerpf(1.0, 2.0, night_t)
			_tint_rect.color = Color(0.04, 0.14, 0.02, night_t * 0.12)
		_:
			if _environment:
				_environment.adjustment_brightness = 1.0
			_tint_rect.color = Color(0, 0, 0, 0)
