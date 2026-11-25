# The player's own cast bar: the spell's name over a bar that fills across
# the cast time. Shown on Spells.casting_started, hidden when the cast is
# cancelled or lands. Draggable like the other HUD panels.
extends DraggablePanel

@onready var _label: Label = $Label
@onready var _progress: ProgressBar = $Progress
var _total: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false

# Centred (user, 2026-10-29: "put it in the center for now"), its centre
# 110 px below the middle of the screen so it does not cover the target, 300
# by 48 px; the placement is the scene's (scenes/hud_cast_bar.tscn). It used
# to sit inside the band the hotbars occupy, so a player never saw their own
# bar.
func _ready() -> void:
	Spells.casting_started.connect(_on_casting_started)
	Spells.casting_cancelled.connect(func(): _hide())
	Spells.spell_cast.connect(func(_sp): _hide())

func _process(delta: float) -> void:
	if _active and _total > 0.0:
		_elapsed = minf(_elapsed + delta, _total)
		_progress.value = _elapsed / _total

func _on_casting_started(spell: SpellData) -> void:
	_total = spell.cast_time
	_elapsed = 0.0
	_active = true
	_label.text = spell.spell_name
	_progress.value = 0.0
	visible = true

func _hide() -> void:
	_active = false
	visible = false
