extends Panel

var _label: Label = null
var _progress: ProgressBar = null
var _total: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	position = Vector2(-150.0, -120.0)
	size = Vector2(300.0, 48.0)
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
