extends CanvasLayer

const SLOT_COUNT := 10
const SLOT_SIZE  := 40
const BAR_GAP    := 6

const C_BG     := Color(0.06, 0.05, 0.03, 0.90)
const C_COOL   := Color(0.0, 0.0, 0.0, 0.65)
const C_READY  := Color(0.30, 0.22, 0.08)
const C_ACTIVE := Color(0.55, 0.40, 0.10)
# Track 17.1 — lavender memorize-progress fill (rises from the bottom
# of the slot during a 2 s commit). Differs from the cooldown overlay
# colour so the player can tell "writing the spell in" from "the
# spell just fired and is recharging".
const C_MEMORIZE_FILL := Color(0.45, 0.30, 0.75, 0.55)

const KEY_LABELS       := ["1","2","3","4","5","6","7","8","9","0"]
const KEY_LABELS_SPELL := ["A+1","A+2","A+3","A+4","A+5","A+6","A+7","A+8","A+9","A+0"]

var _hotkey_slots: Array          = []
var _hotkey_panel: DraggablePanel = null
var _bank_label: Label            = null

var _spell_slots: Array           = []
var _spell_panel: DraggablePanel  = null

var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label         = null

var _ctx_menu: PopupMenu          = null
var _spell_menu: PopupMenu        = null
var _ctx_slot: int                = -1

var _social_win: Window           = null
var _social_label_edit: LineEdit  = null
var _social_line_edits: Array[LineEdit] = []
var _social_list: ItemList        = null
var _social_editing_id: String    = ""
var _social_pick_mode: bool       = false
var _social_status: Label         = null
var _social_save_btn: Button      = null
var _social_delete_btn: Button    = null

var _hotkey_by_skill: Dictionary  = {}
var _hotkey_by_spell: Dictionary  = {}
var _spell_bar_idx:   Dictionary  = {}

func _ready() -> void:
	var bar_h: float = SLOT_SIZE + 20

	_hotkey_panel = _build_hotkey_bar(bar_h)
	_spell_panel  = _build_spell_bar(bar_h)

	var tip := _hotkey_panel.make_tooltip()
	_tooltip_panel = tip[0]
	_tooltip_label = tip[1]

	_build_context_menu()
	_build_social_editor()

	Skills.skill_cooldown_updated.connect(_on_skill_cooldown)
	Skills.skills_changed.connect(_refresh_hotkey_slots)
	Spells.spell_cooldown_updated.connect(_on_spell_cooldown)
	Spells.spells_changed.connect(_refresh_spell_slots)
	SocialHotkeys.bank_changed.connect(_on_bank_changed)
	SocialHotkeys.slot_changed.connect(_on_slot_changed)
	# Track 16.1 — spell bar is now a memorize bar driven by SpellBar.
	SpellBar.slot_changed.connect(func(_s): _refresh_spell_slots())
	# Track 17.1 — re-render on level-up to drop newly unlocked
	# slots' lock badges, and on memorize lifecycle to drive the
	# in-slot progress overlay.
	SpellBar.cap_changed.connect(func(_c): _refresh_spell_slots())
	Memorize.candidate_changed.connect(_on_memorize_candidate_changed)
	Memorize.memorize_started.connect(_on_memorize_started)
	Memorize.memorize_progress.connect(_on_memorize_progress)
	Memorize.memorize_cancelled.connect(_on_memorize_cancelled)
	Memorize.memorize_completed.connect(_on_memorize_completed)
	PlayerStats.level_changed.connect(func(_l): _refresh_spell_slots())

	await get_tree().process_frame
	_refresh_hotkey_slots()
	_refresh_spell_slots()

