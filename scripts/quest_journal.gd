extends DraggablePanel

const W := 520.0
const H := 380.0

var _tab_active: bool = true  # true = Active, false = Completed
var _selected_quest_id: String = ""

var _active_btn: Button = null
var _completed_btn: Button = null
var _list_vbox: VBoxContainer = null
var _title_lbl: Label = null
var _desc_lbl: Label = null
var _status_lbl: Label = null
var _obj_vbox: VBoxContainer = null
var _empty_lbl: Label = null
var _abandon_btn: Button = null

func _ready() -> void:
	_build_ui()
	QuestManager.quest_added.connect(_on_quests_changed)
	QuestManager.quest_updated.connect(_on_quests_changed)
	QuestManager.quest_completed.connect(_on_quests_changed)
	QuestManager.quest_failed.connect(_on_quests_changed)
	QuestManager.quest_removed.connect(_on_quests_changed)
	visibility_changed.connect(_on_visibility_changed)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left   = -W * 0.5
	offset_top    = -H * 0.5
	offset_right  =  W * 0.5
	offset_bottom =  H * 0.5

	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_WINDOW_BG
	bg.border_color = UITheme.C_GOLDEN_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", bg)

	# Title bar
	var title_row := HBoxContainer.new()
	title_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_row.offset_top    = 10.0
	title_row.offset_bottom = 36.0
	title_row.offset_left   = 12.0
	title_row.offset_right  = -12.0
	add_child(title_row)

	var title := Label.new()
	title.text = "Quest Journal"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	title.add_theme_font_size_override("font_size", 15)
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func() -> void: visible = false)
	title_row.add_child(close_btn)

	# Tab buttons
	var tab_row := HBoxContainer.new()
	tab_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_row.offset_top    = 40.0
	tab_row.offset_bottom = 66.0
	tab_row.offset_left   = 12.0
	tab_row.offset_right  = -12.0
	tab_row.add_theme_constant_override("separation", 4)
	add_child(tab_row)

	_active_btn = _make_tab_btn("Active")
	_active_btn.pressed.connect(_switch_tab.bind(true))
	tab_row.add_child(_active_btn)

	_completed_btn = _make_tab_btn("Completed")
	_completed_btn.pressed.connect(_switch_tab.bind(false))
	tab_row.add_child(_completed_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(spacer)

	# Two-panel split
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.offset_top    = 70.0
	split.offset_left   = 12.0
	split.offset_right  = -12.0
	split.offset_bottom = -12.0
	split.split_offset  = 0
	add_child(split)

	# Left: quest list
	var left_panel := Panel.new()
	left_panel.custom_minimum_size = Vector2(160.0, 0.0)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = UITheme.C_PANEL_BG
	left_style.border_color = UITheme.C_BORDER
	left_style.set_border_width_all(1)
	left_style.set_corner_radius_all(3)
	left_panel.add_theme_stylebox_override("panel", left_style)
	split.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_scroll.offset_left = 4; left_scroll.offset_top = 4
	left_scroll.offset_right = -4; left_scroll.offset_bottom = -4
	left_panel.add_child(left_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 2)
	left_scroll.add_child(_list_vbox)

	# Right: quest details
	var right_panel := Panel.new()
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = UITheme.C_PANEL_BG
	right_style.border_color = UITheme.C_BORDER
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(3)
	right_panel.add_theme_stylebox_override("panel", right_style)
	split.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_scroll.offset_left = 10; right_scroll.offset_top = 10
	right_scroll.offset_right = -10; right_scroll.offset_bottom = -10
	right_panel.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_title_lbl)

	_desc_lbl = Label.new()
	_desc_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	_desc_lbl.add_theme_font_size_override("font_size", 11)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_desc_lbl)

	# "Ready to turn in" callout (PD_W0024: rewards pay at the turn-in NPC).
	_status_lbl = Label.new()
	_status_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.visible = false
	right_vbox.add_child(_status_lbl)

	var obj_header := Label.new()
	obj_header.text = "Objectives"
	obj_header.add_theme_color_override("font_color", UITheme.C_TITLE)
	obj_header.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(obj_header)

	_obj_vbox = VBoxContainer.new()
	_obj_vbox.add_theme_constant_override("separation", 4)
	right_vbox.add_child(_obj_vbox)

	# Abandon (active quests only). Server forgets progress; re-accepting
	# starts from zero. Confirmed by a combat-log line, not a dialog.
	_abandon_btn = Button.new()
	_abandon_btn.text = "Abandon Quest"
	_abandon_btn.custom_minimum_size = Vector2(120.0, 24.0)
	_abandon_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_abandon_btn.add_theme_font_size_override("font_size", 11)
	_abandon_btn.visible = false
	_abandon_btn.pressed.connect(_on_abandon_pressed)
	right_vbox.add_child(_abandon_btn)

	_empty_lbl = Label.new()
	_empty_lbl.text = "No quests."
	_empty_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	_empty_lbl.add_theme_font_size_override("font_size", 11)
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_empty_lbl)

	_refresh_tab_buttons()
	_rebuild_list()

