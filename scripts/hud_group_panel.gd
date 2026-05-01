extends DraggablePanel

signal layout_changed

var _header_lbl: Label = null
var _members_vbox: VBoxContainer = null
var _action_btn: Button = null
var _leave_btn: Button = null
var _context_menu: PopupMenu = null
var _context_peer: int = 0
var _member_bars: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10.0, 10.0)
	size = Vector2(220.0, 60.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.06, 0.88)
	style.border_color = Color(0.35, 0.25, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6; vbox.offset_top = 4
	vbox.offset_right = -6; vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

	_header_lbl = Label.new()
	_header_lbl.text = "GROUP"
	_header_lbl.add_theme_font_size_override("font_size", 11)
	_header_lbl.add_theme_color_override("font_color", Color(0.75, 0.60, 1.0))
	_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_header_lbl)

	_members_vbox = VBoxContainer.new()
	_members_vbox.add_theme_constant_override("separation", 2)
	_members_vbox.visible = false
	vbox.add_child(_members_vbox)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_hbox)

	_action_btn = Button.new()
	_action_btn.text = "Invite"
	_action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_btn.add_theme_font_size_override("font_size", 11)
	_action_btn.pressed.connect(_on_action_pressed)
	btn_hbox.add_child(_action_btn)

	_leave_btn = Button.new()
	_leave_btn.text = "Leave"
	_leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_btn.add_theme_font_size_override("font_size", 11)
	_leave_btn.visible = false
	_leave_btn.pressed.connect(GroupManager.leave_group)
	btn_hbox.add_child(_leave_btn)

	_context_menu = PopupMenu.new()
	_context_menu.add_item("Pass Leadership", 0)
	_context_menu.id_pressed.connect(_on_context_id_pressed)
	add_child(_context_menu)

	GroupManager.group_updated.connect(_on_group_updated)
	GroupManager.invite_received.connect(func(_id, _n): _on_group_updated(true))

func _on_group_updated(membership_changed: bool) -> void:
	if membership_changed:
		_refresh()
	else:
		_update_bars()

func _refresh() -> void:
	_member_bars.clear()
	for child in _members_vbox.get_children():
		child.queue_free()

	if GroupManager.in_group:
		_members_vbox.visible = true
		for member in GroupManager.members:
			var pid: int = member.get("peer_id", 0)
			var row_data := _build_member_row(member)
			_members_vbox.add_child(row_data.panel)
			_member_bars[pid] = {"hp": row_data.hp_bar, "mp": row_data.mp_bar, "sta": row_data.sta_bar}
		var show_invite := GroupManager.is_leader and GroupManager.members.size() < GroupManager.MAX_SIZE
		_action_btn.visible = show_invite
		_action_btn.text = "Invite"
		_leave_btn.visible = true
		_header_lbl.text = "GROUP (Leader)" if GroupManager.is_leader else "GROUP"
		size.y = 60.0 + GroupManager.members.size() * 54.0
	else:
		_members_vbox.visible = false
		_leave_btn.visible = false
		_action_btn.visible = true
		if GroupManager.pending_invite_from != 0:
			_action_btn.text = "Follow"
			_header_lbl.text = "GROUP (Invited)"
		else:
			_action_btn.text = "Invite"
			_header_lbl.text = "GROUP"
		size.y = 60.0

	layout_changed.emit()

func _update_bars() -> void:
	for member in GroupManager.members:
		var pid: int = member.get("peer_id", 0)
		if not _member_bars.has(pid):
			continue
		var bars: Dictionary = _member_bars[pid]
		bars.hp.max_value  = maxf(member.get("max_hp",  100.0), 1.0)
		bars.hp.value      = member.get("hp",  0.0)
		bars.mp.max_value  = maxf(member.get("max_mp",  100.0), 1.0)
		bars.mp.value      = member.get("mp",  0.0)
		bars.sta.max_value = maxf(member.get("max_sta", 100.0), 1.0)
		bars.sta.value     = member.get("sta", 0.0)

func _build_member_row(member: Dictionary) -> Dictionary:
	var peer_id: int = member.get("peer_id", 0)
	var my_id := multiplayer.get_unique_id()
	var is_me := peer_id == my_id
	var is_leader := peer_id == GroupManager.leader_peer_id

	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 50)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.06, 0.12, 0.70) if is_me else Color(0.05, 0.04, 0.08, 0.50)
	row_style.border_color = UITheme.C_GOLDEN_BORDER if is_leader else Color(0.20, 0.15, 0.30)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(2)
	row.add_theme_stylebox_override("panel", row_style)
	if GroupManager.is_leader and not is_me:
		row.gui_input.connect(_on_member_row_input.bind(peer_id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4; vbox.offset_top = 3
	vbox.offset_right = -4; vbox.offset_bottom = -3
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = member.get("name", "???")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TITLE if is_leader else Color(0.90, 0.90, 0.90))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_row.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv %d" % member.get("level", 1)
	lv_lbl.add_theme_font_size_override("font_size", 10)
	lv_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	name_row.add_child(lv_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0.0
	hp_bar.max_value = maxf(member.get("max_hp", 100.0), 1.0)
	hp_bar.value = member.get("hp", 100.0)
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 10)
	UITheme.style_bar(hp_bar, UITheme.C_BAR_HP, false)
	vbox.add_child(hp_bar)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 2)
	vbox.add_child(bar_row)

	var mp_bar := ProgressBar.new()
	mp_bar.min_value = 0.0
	mp_bar.max_value = maxf(member.get("max_mp", 100.0), 1.0)
	mp_bar.value = member.get("mp", 100.0)
	mp_bar.show_percentage = false
	mp_bar.custom_minimum_size = Vector2(0, 10)
	mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_bar(mp_bar, UITheme.C_BAR_MANA, false)
	bar_row.add_child(mp_bar)

	var sta_bar := ProgressBar.new()
	sta_bar.min_value = 0.0
	sta_bar.max_value = maxf(member.get("max_sta", 100.0), 1.0)
	sta_bar.value = member.get("sta", 100.0)
	sta_bar.show_percentage = false
	sta_bar.custom_minimum_size = Vector2(0, 10)
	sta_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_bar(sta_bar, UITheme.C_BAR_STAMINA, false)
	bar_row.add_child(sta_bar)

	return {"panel": row, "hp_bar": hp_bar, "mp_bar": mp_bar, "sta_bar": sta_bar}

func _on_action_pressed() -> void:
	if GroupManager.pending_invite_from != 0:
		GroupManager.accept_invite()
	else:
		var target = Combat.current_target
		if not is_instance_valid(target):
			return
		if not target.is_in_group("player"):
			return
		var peer_id: int = target.get_meta("peer_id", 0)
		if peer_id == 0:
			return
		GroupManager.invite_player(peer_id)

func _on_member_row_input(event: InputEvent, peer_id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_context_peer = peer_id
		_context_menu.popup(Rect2(get_viewport().get_mouse_position(), Vector2.ZERO))

func _on_context_id_pressed(id: int) -> void:
	if id == 0:
		GroupManager.pass_leadership(_context_peer)