func _build_hotkey_bar(bar_h: float) -> DraggablePanel:
	var bar_w: float = SLOT_COUNT * (SLOT_SIZE + 4) + 16

	var panel := DraggablePanel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 1.0
	panel.anchor_bottom = 1.0
	var extra_h := 20.0  # room for bank nav row
	panel.offset_left   = -bar_w / 2.0
	panel.offset_right  =  bar_w / 2.0
	panel.offset_top    = -(bar_h + extra_h) - BAR_GAP / 2.0
	panel.offset_bottom = -BAR_GAP / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.offset_left = 8; vbox.offset_top = 4
	vbox.offset_right = -8; vbox.offset_bottom = -4
	panel.add_child(vbox)

	# Bank navigation row
	var nav_row := HBoxContainer.new()
	nav_row.custom_minimum_size.y = 16
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 4)
	vbox.add_child(nav_row)

	var btn_prev := Button.new()
	btn_prev.text = "<"
	btn_prev.custom_minimum_size = Vector2(18, 16)
	btn_prev.add_theme_font_size_override("font_size", 10)
	btn_prev.pressed.connect(func(): SocialHotkeys.switch_bank(SocialHotkeys.current_bank - 1))
	nav_row.add_child(btn_prev)

	_bank_label = Label.new()
	_bank_label.text = "Bank 1"
	_bank_label.add_theme_font_size_override("font_size", 10)
	_bank_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bank_label.custom_minimum_size.x = 50
	nav_row.add_child(_bank_label)

	var btn_next := Button.new()
	btn_next.text = ">"
	btn_next.custom_minimum_size = Vector2(18, 16)
	btn_next.add_theme_font_size_override("font_size", 10)
	btn_next.pressed.connect(func(): SocialHotkeys.switch_bank(SocialHotkeys.current_bank + 1))
	nav_row.add_child(btn_next)

	# Slot row
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 4)
	vbox.add_child(slot_row)

	for i in SLOT_COUNT:
		var sd := {
			"index":            i,
			"frame":            null,
			"icon":             null,
			"key_label":        null,
			"name_label":       null,
			"cooldown_overlay": null,
			"cooldown_label":   null,
		}
		var frame := Panel.new()
		frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_style_slot(frame, false)
		slot_row.add_child(frame)
		sd["frame"] = frame

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(icon)
		sd["icon"] = icon

		var cool_overlay := ColorRect.new()
		cool_overlay.color = C_COOL
		cool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_overlay.visible = false
		frame.add_child(cool_overlay)
		sd["cooldown_overlay"] = cool_overlay

		var cool_lbl := Label.new()
		cool_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cool_lbl.add_theme_font_size_override("font_size", 14)
		cool_lbl.add_theme_color_override("font_color", Color.WHITE)
		cool_lbl.visible = false
		frame.add_child(cool_lbl)
		sd["cooldown_label"] = cool_lbl

		var key_lbl := Label.new()
		key_lbl.text = KEY_LABELS[i]
		key_lbl.anchor_right = 1.0
		key_lbl.anchor_bottom = 0.35
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
		key_lbl.offset_left = 3
		frame.add_child(key_lbl)
		sd["key_label"] = key_lbl

		var name_lbl := Label.new()
		name_lbl.anchor_top = 0.65
		name_lbl.anchor_right = 1.0
		name_lbl.anchor_bottom = 1.0
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		name_lbl.clip_text = true
		frame.add_child(name_lbl)
		sd["name_label"] = name_lbl

		frame.mouse_entered.connect(_on_hotkey_hover.bind(i))
		frame.mouse_exited.connect(func(): if _tooltip_panel: _tooltip_panel.visible = false)
		frame.gui_input.connect(_on_hotkey_input.bind(i))

		_hotkey_slots.append(sd)

	return panel

