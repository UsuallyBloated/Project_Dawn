extends DraggablePanel

const W := 520.0
const H := 340.0

var _npc_name_lbl: Label = null
var _npc_title_lbl: Label = null
var _text_lbl: Label = null
var _response_vbox: VBoxContainer = null

var _current_npc: String = ""
var _current_tree: Dictionary = {}

func _ready() -> void:
	_build_ui()
	DialogueManager.dialogue_opened.connect(open_for)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left   = -W * 0.5
	offset_top    = -H * 0.5
	offset_right  =  W * 0.5
	offset_bottom =  H * 0.5
	z_index = 25

	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_WINDOW_BG
	bg.border_color = UITheme.C_GOLDEN_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── Title row ────────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_col)

	_npc_name_lbl = Label.new()
	_npc_name_lbl.add_theme_font_size_override("font_size", 15)
	_npc_name_lbl.add_theme_color_override("font_color", UITheme.C_GOLDEN_BORDER)
	name_col.add_child(_npc_name_lbl)

	_npc_title_lbl = Label.new()
	_npc_title_lbl.add_theme_font_size_override("font_size", 11)
	_npc_title_lbl.add_theme_color_override("font_color", UITheme.C_NEUTRAL)
	name_col.add_child(_npc_title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_NEUTRAL)
	close_btn.pressed.connect(func(): visible = false)
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# ── NPC speech area ───────────────────────────────────────────────────────────
	var text_panel := PanelContainer.new()
	text_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = Color(0.07, 0.07, 0.11, 0.90)
	text_style.set_corner_radius_all(4)
	text_style.content_margin_left   = 10
	text_style.content_margin_top    = 8
	text_style.content_margin_right  = 10
	text_style.content_margin_bottom = 8
	text_panel.add_theme_stylebox_override("panel", text_style)
	vbox.add_child(text_panel)

	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_lbl.add_theme_font_size_override("font_size", 13)
	_text_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	text_panel.add_child(_text_lbl)

	vbox.add_child(HSeparator.new())

	# ── Response buttons ──────────────────────────────────────────────────────────
	_response_vbox = VBoxContainer.new()
	_response_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_response_vbox)

# ── Public API ────────────────────────────────────────────────────────────────

func open_for(npc_name: String) -> void:
	_current_npc = npc_name
	_current_tree = DialogueDefinitions.ALL.get(npc_name, {})
	if _current_tree.is_empty():
		return
	_npc_name_lbl.text = npc_name
	_npc_title_lbl.text = _current_tree.get("npc_title", "")
	_navigate_to("root")
	visible = true

# ── Internal ──────────────────────────────────────────────────────────────────

func _navigate_to(node_id: String) -> void:
	var node: Dictionary = _current_tree.get(node_id, {})
	if node.is_empty():
		visible = false
		return

	_text_lbl.text = node.get("text", "")

	for child in _response_vbox.get_children():
		child.queue_free()

	var responses: Array = node.get("responses", [])
	var btn_index := 1
	for resp: Dictionary in responses:
		if not _response_passes_condition(resp):
			continue
		var btn := Button.new()
		btn.text = "%d.  %s" % [btn_index, resp.get("text", "")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.55))
		btn.pressed.connect(_on_response.bind(resp))
		_response_vbox.add_child(btn)
		btn_index += 1

func _response_passes_condition(resp: Dictionary) -> bool:
	if not resp.has("quest_condition"):
		return true
	var cond: Dictionary = resp["quest_condition"]
	var qid: String    = cond.get("id", "")
	var required: String = cond.get("status", "")
	var status: int    = QuestManager.get_quest_status(qid)
	match required:
		"none":      return status == -1
		"ACTIVE":    return status == QuestManager.Status.ACTIVE
		"READY":     return status == QuestManager.Status.READY
		"COMPLETED": return status == QuestManager.Status.COMPLETED
		_:           return true

func _on_response(resp: Dictionary) -> void:
	var action: String  = resp.get("action", "")
	var goto_id: String = resp.get("goto", "")
	var qid: String     = resp.get("quest_id", "")
	match action:
		"close":
			visible = false
		"open_vendor":
			visible = false
			VendorManager.open_nearby()
		"bind_soul":
			# Soul Binder: your respawn point becomes wherever you're standing.
			# Server-authoritative — it stores the position and refuses the bind
			# if you're dead, so we only send the intent and report optimistically.
			# In offline/Test Room there's no server, so say so rather than
			# silently doing nothing.
			if Net.is_launcher_mode():
				Net.broadcast_bind_at_current_location()
				CombatLog.add_line(
					"Your soul is bound to this place.", CombatLog.MsgType.INFO)
			else:
				CombatLog.add_line(
					"Soul binding requires a server connection.", CombatLog.MsgType.INFO)
			if goto_id != "":
				_navigate_to(goto_id)
		"give_quest":
			if qid != "":
				var def: Dictionary = QuestDefinitions.ALL.get(qid, {})
				if not def.is_empty():
					QuestManager.add_quest(def)
			if goto_id != "":
				_navigate_to(goto_id)
		"complete_quest":
			if qid != "":
				QuestManager.complete_quest(qid)
			if goto_id != "":
				_navigate_to(goto_id)
		_:
			if goto_id != "":
				_navigate_to(goto_id)
