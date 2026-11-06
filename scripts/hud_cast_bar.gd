# The player's own cast bar: the spell's name over a bar that fills across
# the cast time. Shown on Spells.casting_started, hidden when the cast is
# cancelled or lands. Draggable like the other HUD panels.
extends DraggablePanel

const BAR_SIZE := Vector2(300.0, 48.0)
# How far below the middle of the screen the bar's centre sits, so it reads
# as centred without covering the target.
const BELOW_CENTRE := 110.0

var _label: Label = null
var _progress: ProgressBar = null
var _total: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false

func _ready() -> void:
	# Centred (user, 2026-10-29: "put it in the center for now"). It used to
	# sit 72 to 120 px above the bottom edge, inside the band the hotbars
	# occupy, so a player never saw their own bar. Anchored at the midpoint
	# with offsets, as the trade window is: `position` is measured from the
	# screen's corner, not the anchor.
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -BAR_SIZE.x / 2.0
	offset_right = BAR_SIZE.x / 2.0
	offset_top = BELOW_CENTRE - BAR_SIZE.y / 2.0
	offset_bottom = BELOW_CENTRE + BAR_SIZE.y / 2.0
	visible = false

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)

	_progress = ProgressBar.new()
	_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.value = 0.0
	_progress.show_percentage = false
	add_child(_progress)

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