func _build_spell_bar(bar_h: float) -> DraggablePanel:
	var bar_w: float = SLOT_SIZE + 20
	var total_h: float = SLOT_COUNT * (SLOT_SIZE + 4) + 16

	var panel := DraggablePanel.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -(bar_w + 10)
	panel.offset_right  = -10
	panel.offset_top    = -total_h / 2.0
	panel.offset_bottom =  total_h / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.offset_left = 8; box.offset_top = 8
	box.offset_right = -8; box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	for i in SLOT_COUNT:
		var sd := {
			"index":            i,
			"frame":            null,
			"icon":             null,
			"key_label":        null,
			"name_label":       null,
			"cooldown_overlay": null,
			"cooldown_label":   null,
			"lock_label":       null,
			"memorize_overlay": null,
		}
		var frame := Panel.new()
		frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_style_slot(frame, false)
		box.add_child(frame)
		sd["frame"] = frame

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(icon)
		sd["icon"] = icon

		var cool_overlay := ColorRect.new()
		cool_overlay.color = C_COOL
		cool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_overlay.visible = false
		frame.add_child(cool_overlay)
		sd["cooldown_overlay"] = cool_overlay

		# Track 17.1 — memorize progress overlay; lavender fill anchored
		# bottom-up, sized to match the 2 s cast time.
		var mem_overlay := ColorRect.new()
		mem_overlay.color = C_MEMORIZE_FILL
		mem_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		mem_overlay.anchor_top = 1.0
		mem_overlay.anchor_bottom = 1.0
		mem_overlay.visible = false
		mem_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(mem_overlay)
		sd["memorize_overlay"] = mem_overlay

		var cool_lbl := Label.new()
		cool_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cool_lbl.add_theme_font_size_override("font_size", 14)
		cool_lbl.add_theme_color_override("font_color", Color.WHITE)
		cool_lbl.visible = false
		frame.add_child(cool_lbl)
		sd["cooldown_label"] = cool_lbl

		var key_lbl := Label.new()
		key_lbl.text = KEY_LABELS_SPELL[i]
		key_lbl.anchor_right = 1.0
		key_lbl.anchor_bottom = 0.35
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
		key_lbl.offset_left = 3
		frame.add_child(key_lbl)
		sd["key_label"] = key_lbl

		var name_lbl := Label.new()
		name_lbl.anchor_top = 0.65
		name_lbl.anchor_right = 1.0
		name_lbl.anchor_bottom = 1.0
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
		name_lbl.clip_text = true
		frame.add_child(name_lbl)
		sd["name_label"] = name_lbl

		# Track 17.1 — lock badge on slots above the level cap.
		var lock_lbl := Label.new()
		lock_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
		lock_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lock_lbl.add_theme_constant_override("outline_size", 2)
		lock_lbl.visible = false
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(lock_lbl)
		sd["lock_label"] = lock_lbl

		frame.mouse_entered.connect(_on_spell_hover.bind(i))
		frame.mouse_exited.connect(func(): if _tooltip_panel: _tooltip_panel.visible = false)
		frame.gui_input.connect(_on_spell_clicked.bind(i))

		_spell_slots.append(sd)

	return panel

func _build_context_menu() -> void:
	_ctx_menu = PopupMenu.new()
	_ctx_menu.add_item("Assign Spell...",  0)
	# "Assign Skill..." is gone (2026-08-26): it did not work from the
	# tester's seat, and skills now assign by pickup-and-place from the
	# book's Skills tab — click the skill, click an empty slot.
	# Track 16.2 — Assign Social opens the library in pick mode (the
	# clicked slot becomes the target). Manage Socials opens the same
	# library in edit mode for create / edit / delete.
	_ctx_menu.add_item("Assign Social...", 2)
	_ctx_menu.add_item("Manage Socials...", 4)
	_ctx_menu.add_separator()
	_ctx_menu.add_item("Clear",            3)
	_ctx_menu.id_pressed.connect(_on_ctx_menu_id)
	add_child(_ctx_menu)

	_spell_menu = PopupMenu.new()
	_spell_menu.id_pressed.connect(_on_spell_assign)
	add_child(_spell_menu)