func _make_tab_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(80.0, 24.0)
	btn.add_theme_font_size_override("font_size", 11)
	return btn

func _switch_tab(to_active: bool) -> void:
	_tab_active = to_active
	_selected_quest_id = ""
	_refresh_tab_buttons()
	_rebuild_list()
	_show_details("")

func _refresh_tab_buttons() -> void:
	var sel_style := UITheme.make_stylebox(UITheme.C_BTN_HOVER)
	var norm_style := UITheme.make_stylebox(UITheme.C_BTN_NORM)
	_active_btn.add_theme_stylebox_override("normal", sel_style if _tab_active else norm_style)
	_completed_btn.add_theme_stylebox_override("normal", norm_style if _tab_active else sel_style)
	_active_btn.add_theme_color_override("font_color", UITheme.C_TITLE if _tab_active else UITheme.C_TEXT)
	_completed_btn.add_theme_color_override("font_color", UITheme.C_TEXT if _tab_active else UITheme.C_TITLE)

func _rebuild_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()

	var quests: Array = QuestManager.get_active_quests() if _tab_active else QuestManager.get_completed_quests()
	_empty_lbl.visible = quests.is_empty()

	for q: Dictionary in quests:
		var btn := Button.new()
		var label: String = q["name"]
		if q["status"] == QuestManager.Status.READY:
			label += "  (Ready)"
		btn.text = label
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", UITheme.C_TITLE if q["id"] == _selected_quest_id else UITheme.C_TEXT)
		btn.pressed.connect(_on_quest_selected.bind(q["id"]))
		_list_vbox.add_child(btn)

	if _selected_quest_id != "" and QuestManager.get_quest(_selected_quest_id).is_empty():
		_selected_quest_id = ""
	_show_details(_selected_quest_id)

func _on_quest_selected(quest_id: String) -> void:
	_selected_quest_id = quest_id
	_rebuild_list()

func _show_details(quest_id: String) -> void:
	for child in _obj_vbox.get_children():
		child.queue_free()

	if quest_id == "":
		_title_lbl.text = ""
		_desc_lbl.text = "Select a quest to view details."
		_status_lbl.visible = false
		_abandon_btn.visible = false
		return

	var q: Dictionary = QuestManager.get_quest(quest_id)
	if q.is_empty():
		_title_lbl.text = ""
		_desc_lbl.text = ""
		_status_lbl.visible = false
		_abandon_btn.visible = false
		return

	_title_lbl.text = q["name"]
	var zone_txt: String = ("  —  " + q["zone"]) if q["zone"] != "" else ""
	_desc_lbl.text = q["description"] + zone_txt

	var status: int = q["status"]
	if status == QuestManager.Status.READY:
		var where: String = q.get("turn_in_npc", "")
		if where == "":
			where = "the quest giver"
		_status_lbl.text = "Ready to turn in: return to %s." % where
		_status_lbl.visible = true
	else:
		_status_lbl.visible = false
	_abandon_btn.visible = _tab_active and (status == QuestManager.Status.ACTIVE or status == QuestManager.Status.READY)

	for obj: Dictionary in q["objectives"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_obj_vbox.add_child(row)

		var mark := Label.new()
		mark.text = "✓" if obj["done"] else "○"
		mark.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if obj["done"] else UITheme.C_TEXT)
		mark.add_theme_font_size_override("font_size", 11)
		row.add_child(mark)

		var obj_lbl := Label.new()
		obj_lbl.text = obj["text"]
		obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		obj_lbl.add_theme_font_size_override("font_size", 11)
		var text_color := Color(0.5, 0.5, 0.5) if obj["done"] else UITheme.C_TEXT
		obj_lbl.add_theme_color_override("font_color", text_color)
		row.add_child(obj_lbl)

func _on_abandon_pressed() -> void:
	if _selected_quest_id == "":
		return
	QuestManager.abandon_quest(_selected_quest_id)
	_selected_quest_id = ""

func _on_quests_changed(_id: String) -> void:
	_rebuild_list()

func _on_visibility_changed() -> void:
	if visible:
		_rebuild_list()
