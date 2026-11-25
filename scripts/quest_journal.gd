extends DraggablePanel

var _tab_active: bool = true  # true = Active, false = Completed
var _selected_quest_id: String = ""

@onready var _close_btn: Button = $TitleRow/CloseBtn
@onready var _active_btn: Button = $TabRow/ActiveBtn
@onready var _completed_btn: Button = $TabRow/CompletedBtn
@onready var _list_vbox: VBoxContainer = $Split/LeftPanel/LeftScroll/List
@onready var _empty_lbl: Label = $Split/LeftPanel/EmptyLbl
@onready var _title_lbl: Label = $Split/RightPanel/RightScroll/RightVBox/TitleLbl
@onready var _desc_lbl: Label = $Split/RightPanel/RightScroll/RightVBox/DescLbl
@onready var _status_lbl: Label = $Split/RightPanel/RightScroll/RightVBox/StatusLbl
@onready var _obj_vbox: VBoxContainer = $Split/RightPanel/RightScroll/RightVBox/ObjVBox
@onready var _abandon_btn: Button = $Split/RightPanel/RightScroll/RightVBox/AbandonBtn

# The frame is scenes/quest_journal.tscn (title row, the two tab buttons, the
# split with the list and the detail pane); this script fills both panes.
func _ready() -> void:
	_close_btn.pressed.connect(func() -> void: visible = false)
	_active_btn.pressed.connect(_switch_tab.bind(true))
	_completed_btn.pressed.connect(_switch_tab.bind(false))
	# Abandon (active quests only). Server forgets progress; re-accepting
	# starts from zero. Confirmed by a combat-log line, not a dialog.
	_abandon_btn.pressed.connect(_on_abandon_pressed)
	QuestManager.quest_added.connect(_on_quests_changed)
	QuestManager.quest_updated.connect(_on_quests_changed)
	QuestManager.quest_completed.connect(_on_quests_changed)
	QuestManager.quest_failed.connect(_on_quests_changed)
	QuestManager.quest_removed.connect(_on_quests_changed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_tab_buttons()
	_rebuild_list()

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