func _on_hotkey_input(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# A carried skill (picked up from the book's Skills tab) places on an
		# empty slot and does nothing on an occupied one — and never executes
		# the slot mid-carry, or placing would fire abilities by accident.
		if SocialHotkeys.carried_skill != null:
			var sd_carry: Dictionary = SocialHotkeys.get_slot(slot)
			if sd_carry.get("type", SocialHotkeys.TYPE_EMPTY) == SocialHotkeys.TYPE_EMPTY:
				SocialHotkeys.set_slot_skill(slot, SocialHotkeys.carried_skill)
				SocialHotkeys.clear_skill_carry()
			return
		# Track 17.1 — memorize gestures only resolve through the spell
		# bar (where the cost + cast bar are enforced). Clicking the
		# hotkey bar with a candidate held just executes the slot — the
		# candidate stays staged so the player can still complete the
		# memorize on the spell bar. Assign-spell-to-hotkey is the
		# context-menu route ("Assign Spell..."), unchanged.
		SocialHotkeys.execute_slot(slot)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Spell/skill slots clear on right-click directly — matches
		# the classic-MMO muscle memory. Empty and social slots open
		# the context menu so the player can assign / edit.
		var sd: Dictionary = SocialHotkeys.get_slot(slot)
		var t: String = sd.get("type", SocialHotkeys.TYPE_EMPTY)
		if t == SocialHotkeys.TYPE_SPELL or t == SocialHotkeys.TYPE_SKILL:
			SocialHotkeys.clear_slot(slot)
			return
		_ctx_slot = slot
		_ctx_menu.popup(Rect2i(int(mb.global_position.x), int(mb.global_position.y), 0, 0))

func _on_ctx_menu_id(id: int) -> void:
	match id:
		0: _open_spell_assign_menu()
		2: _open_social_library(true)
		3: SocialHotkeys.clear_slot(_ctx_slot)
		4: _open_social_library(false)

func _open_spell_assign_menu() -> void:
	var names: Array = []
	for sp in Spells.available: names.append(sp.spell_name)
	_open_assign_menu(_spell_menu, names, 0)

func _open_assign_menu(menu: PopupMenu, names: Array, ctx_item_idx: int) -> void:
	menu.clear()
	for i in names.size():
		menu.add_item(names[i], i)
	if menu.item_count == 0:
		menu.add_item("(none available)", -1)
	var r: Rect2 = _ctx_menu.get_item_rect(ctx_item_idx)
	menu.popup(Rect2i(int(_ctx_menu.position.x) + r.size.x, int(_ctx_menu.position.y), 0, 0))

func _on_spell_assign(id: int) -> void:
	if id < 0 or id >= Spells.available.size():
		return
	SocialHotkeys.set_slot_spell(_ctx_slot, Spells.available[id])

# Track 16.2 — Social/Macro library browser. One window, two panes:
#   left  — list of library entries + "New" / "Delete" + status text
#   right — label + 5 command lines + "Save"
# Two modes:
#   browse — manage entries (default; "Save" updates the entry,
#            "Delete" removes it, "New" creates a fresh draft)
#   pick   — clicking an entry assigns it to _ctx_slot and closes
#            (used by the "Assign Social..." context menu item)
func _build_social_editor() -> void:
	_social_win = Window.new()
	_social_win.title = "Social / Macro"
	_social_win.size = Vector2i(560, 340)
	_social_win.unresizable = true
	_social_win.visible = false
	_social_win.close_requested.connect(func(): _social_win.hide())
	add_child(_social_win)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12; root.offset_top = 12
	root.offset_right = -12; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	_social_win.add_child(root)

	# ── Left rail: library list + actions ────────────────────────
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)

	var left_hdr := Label.new()
	left_hdr.text = "Library"
	left_hdr.add_theme_font_size_override("font_size", 12)
	left_hdr.add_theme_color_override("font_color", UITheme.C_TITLE)
	left.add_child(left_hdr)

	_social_list = ItemList.new()
	_social_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_social_list.item_selected.connect(_on_social_list_selected)
	_social_list.item_activated.connect(_on_social_list_activated)
	left.add_child(_social_list)

	var left_btns := HBoxContainer.new()
	left_btns.add_theme_constant_override("separation", 6)
	left.add_child(left_btns)

	var new_btn := Button.new()
	new_btn.text = "New social"
	new_btn.pressed.connect(_on_social_new)
	left_btns.add_child(new_btn)

	_social_delete_btn = Button.new()
	_social_delete_btn.text = "Delete"
	_social_delete_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_social_delete_btn.disabled = true
	_social_delete_btn.pressed.connect(_on_social_delete)
	left_btns.add_child(_social_delete_btn)

	# ── Right pane: editor ───────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	_social_status = Label.new()
	_social_status.add_theme_font_size_override("font_size", 11)
	_social_status.add_theme_color_override("font_color", UITheme.C_TITLE)
	right.add_child(_social_status)

	var lbl_row := HBoxContainer.new()
	right.add_child(lbl_row)
	var lbl_hdr := Label.new()
	lbl_hdr.text = "Button Label (6 chars):"
	lbl_hdr.add_theme_font_size_override("font_size", 11)
	lbl_row.add_child(lbl_hdr)

	_social_label_edit = LineEdit.new()
	_social_label_edit.max_length = 6
	_social_label_edit.custom_minimum_size.x = 80
	lbl_row.add_child(_social_label_edit)

	var help := Label.new()
	help.text = "Commands: /say /yell /shout /group /tell name msg\n/sit  /stand  /attack\nVars: %t = target name,  %n = your name"
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", UITheme.C_TEXT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(help)

	_social_line_edits.clear()
	for i in 5:
		var row := HBoxContainer.new()
		right.add_child(row)

		var lnum := Label.new()
		lnum.text = "Line %d:" % (i + 1)
		lnum.custom_minimum_size.x = 50
		lnum.add_theme_font_size_override("font_size", 11)
		row.add_child(lnum)

		var le := LineEdit.new()
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.placeholder_text = "/say Hello!" if i == 0 else ""
		row.add_child(le)
		_social_line_edits.append(le)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	right.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Close"
	btn_close.pressed.connect(func(): _social_win.hide())
	btn_row.add_child(btn_close)

	_social_save_btn = Button.new()
	_social_save_btn.text = "Save"
	_social_save_btn.pressed.connect(_on_social_save)
	btn_row.add_child(_social_save_btn)

	SocialHotkeys.library_changed.connect(_refresh_social_list)

