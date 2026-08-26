class_name SpellBook
extends DraggablePanel

const C_BG   := Color(0.07, 0.06, 0.04, 0.95)
const C_ROW  := Color(0.12, 0.10, 0.07, 1.00)
const C_HOVER := Color(0.20, 0.16, 0.10, 1.00)
# Track 16.1 — gold-tinted highlight to mark the spell currently
# selected for memorization. Matches the open-bag accent so the player
# sees "this is staged, pick a spell-bar slot next".
const C_MEMORIZE := Color(0.30, 0.22, 0.06, 1.00)
const ROW_H  := 28

var _vbox: VBoxContainer = null
var _rows: Array = []
# row data: {bg, normal_style, hover_style, memorize_style, spell, hovered}
var _row_data: Array = []
# Skills tab (2026-08-26): the book shows BOTH halves of a class's abilities.
# Pure casters see only Spells, pure melee only Skills, hybrids (Paladin,
# Ranger, Shadow Knight...) both — a Warrior looking for Shield Bash in a
# spells-only book was the report that motivated this.
var _tabs: TabContainer = null
var _skills_vbox: VBoxContainer = null
var _skill_rows: Array = []

func _ready() -> void:
	_build()
	Spells.spells_changed.connect(_rebuild)
	Skills.skills_changed.connect(_rebuild_skills)
	Memorize.candidate_changed.connect(_on_candidate_changed)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild()
	_rebuild_skills()

func _build() -> void:
	custom_minimum_size = Vector2(300, 320)
	position = Vector2(220, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 4)
	outer.offset_left = 8; outer.offset_top = 8
	outer.offset_right = -8; outer.offset_bottom = -8
	add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	var title := Label.new()
	title.text = "Spellbook"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_tabs)

	# ── Spells tab ────────────────────────────────────────────────────────────
	var spells_tab := VBoxContainer.new()
	spells_tab.name = "Spells"
	spells_tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(spells_tab)

	# Track 16.1 — short usage hint so a player who hasn't read the
	# release notes still discovers the sit+click+slot flow.
	var hint := Label.new()
	hint.text = "Sit, click a spell, then click a Spell Bar slot to memorize."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UITheme.C_TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spells_tab.add_child(hint)

	var col_row := HBoxContainer.new()
	col_row.add_theme_constant_override("separation", 4)
	spells_tab.add_child(col_row)
	_add_col_hdr(col_row, "Spell", 0, true)
	_add_col_hdr(col_row, "MP",   36, false)
	_add_col_hdr(col_row, "CD",   44, false)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spells_tab.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_vbox)

	# ── Skills tab ────────────────────────────────────────────────────────────
	var skills_tab := VBoxContainer.new()
	skills_tab.name = "Skills"
	skills_tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(skills_tab)

	var skill_hint := Label.new()
	skill_hint.text = "Right-click an empty hotbar slot, then Assign Skill, to put one on your bar."
	skill_hint.add_theme_font_size_override("font_size", 10)
	skill_hint.add_theme_color_override("font_color", UITheme.C_TEXT)
	skill_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_tab.add_child(skill_hint)

	var skill_cols := HBoxContainer.new()
	skill_cols.add_theme_constant_override("separation", 4)
	skills_tab.add_child(skill_cols)
	_add_col_hdr(skill_cols, "Skill", 0, true)
	_add_col_hdr(skill_cols, "ST",   36, false)
	_add_col_hdr(skill_cols, "CD",   44, false)

	var skill_scroll := ScrollContainer.new()
	skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skills_tab.add_child(skill_scroll)

	_skills_vbox = VBoxContainer.new()
	_skills_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_vbox.add_theme_constant_override("separation", 2)
	skill_scroll.add_child(_skills_vbox)

func _add_col_hdr(parent: HBoxContainer, text: String, min_w: float, expand: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	if min_w > 0:
		lbl.custom_minimum_size.x = min_w
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)

func _rebuild() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	_row_data.clear()
	for spell in Spells.available:
		var row := _make_row(spell)
		_vbox.add_child(row)
		_rows.append(row)
	# Stale-candidate cleanup happens in SpellBar's spells_changed
	# handler, but the spell book also wants to drop the highlight if
	# the candidate's row is gone after a level-up rank refresh.
	if Memorize.candidate != null:
		var still_listed := false
		for sp in Spells.available:
			if sp == Memorize.candidate:
				still_listed = true
				break
		if not still_listed:
			Memorize.clear()
	# Re-apply the highlight after rebuild.
	_repaint_all()
	_update_tab_visibility()

func _rebuild_skills() -> void:
	for row in _skill_rows:
		row.queue_free()
	_skill_rows.clear()
	for skill in Skills.available:
		var row := _make_skill_row(skill)
		_skills_vbox.add_child(row)
		_skill_rows.append(row)
	_update_tab_visibility()

## Pure casters see only the Spells tab, pure melee only Skills, hybrids both.
## Driven by list emptiness rather than a class table, so it stays correct as
## definitions change. Both-empty keeps Spells visible (an empty book beats a
## tabless one).
func _update_tab_visibility() -> void:
	if _tabs == null:
		return
	var has_spells := Spells.available.size() > 0
	var has_skills := Skills.available.size() > 0
	_tabs.set_tab_hidden(0, not has_spells and has_skills)
	_tabs.set_tab_hidden(1, not has_skills)
	if not has_spells and has_skills:
		_tabs.current_tab = 1

