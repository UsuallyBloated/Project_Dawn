extends DraggablePanel

@onready var _npc_name_lbl: Label = $Margin/VBox/TitleRow/NameCol/NpcName
@onready var _npc_title_lbl: Label = $Margin/VBox/TitleRow/NameCol/NpcTitle
@onready var _close_btn: Button = $Margin/VBox/TitleRow/CloseBtn
@onready var _text_lbl: Label = $Margin/VBox/TextPanel/Text
@onready var _response_vbox: VBoxContainer = $Margin/VBox/Responses

var _current_npc: String = ""
var _current_tree: Dictionary = {}

# The frame is scenes/dialogue_window.tscn (title row, the speech panel, the
# response list); this script fills it from the dialogue tree.
func _ready() -> void:
	_close_btn.pressed.connect(func(): visible = false)
	DialogueManager.dialogue_opened.connect(open_for)

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
			# Server-authoritative: send the intent and say nothing, since the
			# server answers both ways ("Your soul is bound to this place." on
			# success, a refusal when dead or out of range). This line used to
			# claim success unconditionally, which meant a refused bind read as
			# a granted one — the death loop's favourite disguise.
			Net.broadcast_bind_at_current_location()
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