func _open_social_library(pick_mode: bool) -> void:
	_social_pick_mode = pick_mode
	_social_editing_id = ""
	_refresh_social_list()
	_clear_social_editor()
	_update_social_status()
	_social_win.popup_centered()

func _refresh_social_list() -> void:
	if _social_list == null:
		return
	_social_list.clear()
	for entry: Dictionary in SocialHotkeys.library_list():
		_social_list.add_item(entry["label"] if entry["label"] != "" else "(unnamed)")
	if _social_list.item_count == 0:
		_social_list.add_item("(no socials yet — click 'New social')")
		_social_list.set_item_disabled(0, true)
	# Reselect the entry we were editing, if it survived a rebuild.
	if _social_editing_id != "":
		var entries: Array = SocialHotkeys.library_list()
		for i in entries.size():
			if (entries[i] as Dictionary).get("id") == _social_editing_id:
				_social_list.select(i)
				break

func _on_social_list_selected(idx: int) -> void:
	var entries: Array = SocialHotkeys.library_list()
	if idx < 0 or idx >= entries.size():
		return
	var entry: Dictionary = entries[idx]
	_social_editing_id = entry["id"]
	_social_label_edit.text = entry["label"]
	var lines: Array = entry["lines"]
	for i in 5:
		_social_line_edits[i].text = lines[i] if i < lines.size() else ""
	_social_delete_btn.disabled = false
	_update_social_status()

func _on_social_list_activated(idx: int) -> void:
	# Double-click. In pick mode, this assigns and closes. In browse
	# mode it just keeps the selection.
	if not _social_pick_mode:
		return
	var entries: Array = SocialHotkeys.library_list()
	if idx < 0 or idx >= entries.size():
		return
	var entry: Dictionary = entries[idx]
	SocialHotkeys.set_slot_social_ref(_ctx_slot, entry["id"])
	_social_win.hide()

func _on_social_new() -> void:
	_social_editing_id = ""
	_clear_social_editor()
	_social_delete_btn.disabled = true
	_social_list.deselect_all()
	_social_label_edit.grab_focus()
	_update_social_status()

func _on_social_save() -> void:
	var lbl: String = _social_label_edit.text.strip_edges()
	if lbl == "":
		lbl = "Macro"
	var lines: Array = []
	for le: LineEdit in _social_line_edits:
		lines.append(le.text)
	if _social_editing_id == "":
		# New entry. In pick mode, also assign it to the ctx slot
		# (matches the muscle memory of the old single-shot editor:
		# "create + use it now").
		_social_editing_id = SocialHotkeys.library_add(lbl, lines)
		if _social_pick_mode:
			SocialHotkeys.set_slot_social_ref(_ctx_slot, _social_editing_id)
			_social_win.hide()
			return
	else:
		SocialHotkeys.library_edit(_social_editing_id, lbl, lines)
	_update_social_status()

