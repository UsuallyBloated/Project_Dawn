extends DraggablePanel

@onready var _close_btn: Button = $Root/TitleRow/CloseBtn
@onready var _tradeskill_opt: OptionButton = $Root/TradeskillRow/TradeskillOpt
@onready var _skill_label: Label = $Root/TradeskillRow/SkillLabel
@onready var _recipe_vbox: VBoxContainer = $Root/Body/ListScroll/Recipes
@onready var _detail_vbox: VBoxContainer = $Root/Body/DetailScroll/Detail
@onready var _combine_btn: Button = $Root/Footer/CombineBtn
@onready var _result_label: Label = $Root/Footer/ResultLabel

var _tradeskill_names: Array[String] = []
var _current_tradeskill: String = ""
var _filtered_recipes: Array = []
var _selected_recipe: Dictionary = {}
var _recipe_btns: Array[Button] = []

# The frame is scenes/crafting_window.tscn (title row, the tradeskill picker,
# the recipe and detail panes, the Combine footer); this script fills them.
func _ready() -> void:
	_close_btn.pressed.connect(func(): visible = false)
	_tradeskill_opt.item_selected.connect(_on_tradeskill_selected)
	_combine_btn.pressed.connect(_on_combine_pressed)
	_populate_tradeskills()
	Inventory.inventory_changed.connect(_refresh_detail)
	Crafting.skill_level_changed.connect(_on_skill_changed)
	Alignment.alignment_changed.connect(func(_tier, _score): _populate_tradeskills())
	visibility_changed.connect(_on_visibility_changed)

func _populate_tradeskills() -> void:
	_tradeskill_names.clear()
	_tradeskill_opt.clear()
	for skill in Crafting.get_accessible_skills():
		var ts_name: String = skill.skill_name
		if RecipeDefinitions.ALL.has(ts_name):
			_tradeskill_names.append(ts_name)
			_tradeskill_opt.add_item(ts_name)
	if not _tradeskill_names.is_empty():
		_on_tradeskill_selected(0)

func _on_tradeskill_selected(idx: int) -> void:
	if idx < 0 or idx >= _tradeskill_names.size():
		return
	_current_tradeskill = _tradeskill_names[idx]
	_selected_recipe = {}
	_result_label.text = ""
	_combine_btn.disabled = true
	_refresh_skill_label()
	_populate_recipes()

func _refresh_skill_label() -> void:
	if _current_tradeskill.is_empty():
		_skill_label.text = ""
		return
	var level := Crafting.get_skill_level(_current_tradeskill)
	var cap   := Crafting.get_skill_cap(_current_tradeskill)
	_skill_label.text = "Skill: %d / %d" % [level, cap]

func _populate_recipes() -> void:
	_recipe_btns.clear()
	for child in _recipe_vbox.get_children():
		child.queue_free()
	_filtered_recipes = RecipeDefinitions.get_by_tradeskill(_current_tradeskill)

	for i in _filtered_recipes.size():
		var recipe: Dictionary = _filtered_recipes[i]
		var station: String = recipe.get("station", "")
		var station_blocked := station != "" and StationManager.nearby_station != station
		var btn := Button.new()
		btn.text = recipe.get("name", "")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("normal", UITheme.make_stylebox(UITheme.C_BTN_NORM))
		btn.add_theme_stylebox_override("hover",  UITheme.make_stylebox(UITheme.C_BTN_HOVER))
		if station_blocked:
			btn.add_theme_color_override("font_color", UITheme.C_NEUTRAL)
		btn.pressed.connect(_on_recipe_btn_pressed.bind(i))
		_recipe_vbox.add_child(btn)
		_recipe_btns.append(btn)

	_show_detail_hint()

func _on_recipe_btn_pressed(idx: int) -> void:
	_selected_recipe = _filtered_recipes[idx]
	_result_label.text = ""
	var station: String = _selected_recipe.get("station", "")
	_combine_btn.disabled = station != "" and StationManager.nearby_station != station
	for i in _recipe_btns.size():
		_recipe_btns[i].add_theme_stylebox_override("normal",
			UITheme.make_stylebox(UITheme.C_SELECTED if i == idx else UITheme.C_BTN_NORM))
	_refresh_detail()

func _clear_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()

func _show_detail_hint() -> void:
	_clear_detail()
	_add_detail_label("Select a recipe to view details.", UITheme.C_NEUTRAL, 12)

func _on_visibility_changed() -> void:
	if visible and not _selected_recipe.is_empty():
		_refresh_detail()
		_refresh_skill_label()

func _refresh_detail() -> void:
	if not visible:
		return
	_clear_detail()
	if _selected_recipe.is_empty():
		_show_detail_hint()
		return

	var recipe    := _selected_recipe
	var level     := Crafting.get_skill_level(_current_tradeskill)
	var required: int = recipe.get("required_skill", 0)
	var trivial: int  = recipe.get("trivial_at", 50)

	_add_detail_label(recipe.get("name", ""), UITheme.C_TITLE, 13)
	_add_detail_label(
		"Requires skill %d  (trivial at %d)" % [required, trivial],
		UITheme.C_POSITIVE if level >= required else UITheme.C_NEGATIVE, 11
	)

	_detail_vbox.add_child(HSeparator.new())
	_add_detail_label("Ingredients", UITheme.C_TEXT, 12)

	for ing in recipe.get("ingredients", []):
		var item_name: String = ing["item"]
		var need: int = int(ing["qty"])
		var have := Crafting.count_item(item_name)

		var row := HBoxContainer.new()
		_detail_vbox.add_child(row)

		var item_lbl := Label.new()
		item_lbl.text = item_name
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 11)
		item_lbl.clip_text = true
		row.add_child(item_lbl)

		var qty_lbl := Label.new()
		qty_lbl.text = "%d / %d" % [mini(have, need), need]
		qty_lbl.add_theme_font_size_override("font_size", 11)
		qty_lbl.add_theme_color_override("font_color",
			UITheme.C_POSITIVE if have >= need else UITheme.C_NEGATIVE)
		row.add_child(qty_lbl)

	_detail_vbox.add_child(HSeparator.new())
	_add_detail_label("Produces", UITheme.C_TEXT, 12)

	var out_qty: int = recipe.get("output_qty", 1)
	var out_text: String = recipe.get("output", "")
	if out_qty > 1:
		out_text += " x%d" % out_qty
	_add_detail_label(out_text, UITheme.C_TITLE, 12)

	var tool: String = recipe.get("tool", "")
	if tool != "":
		var color := UITheme.C_POSITIVE if Crafting.count_item(tool) > 0 else UITheme.C_NEGATIVE
		_add_detail_label("Tool: " + tool, color, 11)

	var station: String = recipe.get("station", "")
	if station != "":
		_add_detail_label(
			"Station: " + station.replace("_", " ").capitalize(),
			UITheme.C_NEUTRAL, 11
		)

func _add_detail_label(text: String, color: Color, font_size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_vbox.add_child(lbl)

func _on_combine_pressed() -> void:
	if _selected_recipe.is_empty():
		return
	var msg := Crafting.try_combine(_selected_recipe, _current_tradeskill)
	var ok := msg.begins_with("You created")
	_result_label.text = msg
	_result_label.add_theme_color_override("font_color",
		UITheme.C_POSITIVE if ok else UITheme.C_NEGATIVE)
	CombatLog.add_line(msg, CombatLog.MsgType.INFO)
	_refresh_detail()
	_refresh_skill_label()

func _on_skill_changed(skill: String, _level: int) -> void:
	if visible and skill == _current_tradeskill:
		_refresh_skill_label()