func _make_skill_row(skill: SkillData) -> Panel:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = C_ROW
	normal_style.set_corner_radius_all(2)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_HOVER
	hover_style.set_corner_radius_all(2)

	var bg := Panel.new()
	bg.custom_minimum_size.y = ROW_H
	bg.add_theme_stylebox_override("panel", normal_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var extra := ""
	if skill.damage_multiplier > 0.0:
		extra = "  Damage: %.1fx" % skill.damage_multiplier
	bg.tooltip_text = "%s
%s
Stamina: %d  CD: %s%s" % [
		skill.skill_name, skill.description, int(skill.stamina_cost),
		("%.0fs" % skill.cooldown) if skill.cooldown > 0.0 else "—",
		extra,
	]

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4; row.offset_top = 2
	row.offset_right = -4; row.offset_bottom = -2
	row.add_theme_constant_override("separation", 4)
	bg.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = skill.skill_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var st_lbl := Label.new()
	st_lbl.text = "%d" % int(skill.stamina_cost)
	st_lbl.custom_minimum_size.x = 36
	st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st_lbl.add_theme_font_size_override("font_size", 11)
	st_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.45))
	row.add_child(st_lbl)

	var cd_lbl := Label.new()
	cd_lbl.text = ("%.0fs" % skill.cooldown) if skill.cooldown > 0.0 else "—"
	cd_lbl.custom_minimum_size.x = 44
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cd_lbl.add_theme_font_size_override("font_size", 11)
	cd_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	row.add_child(cd_lbl)

	bg.mouse_entered.connect(func() -> void:
		bg.add_theme_stylebox_override("panel", hover_style))
	bg.mouse_exited.connect(func() -> void:
		bg.add_theme_stylebox_override("panel", normal_style))
	return bg

func _make_row(spell: SpellData) -> Panel:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = C_ROW
	normal_style.set_corner_radius_all(2)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_HOVER
	hover_style.set_corner_radius_all(2)

	var memorize_style := StyleBoxFlat.new()
	memorize_style.bg_color = C_MEMORIZE
	memorize_style.border_color = UITheme.C_TITLE
	memorize_style.set_border_width_all(1)
	memorize_style.set_corner_radius_all(2)

	var bg := Panel.new()
	bg.custom_minimum_size.y = ROW_H
	bg.add_theme_stylebox_override("panel", normal_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.tooltip_text = "%s\n%s\nMP: %d  Cast: %s  CD: %s" % [
		spell.spell_name, spell.description, int(spell.mana_cost),
		("%.1fs" % spell.cast_time) if spell.cast_time > 0.0 else "instant",
		("%.0fs" % spell.cooldown) if spell.cooldown > 0.0 else "—",
	]

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4; row.offset_top = 2
	row.offset_right = -4; row.offset_bottom = -2
	row.add_theme_constant_override("separation", 4)
	bg.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = spell.spell_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var mp_lbl := Label.new()
	mp_lbl.text = "%d" % int(spell.mana_cost)
	mp_lbl.custom_minimum_size.x = 36
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_lbl.add_theme_font_size_override("font_size", 11)
	mp_lbl.add_theme_color_override("font_color", Color(0.45, 0.60, 1.00))
	row.add_child(mp_lbl)

	var cd_lbl := Label.new()
	cd_lbl.text = ("%.0fs" % spell.cooldown) if spell.cooldown > 0.0 else "—"
	cd_lbl.custom_minimum_size.x = 44
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cd_lbl.add_theme_font_size_override("font_size", 11)
	cd_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	row.add_child(cd_lbl)

	var data := {
		"bg":              bg,
		"spell":           spell,
		"normal_style":    normal_style,
		"hover_style":     hover_style,
		"memorize_style":  memorize_style,
		"hovered":         false,
	}
	_row_data.append(data)

	bg.mouse_entered.connect(func() -> void:
		data["hovered"] = true
		_repaint_row(data))
	bg.mouse_exited.connect(func() -> void:
		data["hovered"] = false
		_repaint_row(data))
	# Track 16.1 — row click no longer casts. Sit-gated select: tags
	# the spell as the memorize candidate; spell / hotkey bar slot
	# clicks then route it through SpellBar.set_slot / set_slot_spell.
	bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_row_clicked(spell)
			bg.accept_event())

	return bg

func _on_row_clicked(spell: SpellData) -> void:
	var player := _find_local_player()
	if player == null or player.state != PlayerCharacter.PlayerState.SITTING:
		CombatLog.add_line("You must be sitting to memorize spells.", CombatLog.MsgType.INFO)
		Memorize.clear()
		return
	# Toggle off if it's the same spell — second click cancels memo
	# selection so the player can back out without closing the book.
	if Memorize.candidate == spell:
		Memorize.clear()
		return
	Memorize.set_candidate(spell)

func _find_local_player() -> PlayerCharacter:
	var nodes := get_tree().get_nodes_in_group("player")
	for n in nodes:
		if n is PlayerCharacter and (n as PlayerCharacter).is_multiplayer_authority():
			return n
	return null

func _on_candidate_changed(_spell) -> void:
	_repaint_all()

func _on_visibility_changed() -> void:
	# Closing the spellbook drops the candidate — the spell bar slot
	# click belongs to the same gesture, and a stale candidate left
	# alive after a close-and-reopen is more surprising than helpful.
	if not visible:
		Memorize.clear()

func _repaint_all() -> void:
	for data in _row_data:
		_repaint_row(data)

func _repaint_row(data: Dictionary) -> void:
	var bg: Panel = data["bg"]
	if Memorize.candidate == data["spell"]:
		bg.add_theme_stylebox_override("panel", data["memorize_style"])
	elif data["hovered"]:
		bg.add_theme_stylebox_override("panel", data["hover_style"])
	else:
		bg.add_theme_stylebox_override("panel", data["normal_style"])