func _on_social_delete() -> void:
	if _social_editing_id == "":
		return
	SocialHotkeys.library_delete(_social_editing_id)
	_social_editing_id = ""
	_clear_social_editor()
	_social_delete_btn.disabled = true
	_update_social_status()

func _clear_social_editor() -> void:
	_social_label_edit.text = ""
	for le in _social_line_edits:
		le.text = ""

func _update_social_status() -> void:
	if _social_pick_mode:
		_social_status.text = "Pick a social to assign to slot %d (or create a new one)." % (_ctx_slot + 1)
	elif _social_editing_id == "":
		_social_status.text = "New social — fill in the label and lines, then Save."
	else:
		_social_status.text = "Editing — changes Save to every slot using this social."

func _refresh_hotkey_slots() -> void:
	_bank_label.text = "Bank %d" % (SocialHotkeys.current_bank + 1)
	for i in SLOT_COUNT:
		_update_hotkey_slot(i)
	_rebuild_hotkey_maps()

func _update_hotkey_slot(i: int) -> void:
	var sd: Dictionary  = SocialHotkeys.get_slot(i)
	var vis: Dictionary = _hotkey_slots[i]

	var icon: TextureRect = vis["icon"]
	var name_lbl: Label   = vis["name_label"]

	match sd["type"]:
		SocialHotkeys.TYPE_SPELL:
			var sp := _find_spell(sd["identifier"])
			icon.texture = sp.icon if sp else null
			name_lbl.text = sd["label"]
		SocialHotkeys.TYPE_SKILL:
			var sk := _find_skill(sd["identifier"])
			icon.texture = sk.icon if sk else null
			name_lbl.text = sd["label"]
		SocialHotkeys.TYPE_SOCIAL:
			icon.texture = null
			name_lbl.text = sd["label"]
		_:
			icon.texture = null
			name_lbl.text = ""

func _refresh_spell_slots() -> void:
	# Track 16.1 — spell bar is now a player-configurable memorize bar.
	# Each slot reads its memorized spell name from SpellBar; the auto-
	# population from Spells.available is gone (clicking a spell in the
	# book is what populates these slots now).
	_spell_bar_idx.clear()
	for i in SLOT_COUNT:
		var vis: Dictionary = _spell_slots[i]
		var unlocked: bool = SpellBar.is_slot_unlocked(i)
		var sp := SpellBar.get_spell(i)
		var icon: TextureRect = vis["icon"]
		var name_lbl: Label   = vis["name_label"]
		var lock_lbl: Label   = vis["lock_label"]
		if sp != null:
			icon.texture     = sp.icon
			icon.modulate    = Color.WHITE
			name_lbl.text    = sp.spell_name
			lock_lbl.visible = false
			_spell_bar_idx[sp.spell_name] = i
		else:
			icon.texture     = null
			name_lbl.text    = ""
			if unlocked:
				lock_lbl.visible = false
			else:
				lock_lbl.text    = "Lv %d" % SpellBar.unlock_level_for_slot(i)
				lock_lbl.visible = true
		# Dim everything (icon + key label) on locked slots so the
		# whole slot reads as "not yet available".
		var dim: float = 1.0 if unlocked else 0.35
		icon.modulate    = Color(1.0, 1.0, 1.0, dim) if sp != null else Color(1.0, 1.0, 1.0, 1.0)
		name_lbl.modulate = Color(1.0, 1.0, 1.0, dim)
		(vis["key_label"] as Label).modulate = Color(1.0, 1.0, 1.0, dim)
		_style_spell_slot(vis)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	var slot_idx := -1
	match key:
		KEY_1: slot_idx = 0
		KEY_2: slot_idx = 1
		KEY_3: slot_idx = 2
		KEY_4: slot_idx = 3
		KEY_5: slot_idx = 4
		KEY_6: slot_idx = 5
		KEY_7: slot_idx = 6
		KEY_8: slot_idx = 7
		KEY_9: slot_idx = 8
		KEY_0: slot_idx = 9
	if slot_idx < 0:
		return
	if event.alt_pressed:
		# Track 16.1 — Alt+digit now casts the memorized spell in the
		# matching spell-bar slot, not the i-th spell from the
		# (defunct) auto-populated list.
		SpellBar.cast_slot(slot_idx)
	else:
		SocialHotkeys.execute_slot(slot_idx)

func _on_spell_clicked(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# Track 17.1 — with a memorize candidate held, left-click on
		# a spell-bar slot starts a memorize cast (2 s, half-cost MP);
		# Memorize.commit handles the sit / move / mana checks and
		# writes the slot only on completion. Without a candidate,
		# left-click casts the already-memorized spell.
		if Memorize.candidate != null:
			Memorize.commit(index)
			return
		SpellBar.cast_slot(index)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click clears the memorize. Closes the user's
		# 2026-05-22 ask: "Right-click a spell on the hotbar, spell is
		# not removed."
		if SpellBar.get_slot(index) != "":
			SpellBar.clear_slot(index)

func _on_memorize_candidate_changed(_spell) -> void:
	# 17.1 — only the spell bar highlights empty slots while a
	# candidate is held; hotkey bar isn't a memorize target anymore.
	for vis: Dictionary in _spell_slots:
		_style_spell_slot(vis)

func _on_memorize_started(spell: SpellData, _duration: float) -> void:
	# Paint the target slot with the candidate icon at half opacity so
	# the player sees which slot is receiving the spell. The lavender
	# fill grows from the bottom as the cast progresses.
	var slot: int = Memorize.get_commit_slot()
	if slot < 0 or slot >= _spell_slots.size():
		return
	var vis: Dictionary = _spell_slots[slot]
	(vis["icon"] as TextureRect).texture  = spell.icon
	(vis["icon"] as TextureRect).modulate = Color(1.0, 1.0, 1.0, 0.55)
	(vis["name_label"] as Label).text     = spell.spell_name
	(vis["name_label"] as Label).modulate = Color(1.0, 1.0, 1.0, 0.7)
	var overlay: ColorRect = vis["memorize_overlay"]
	overlay.visible    = true
	overlay.anchor_top = 1.0

func _on_memorize_progress(elapsed: float, total: float) -> void:
	var slot: int = Memorize.get_commit_slot()
	if slot < 0 or slot >= _spell_slots.size():
		return
	var vis: Dictionary = _spell_slots[slot]
	var overlay: ColorRect = vis["memorize_overlay"]
	overlay.anchor_top = 1.0 - clampf(elapsed / total, 0.0, 1.0)

func _on_memorize_cancelled(_reason: String) -> void:
	# The slot was painted optimistically; restore from SpellBar.
	for i in SLOT_COUNT:
		var vis: Dictionary = _spell_slots[i]
		(vis["memorize_overlay"] as ColorRect).visible = false
	_refresh_spell_slots()

func _on_memorize_completed(_spell: SpellData, _slot: int) -> void:
	# SpellBar.set_slot already fired slot_changed → _refresh_spell_slots,
	# so the icon now reflects the saved spell. Just hide the overlay.
	for i in SLOT_COUNT:
		var vis: Dictionary = _spell_slots[i]
		(vis["memorize_overlay"] as ColorRect).visible = false

func _style_spell_slot(vis: Dictionary) -> void:
	# Highlight empty spell-bar slots while a memorize candidate is held
	# (the same gold-border accent the open-bag pattern uses) so the
	# player sees where to click next. Filled slots keep their normal
	# look — overwriting an assigned slot is allowed but not advertised.
	var frame: Panel = vis["frame"]
	var s := StyleBoxFlat.new()
	if Memorize.candidate != null and SpellBar.get_slot(vis["index"]) == "":
		s.bg_color     = C_READY
		s.border_color = UITheme.C_TITLE
		s.set_border_width_all(2)
	else:
		s.bg_color     = C_READY
		s.border_color = UITheme.C_BORDER
		s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", s)

func _on_skill_cooldown(skill_name: String, remaining: float, total: float) -> void:
	var idx: int = _hotkey_by_skill.get(skill_name, -1)
	if idx >= 0:
		_apply_cooldown(_hotkey_slots[idx], remaining, total)

func _on_spell_cooldown(spell_name: String, remaining: float, total: float) -> void:
	var hidx: int = _hotkey_by_spell.get(spell_name, -1)
	if hidx >= 0:
		_apply_cooldown(_hotkey_slots[hidx], remaining, total)
	var sidx: int = _spell_bar_idx.get(spell_name, -1)
	if sidx >= 0:
		_apply_cooldown(_spell_slots[sidx], remaining, total)

func _apply_cooldown(vis: Dictionary, remaining: float, total: float) -> void:
	var overlay: ColorRect = vis["cooldown_overlay"]
	var lbl: Label         = vis["cooldown_label"]
	if remaining > 0.0:
		overlay.visible   = true
		lbl.visible       = true
		lbl.text          = "%.1f" % remaining
		overlay.anchor_top = 1.0 - (remaining / total)
	else:
		overlay.visible = false
		lbl.visible     = false

func _on_bank_changed(_bank_idx: int) -> void:
	_refresh_hotkey_slots()

func _on_slot_changed(bank_idx: int, slot_idx: int) -> void:
	if bank_idx == SocialHotkeys.current_bank:
		_update_hotkey_slot(slot_idx)
		_rebuild_hotkey_maps()

func _rebuild_hotkey_maps() -> void:
	_hotkey_by_skill.clear()
	_hotkey_by_spell.clear()
	for i in SLOT_COUNT:
		var sd := SocialHotkeys.get_slot(i)
		match sd["type"]:
			SocialHotkeys.TYPE_SKILL:
				_hotkey_by_skill[sd["identifier"]] = i
			SocialHotkeys.TYPE_SPELL:
				_hotkey_by_spell[sd["identifier"]] = i

func _on_hotkey_hover(slot: int) -> void:
	var sd: Dictionary = SocialHotkeys.get_slot(slot)
	var text := ""
	match sd["type"]:
		SocialHotkeys.TYPE_SPELL:
			var sp := _find_spell(sd["identifier"])
			if sp:
				text = "%s\n%s\nMP: %.0f  CD: %.1fs" % [sp.spell_name, sp.description, sp.mana_cost, sp.cooldown]
		SocialHotkeys.TYPE_SKILL:
			var sk := _find_skill(sd["identifier"])
			if sk:
				text = "%s\n%s\nST: %.0f  CD: %.1fs" % [sk.skill_name, sk.description, sk.stamina_cost, sk.cooldown]
		SocialHotkeys.TYPE_SOCIAL:
			var lines := sd.get("lines", []) as Array
			var preview := "\n".join(lines.filter(func(l): return l.strip_edges() != ""))
			text = "[Social] %s\n%s" % [sd["label"], preview]
	if text == "":
		_tooltip_panel.visible = false
		return
	_tooltip_label.text = text
	var frame: Panel = _hotkey_slots[slot]["frame"]
	_tooltip_panel.position = frame.global_position - _hotkey_panel.global_position + Vector2(0, -80)
	_tooltip_panel.visible = true

func _on_spell_hover(index: int) -> void:
	var text := ""
	var sp := SpellBar.get_spell(index)
	if sp != null:
		text = "%s\n%s\nMP: %.0f  CD: %.1fs" % [sp.spell_name, sp.description, sp.mana_cost, sp.cooldown]
	elif Memorize.candidate != null:
		text = "Click to memorize %s here." % Memorize.candidate.spell_name
	if text == "":
		_tooltip_panel.visible = false
		return
	_tooltip_label.text = text
	var frame: Panel = _spell_slots[index]["frame"]
	_tooltip_panel.position = frame.global_position - _hotkey_panel.global_position + Vector2(0, -80)
	_tooltip_panel.visible = true

func _style_slot(frame: Panel, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color     = C_ACTIVE if active else C_READY
	s.border_color = UITheme.C_TITLE if active else UITheme.C_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", s)

func _find_spell(spell_name: String) -> SpellData:
	for sp in Spells.available:
		if sp.spell_name == spell_name:
			return sp
	return null

func _find_skill(skill_name: String) -> SkillData:
	for sk in Skills.available:
		if sk.skill_name == skill_name:
			return sk
	return null
