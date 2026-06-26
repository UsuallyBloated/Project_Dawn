extends CanvasLayer

const _OptionsScreenScript  := preload("res://scripts/options_screen.gd")
const _CraftingWindowScript := preload("res://scripts/crafting_window.gd")
const _VendorWindowScript   := preload("res://scripts/vendor_window.gd")
const _BankWindowScript     := preload("res://scripts/bank_window.gd")
const _HudDeathScreen       := preload("res://scripts/hud_death_screen.gd")
const _HudCastBar           := preload("res://scripts/hud_cast_bar.gd")
const _HudBuffBar           := preload("res://scripts/hud_buff_bar.gd")
const _HudDebuffBar         := preload("res://scripts/hud_debuff_bar.gd")
const _HudPetPanel          := preload("res://scripts/hud_pet_panel.gd")
const _HudGroupPanel        := preload("res://scripts/hud_group_panel.gd")
const _TrackWindowScript    := preload("res://scripts/track_window.gd")
const _SpellBookScript      := preload("res://scripts/spell_book.gd")
const _QuestJournalScript   := preload("res://scripts/quest_journal.gd")
const _DialogueWindowScript := preload("res://scripts/dialogue_window.gd")
const _InspectWindowScript  := preload("res://scripts/inspect_window.gd")
const _DebugConsoleScript   := preload("res://scripts/debug_console.gd")

@onready var health_bar: ProgressBar = $Panel/VBoxContainer/HPRow/HealthBar
@onready var stamina_bar: ProgressBar = $Panel/VBoxContainer/STARow/StaminaBar
@onready var mana_bar: ProgressBar = $Panel/VBoxContainer/MPRow/ManaBar
@onready var character_window: Panel = $CharacterWindow
@onready var inventory_window: Panel = $InventoryWindow
@onready var paperdoll_window: Panel = $PaperdollWindow
@onready var target_frame: Panel = $TargetFrame
@onready var target_name_label: Label = $TargetFrame/VBox/NameLabel
@onready var target_level_label: Label = $TargetFrame/VBox/LevelLabel
@onready var target_hp_bar: ProgressBar = $TargetFrame/VBox/HPBar
@onready var target_mp_bar: ProgressBar = $TargetFrame/VBox/MPBar
@onready var target_st_bar: ProgressBar = $TargetFrame/VBox/StaminaBar
@onready var target_cast_bar: ProgressBar = $TargetFrame/VBox/CastBar
@onready var target_cast_label: Label = $TargetFrame/VBox/CastLabel
@onready var target_buffs_label: Label = $TargetFrame/VBox/BuffsLabel

var _clock_label: Label = null
var _state_label: Label = null
var _encumbrance_label: Label = null
# Camp slice B — /camp countdown overlay. Driven by Net.world_camp_update; ticks
# locally in _process while _camp_active. The server owns the real timer + logout.
var _camp_label: Label = null
# Slice 3 — resurrection offer prompt (Accept/Decline). Shown by
# Net.world_resurrect_offer; the corpse_id is sent back on the response.
var _res_prompt: Panel = null
var _res_label: Label = null
var _res_corpse_id: int = -1
var _camp_active: bool = false
var _camp_seconds_left: float = 0.0
var _hp_label: Label = null
var _mp_label: Label = null
var _sta_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_label: Label = null
@onready var _player_name_label: Label = $Panel/VBoxContainer/PlayerNameLabel

var _window_stack: Array = []
var _tracked_target = null
# Target-frame buff icon row (small versions of the main buff-bar panels),
# created lazily under the BuffsLabel's parent and rebuilt on each refresh.
var _target_buff_icons: HFlowContainer = null
# Buff-name → border color, matching the main buff bar's per-type colors
# (gold stat / blue clarity / yellow haste / green speed / orange shield).
# Unknown names (HoTs etc.) fall back to a green default.
const _TARGET_BUFF_COLORS := {
	"Bless": Color(0.95, 0.80, 0.35), "Valor": Color(0.95, 0.80, 0.35),
	"Brilliance": Color(0.95, 0.80, 0.35), "Strength": Color(0.95, 0.80, 0.35),
	"Spirit of the Bear": Color(0.95, 0.80, 0.35), "Gift of Insight": Color(0.95, 0.80, 0.35),
	"Clarity": Color(0.30, 0.50, 1.00), "Breeze": Color(0.30, 0.50, 1.00),
	"Haste": Color(0.95, 0.85, 0.10),
	"Spirit of Wolf": Color(0.40, 0.85, 0.40),
	"Thorns": Color(0.85, 0.40, 0.20), "Spellshield": Color(0.85, 0.40, 0.20),
}
var _player: Node3D = null
var _options_screen: Panel = null
var _crafting_window: Panel = null
var _vendor_window: Panel = null
var _bank_window: Panel = null

var _group_panel = null
var _pet_panel = null
var _track_window: TrackWindow = null
var _spell_book: Panel = null
var _quest_journal: Panel = null
var _dialogue_window: Panel = null
var _inspect_window: InspectWindow = null
var _debug_console: DebugConsole = null
var _target_hp_label: Label = null
var _target_mp_label: Label = null
var _target_st_label: Label = null

var _tot_frame: DraggablePanel = null
var _tot_name_label: Label = null
var _tot_hp_bar: ProgressBar = null
var _tot_hp_label: Label = null
# Track 21B — node the ToT frame is currently rendering. Cached so
# we can disconnect its hp/death signals on retarget without a
# scene-tree walk; null when ToT is hidden or pointing at the local
# player (PlayerStats is the source there).
var _tot_entity: Node = null

var _self_targeted: bool = false

func _ready() -> void:
	_style_panel()
	_hp_label  = UITheme.style_bar(health_bar,  UITheme.C_BAR_HP)
	_sta_label = UITheme.style_bar(stamina_bar, UITheme.C_BAR_STAMINA)
	_mp_label  = UITheme.style_bar(mana_bar,    UITheme.C_BAR_MANA)
	$Panel/VBoxContainer/HPRow/HPLabel.add_theme_color_override("font_color",  Color(0.95, 0.45, 0.45))
	$Panel/VBoxContainer/MPRow/MPLabel.add_theme_color_override("font_color",  Color(0.45, 0.60, 1.00))
	$Panel/VBoxContainer/STARow/STALabel.add_theme_color_override("font_color", Color(1.00, 0.92, 0.35))

	_target_hp_label = UITheme.style_bar(target_hp_bar, UITheme.C_BAR_HP)
	_target_mp_label = UITheme.style_bar(target_mp_bar, UITheme.C_BAR_MANA)
	_target_st_label = UITheme.style_bar(target_st_bar, UITheme.C_BAR_STAMINA)
	# Cast bar uses XP color (warm gold). Distinct enough from the mana
	# blue and stamina yellow that the player can tell at a glance.
	UITheme.style_bar(target_cast_bar, UITheme.C_BAR_XP, false)
	target_mp_bar.visible = false
	target_st_bar.visible = false
	target_cast_bar.visible = false
	target_cast_label.visible = false
	target_buffs_label.visible = false
	if _target_buff_icons != null and is_instance_valid(_target_buff_icons):
		_target_buff_icons.visible = false
	if _target_mp_label:
		_target_mp_label.visible = false
	if _target_st_label:
		_target_st_label.visible = false

	PlayerStats.hp_changed.connect(_on_hp_changed)
	PlayerStats.mp_changed.connect(_on_mp_changed)
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	Combat.target_changed.connect(_on_target_changed)
	target_frame.visible = false
	$Panel.gui_input.connect(_on_stat_panel_input)

	health_bar.max_value = PlayerStats.max_hp
	health_bar.value = PlayerStats.hp
	stamina_bar.max_value = PlayerStats.max_stamina
	stamina_bar.value = PlayerStats.stamina
	mana_bar.max_value = PlayerStats.max_mp
	mana_bar.value = PlayerStats.mp
	_hp_label.text  = "%d / %d" % [int(PlayerStats.hp),      int(PlayerStats.max_hp)]
	_mp_label.text  = "%d / %d" % [int(PlayerStats.mp),      int(PlayerStats.max_mp)]
	_sta_label.text = "%d / %d" % [int(PlayerStats.stamina), int(PlayerStats.max_stamina)]

	for w in [character_window, inventory_window, paperdoll_window]:
		w.visibility_changed.connect(_on_window_visibility_changed.bind(w))

	_build_xp_bar()
	_refresh_player_name_label()
	PlayerStats.character_applied.connect(_refresh_player_name_label)
	_build_portrait()
	_refresh_portrait()
	PlayerStats.character_applied.connect(_refresh_portrait)
	_build_clock()
	_build_state_label()
	_build_encumbrance_indicator()
	_build_camp_indicator()
	_build_res_prompt()
	_build_command_input()
	_build_options_screen()
	_build_crafting_window()
	_build_vendor_window()
	_build_bank_window()
	_build_components()
	_connect_player_state()

func _build_components() -> void:
	var death_screen := _HudDeathScreen.new()
	add_child(death_screen)

	var cast_bar := _HudCastBar.new()
	add_child(cast_bar)

	var buff_bar := _HudBuffBar.new()
	add_child(buff_bar)

	var debuff_bar := _HudDebuffBar.new()
	add_child(debuff_bar)

	_group_panel = _HudGroupPanel.new()
	add_child(_group_panel)

	_pet_panel = _HudPetPanel.new()
	add_child(_pet_panel)

	_track_window = _TrackWindowScript.new()
	add_child(_track_window)

	_spell_book = _SpellBookScript.new()
	_spell_book.visible = false
	add_child(_spell_book)
	_spell_book.visibility_changed.connect(_on_window_visibility_changed.bind(_spell_book))

	_quest_journal = _QuestJournalScript.new()
	_quest_journal.visible = false
	add_child(_quest_journal)
	_quest_journal.visibility_changed.connect(_on_window_visibility_changed.bind(_quest_journal))

	_dialogue_window = _DialogueWindowScript.new()
	_dialogue_window.visible = false
	add_child(_dialogue_window)

	_inspect_window = _InspectWindowScript.new()
	_inspect_window.visible = false
	add_child(_inspect_window)
	_inspect_window.visibility_changed.connect(_on_window_visibility_changed.bind(_inspect_window))

	# In-game DebugLog tail. Independent of the user-data debug.log
	# file (which gets corrupted when two clients share the same
	# Godot user dir), so this stays useful in multi-client testing.
	# Built in code (no .tscn) so the preload doesn't fail on first
	# touch before Godot has imported the scene file. Toggle with F2
	# (see _unhandled_input).
	_debug_console = _DebugConsoleScript.new()
	add_child(_debug_console)

	_build_tot_frame()

	_group_panel.layout_changed.connect(_reposition_pet_panel)
	_reposition_pet_panel()

func _reposition_pet_panel() -> void:
	if _pet_panel == null or _group_panel == null:
		return
	_pet_panel.position.y = _group_panel.position.y + _group_panel.size.y + 8.0

func _build_tot_frame() -> void:
	var tot := DraggablePanel.new()
	_tot_frame = tot
	_tot_frame.visible = false

	add_child(_tot_frame)
	var vp := get_viewport().get_visible_rect().size
	_tot_frame.setup(Vector2(vp.x - 154.0, 4.0), Vector2(150.0, 34.0), Vector2(100.0, 28.0))
	tot.apply_style(Color(0.06, 0.05, 0.04, 0.88))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 1)
	vbox.offset_left = 4; vbox.offset_top = 2
	vbox.offset_right = -4; vbox.offset_bottom = -2
	_tot_frame.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 2)
	vbox.add_child(name_row)

	var arrow := Label.new()
	arrow.text = "▶"
	arrow.add_theme_font_size_override("font_size", 8)
	arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(arrow)

	_tot_name_label = Label.new()
	_tot_name_label.add_theme_font_size_override("font_size", 10)
	_tot_name_label.add_theme_color_override("font_color", UITheme.C_TITLE)
	_tot_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tot_name_label.clip_text = true
	name_row.add_child(_tot_name_label)

	_tot_hp_bar = ProgressBar.new()
	_tot_hp_bar.custom_minimum_size = Vector2(0, 6)
	_tot_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tot_hp_bar.show_percentage = false
	_tot_hp_label = UITheme.style_bar(_tot_hp_bar, UITheme.C_BAR_HP)
	vbox.add_child(_tot_hp_bar)

# ── XP bar ────────────────────────────────────────────────────────────────────

func _build_xp_bar() -> void:
	$Panel.offset_top -= 22.0
	var vbox: VBoxContainer = $Panel/VBoxContainer

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "XP"
	lbl.custom_minimum_size = Vector2(32, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.00))
	row.add_child(lbl)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 18)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.min_value = 0
	_xp_bar.max_value = PlayerStats.xp_to_next
	_xp_bar.value = PlayerStats.xp
	_xp_bar.show_percentage = false
	_xp_label = UITheme.style_bar(_xp_bar, Color(0.20, 0.55, 1.00))
	row.add_child(_xp_bar)

	_xp_label.text = "%d / %d" % [PlayerStats.xp, PlayerStats.xp_to_next]
	PlayerStats.xp_changed.connect(_on_xp_changed)

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = current_xp
	_xp_label.text = "%d / %d" % [current_xp, xp_to_next]

# ── Player name label ─────────────────────────────────────────────────────────

func _refresh_player_name_label() -> void:
	if _player_name_label == null:
		return
	var nm := PlayerStats.player_name
	_player_name_label.text = nm if nm != "" else "Adventurer"

# ── Player portrait ───────────────────────────────────────────────────────────

# Track 22.I — race/class portrait slot. TextureRect floats to the
# right of the player stat panel; populates from
# assets/sprites/portraits/portrait_<race>_<class>.png matching the
# naming in docs/concepts/lore/portraits/prompts.md. Missing files
# hide the slot — saves can land incrementally as art is generated.
var _portrait_rect: TextureRect = null

func _build_portrait() -> void:
	_portrait_rect = TextureRect.new()
	_portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.custom_minimum_size = Vector2(96, 96)
	# Position: right of the player stat panel (which sits at
	# offset_left=32 → offset_right=342). 4 px gap, top-aligned.
	_portrait_rect.position = Vector2(346, 8)
	_portrait_rect.size = Vector2(96, 96)
	_portrait_rect.visible = false
	add_child(_portrait_rect)

func _refresh_portrait() -> void:
	if _portrait_rect == null:
		return
	var race: String = PlayerStats.race
	var cls: String = PlayerStats.player_class
	if race == "" or cls == "":
		_portrait_rect.visible = false
		return
	# Slugify: "Dark Elf" → "dark_elf", "Shadow Knight" → "shadow_knight".
	# Lowercased, spaces to underscores, backticks stripped (Kel`varath).
	var race_slug := race.to_lower().replace(" ", "_").replace("`", "")
	var cls_slug := cls.to_lower().replace(" ", "_").replace("`", "")
	var path := "res://assets/sprites/portraits/portrait_%s_%s.png" % [race_slug, cls_slug]
	if not ResourceLoader.exists(path):
		_portrait_rect.visible = false
		_portrait_rect.texture = null
		return
	var tex := load(path) as Texture2D
	if tex == null:
		_portrait_rect.visible = false
		_portrait_rect.texture = null
		return
	_portrait_rect.texture = tex
	_portrait_rect.visible = true

# ── Utility windows ───────────────────────────────────────────────────────────

func _build_options_screen() -> void:
	_options_screen = _OptionsScreenScript.new()
	_options_screen.visible = false
	_options_screen.z_index = 20
	add_child(_options_screen)
	_options_screen.visibility_changed.connect(
		_on_window_visibility_changed.bind(_options_screen))

func _build_crafting_window() -> void:
	_crafting_window = _CraftingWindowScript.new()
	_crafting_window.visible = false
	_crafting_window.z_index = 20
	add_child(_crafting_window)
	_crafting_window.visibility_changed.connect(
		_on_window_visibility_changed.bind(_crafting_window))
	Crafting.skill_level_changed.connect(func(skill: String, lvl: int) -> void:
		CombatLog.add_line(
			"Your %s skill has increased to %d!" % [skill, lvl],
			CombatLog.MsgType.INFO))

func _build_vendor_window() -> void:
	_vendor_window = _VendorWindowScript.new()
	_vendor_window.visible = false
	_vendor_window.z_index = 20
	add_child(_vendor_window)
	_vendor_window.visibility_changed.connect(
		_on_window_visibility_changed.bind(_vendor_window))
	VendorManager.vendor_opened.connect(func(vname: String, vtype: String) -> void:
		(_vendor_window as Node).call("open_for", vname, vtype))

# Banker slice 1 — same lifecycle as the vendor window; opens on
# BankerManager.banker_opened (hud NPC-interact path / BankerNPC proximity).
func _build_bank_window() -> void:
	_bank_window = _BankWindowScript.new()
	_bank_window.visible = false
	_bank_window.z_index = 20
	add_child(_bank_window)
	_bank_window.visibility_changed.connect(
		_on_window_visibility_changed.bind(_bank_window))
	BankerManager.banker_opened.connect(func(bname: String) -> void:
		(_bank_window as Node).call("open_for", bname))

# ── Clock ─────────────────────────────────────────────────────────────────────

func _build_clock() -> void:
	_clock_label = Label.new()
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock_label.position = Vector2(-108.0, 8.0)
	_clock_label.size = Vector2(100.0, 24.0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.58))
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.text = TimeOfDay.get_time_string()
	add_child(_clock_label)

# ── State label & command input ───────────────────────────────────────────────

func _build_state_label() -> void:
	_state_label = Label.new()
	_state_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_state_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_state_label.position = Vector2(-100.0, -160.0)
	_state_label.size = Vector2(200.0, 24.0)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
	_state_label.add_theme_font_size_override("font_size", 13)
	_state_label.visible = false
	add_child(_state_label)

# Weight warning tucked under the stat panel — appears only while over
# capacity, so the player knows why they're slow without opening the
# character window. Yellow = encumbered (slowed), red = overloaded
# (≥ 2× capacity, stamina regen stopped).
func _build_encumbrance_indicator() -> void:
	_encumbrance_label = Label.new()
	var panel: Panel = $Panel
	_encumbrance_label.position = panel.position + Vector2(4.0, panel.size.y + 2.0)
	_encumbrance_label.add_theme_font_size_override("font_size", 11)
	_encumbrance_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_encumbrance_label.add_theme_constant_override("outline_size", 3)
	_encumbrance_label.visible = false
	add_child(_encumbrance_label)
	Encumbrance.encumbrance_changed.connect(_on_encumbrance_changed)
	_on_encumbrance_changed(Encumbrance.total_weight, Encumbrance.capacity)

func _on_encumbrance_changed(weight: float, capacity: float) -> void:
	if weight <= capacity:
		_encumbrance_label.visible = false
		return
	var overloaded := weight >= capacity * Encumbrance.OVERLOADED_RATIO
	_encumbrance_label.text = "%s  %.1f / %.1f" % \
		["Overloaded!" if overloaded else "Encumbered", weight, capacity]
	_encumbrance_label.add_theme_color_override("font_color",
		UITheme.C_OVERLOADED if overloaded else UITheme.C_ENCUMBERED)
	_encumbrance_label.visible = true

# Camp slice B — the /camp countdown overlay, just above the sit "state" label.
# Server-driven: shown/hidden by Net.world_camp_update, ticked locally in
# _process. Amber to read as "leaving the world", outlined for legibility.
func _build_camp_indicator() -> void:
	_camp_label = Label.new()
	_camp_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_camp_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_camp_label.position = Vector2(-100.0, -190.0)
	_camp_label.size = Vector2(200.0, 24.0)
	_camp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camp_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_camp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_camp_label.add_theme_constant_override("outline_size", 3)
	_camp_label.add_theme_font_size_override("font_size", 14)
	_camp_label.visible = false
	add_child(_camp_label)
	Net.world_camp_update.connect(_on_world_camp_update)
	# Any disconnect (camp completion, a kick, a transport drop / linkdead) must
	# clear the overlay so a stale "Making camp..." can't linger on a dead
	# session — the server doesn't send a CampUpdate(false) for those paths.
	Net.app_disconnected.connect(_on_camp_disconnected)

func _on_world_camp_update(remaining_secs: int, active: bool) -> void:
	if _camp_label == null:
		return
	_camp_active = active
	if active:
		_camp_seconds_left = float(remaining_secs)
		_camp_label.text = _camp_text(_camp_seconds_left)
		_camp_label.visible = true
	else:
		_camp_label.visible = false

func _on_camp_disconnected(_reason: String) -> void:
	_camp_active = false
	if _camp_label != null:
		_camp_label.visible = false

# Slice 3 — resurrection offer prompt. A Cleric/Paladin cast a res on your corpse;
# Accept to be summoned to it + refunded a % of the experience that death cost.
func _build_res_prompt() -> void:
	_res_prompt = Panel.new()
	_res_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_res_prompt.custom_minimum_size = Vector2(380.0, 96.0)
	_res_prompt.position = Vector2(-190.0, -130.0)
	_res_prompt.visible = false
	add_child(_res_prompt)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 10
	vbox.offset_right = -12
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	_res_prompt.add_child(vbox)

	_res_label = Label.new()
	_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_res_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)

	var accept := Button.new()
	accept.text = "Accept"
	accept.pressed.connect(_on_res_accept_pressed)
	row.add_child(accept)

	var decline := Button.new()
	decline.text = "Decline"
	decline.pressed.connect(_on_res_decline_pressed)
	row.add_child(decline)

	Net.world_resurrect_offer.connect(_on_world_resurrect_offer)
	# Hide the prompt if its corpse despawns (looted clean or decayed) before we
	# answer, so a stale Accept can't click into a server-side no-op.
	Net.world_entity_despawn.connect(_on_res_corpse_despawn)

func _on_res_corpse_despawn(id: int) -> void:
	if id == _res_corpse_id:
		_hide_res_prompt()

func _on_world_resurrect_offer(corpse_id: int, caster_name: String, xp_percent: int) -> void:
	if _res_prompt == null:
		return
	_res_corpse_id = corpse_id
	_res_label.text = "%s offers to resurrect you.\nReturn %d%% of the experience that death cost?" % [caster_name, xp_percent]
	_res_prompt.visible = true

func _on_res_accept_pressed() -> void:
	if _res_corpse_id >= 0:
		Net.send_resurrect_accept(_res_corpse_id, true)
	_hide_res_prompt()

func _on_res_decline_pressed() -> void:
	if _res_corpse_id >= 0:
		Net.send_resurrect_accept(_res_corpse_id, false)
	_hide_res_prompt()

func _hide_res_prompt() -> void:
	_res_corpse_id = -1
	if _res_prompt != null:
		_res_prompt.visible = false

# Camp slice B — the countdown elapsed: log out cleanly, exactly like the Options
# "Quit Game" button (SaveManager.save -> Net.leave_session -> quit). The server's
# camp window has elapsed too, so this clean Disconnect reaps the body and frees
# the account to relog at once. Completion is client-driven because there is no
# in-game return-to-lobby flow yet; a finished camp exits to desktop, the same end
# state as Quit Game (the player relaunches to relog).
func _complete_camp() -> void:
	_camp_active = false
	if _camp_label != null:
		_camp_label.visible = false
	SaveManager.save()
	Net.leave_session()
	get_tree().quit()

func _camp_text(seconds_left: float) -> String:
	return "Making camp... %d" % int(ceil(seconds_left))

func _build_command_input() -> void:
	CombatLog.chat_submitted.connect(_handle_chat_input)

func _connect_player_state() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		await get_tree().process_frame
		players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_player = players[0]
	if _player.has_signal("state_changed"):
		_player.state_changed.connect(_on_player_state_changed)

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _clock_label != null:
		var t := TimeOfDay.get_time_string()
		if t != _clock_label.text:
			_clock_label.text = t
	# Tick the cast bar for a casting peer target. Reads progress from the
	# RemotePlayer which tracks elapsed via Time.get_unix_time_from_system
	# — server messages provide start + duration, not per-frame progress.
	if target_cast_bar.visible and is_instance_valid(_tracked_target):
		if _tracked_target.has_method("cast_progress_ratio"):
			target_cast_bar.value = _tracked_target.cast_progress_ratio()
	# Camp slice B — tick the local /camp countdown. Standing/moving cancels it
	# immediately client-side for responsiveness (the server independently cancels
	# on stand/move/damage and fans camp_update(false), handled idempotently);
	# when the count reaches 0 still seated, the client drives the clean logout
	# itself (_complete_camp).
	if _camp_active and _camp_label != null:
		if not Combat.is_player_seated():
			_camp_active = false
			_camp_label.visible = false
		else:
			_camp_seconds_left = maxf(_camp_seconds_left - delta, 0.0)
			_camp_label.text = _camp_text(_camp_seconds_left)
			if _camp_seconds_left <= 0.0:
				_complete_camp()

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not CombatLog.is_chat_input_focused():
				CombatLog.show_chat_input()
				get_viewport().set_input_as_handled()
				return
		if CombatLog.is_chat_input_focused():
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _window_stack.size() > 0:
				_window_stack.back().visible = false
				get_viewport().set_input_as_handled()
			elif _options_screen != null:
				_options_screen.visible = !_options_screen.visible
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_QUOTELEFT:
			# Dev-only: in-game tail of DebugLog. Hardcoded (not in
			# Settings.actions) since it's a diagnostic tool, not a
			# rebindable gameplay control. Backtick (`) toggles it; F2 is
			# now EQ's "target group member 1". `/console` is the fallback.
			if _debug_console != null:
				_debug_console.toggle()
				CombatLog.add_line(
					"Debug console: %s (%d lines buffered)" % [
						"ON" if _debug_console.visible else "OFF",
						DebugLog.recent_lines.size(),
					],
					CombatLog.MsgType.INFO,
				)
				get_viewport().set_input_as_handled()
		elif event.is_action("target_self"):
			if _self_targeted:
				_clear_self_target()
			else:
				Combat.set_target(null)
				_show_self_target()
		elif event.is_action("toggle_character"):
			character_window.visible = !character_window.visible
		elif event.is_action("toggle_inventory"):
			inventory_window.visible = !inventory_window.visible
		elif event.is_action("toggle_paperdoll"):
			paperdoll_window.visible = !paperdoll_window.visible
		elif event.is_action("toggle_crafting"):
			_crafting_window.visible = !_crafting_window.visible
		elif event.is_action("toggle_spell_book"):
			if _spell_book != null:
				_spell_book.visible = !_spell_book.visible
		elif event.is_action("toggle_quest_journal"):
			if _quest_journal != null:
				_quest_journal.visible = !_quest_journal.visible
		elif event.is_action("toggle_auto_attack"):
			Combat.toggle_auto_attack()
		elif event.is_action("interact"):
			if _try_open_targeted_npc():
				pass
			elif StationManager.nearby_station != "":
				_crafting_window.visible = true
			elif _try_loot_nearby():
				pass
			elif not _try_mine_nearby():
				_try_skin_nearby()

func _try_open_targeted_npc() -> bool:
	var t = Combat.current_target
	if t == null or not is_instance_valid(t):
		return false
	var is_friendly: bool = t.is_in_group("dialogue_npcs") or t.is_in_group("vendor_npcs") or t.is_in_group("banker_npcs")
	if not is_friendly:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	const NPC_INTERACT_RANGE := 6.0
	if t.global_position.distance_to(player.global_position) > NPC_INTERACT_RANGE:
		CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
		return true
	if t.is_in_group("dialogue_npcs"):
		DialogueManager.open_for(t)
	elif t.is_in_group("banker_npcs"):
		BankerManager.open_for(t)
	else:
		VendorManager.open_for(t)
	return true

func _try_loot_nearby() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	const LOOT_RANGE := 6.0
	for node in get_tree().get_nodes_in_group("loot_bags"):
		var bag := node as LootBag
		if bag == null or not is_instance_valid(bag):
			continue
		if bag.global_position.distance_to(player.global_position) <= LOOT_RANGE:
			Loot.show_window(bag)
			return true
	return false

func _try_mine_nearby() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	const MINE_RANGE := 3.0
	for node in get_tree().get_nodes_in_group("mining_nodes"):
		var mn := node as MiningNode
		if mn == null:
			continue
		if mn.global_position.distance_to(player.global_position) > MINE_RANGE:
			continue
		var msg := mn.try_mine()
		CombatLog.add_line(msg, CombatLog.MsgType.INFO)
		return true
	return false

func _try_skin_nearby() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	const SKIN_RANGE := 3.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_skinnable:
			continue
		if enemy.global_position.distance_to(player.global_position) > SKIN_RANGE:
			continue
		var msg := enemy.try_skin()
		CombatLog.add_line(msg, CombatLog.MsgType.INFO)
		return

func _on_window_visibility_changed(window: Panel) -> void:
	if window.visible:
		_window_stack.erase(window)
		_window_stack.append(window)
	else:
		_window_stack.erase(window)

# ── Styling helpers ───────────────────────────────────────────────────────────

func _style_panel() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.05, 0.03, 0.92)
	s.border_color = UITheme.C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	$Panel.add_theme_stylebox_override("panel", s)

# ── Stat bar callbacks ────────────────────────────────────────────────────────

func _on_hp_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	if _hp_label:
		_hp_label.text = "%d / %d" % [int(current), int(maximum)]
	# Track 21B — ToT mirrors PlayerStats only when it's rendering
	# the local player (self-target case: tracked enemy is hitting
	# you). When ToT is bound to a remote entity, that entity's
	# hp_changed feeds the bar via _on_tot_entity_hp_changed.
	if _tot_frame != null and _tot_frame.visible and _tot_entity == null:
		_tot_hp_bar.max_value = maximum
		_tot_hp_bar.value = current
		if _tot_hp_label:
			_tot_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_mp_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	if _mp_label:
		_mp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	if _sta_label:
		_sta_label.text = "%d / %d" % [int(current), int(maximum)]

# ── Target frame ──────────────────────────────────────────────────────────────

func _on_stat_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _self_targeted:
			_clear_self_target()
		else:
			Combat.set_target(null)
			_show_self_target()

func _show_self_target() -> void:
	_self_targeted = true
	if is_instance_valid(_tracked_target):
		if _tracked_target.is_connected("hp_changed", _on_target_hp_changed):
			_tracked_target.hp_changed.disconnect(_on_target_hp_changed)
		if _tracked_target.is_connected("died", _on_target_enemy_died):
			_tracked_target.died.disconnect(_on_target_enemy_died)
	_tracked_target = null
	var pname := PlayerStats.player_name if PlayerStats.player_name != "" else "You"
	target_name_label.text = pname
	target_level_label.text = "Level %d" % PlayerStats.level
	target_hp_bar.max_value = PlayerStats.max_hp
	target_hp_bar.value = PlayerStats.hp
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(PlayerStats.hp), int(PlayerStats.max_hp)]
		_target_hp_label.visible = true
	target_frame.visible = true
	target_hp_bar.visible = true
	if not PlayerStats.is_connected("hp_changed", _on_self_target_hp_changed):
		PlayerStats.hp_changed.connect(_on_self_target_hp_changed)
	if _tot_frame != null:
		_tot_frame.visible = false

func _clear_self_target() -> void:
	_self_targeted = false
	if PlayerStats.is_connected("hp_changed", _on_self_target_hp_changed):
		PlayerStats.hp_changed.disconnect(_on_self_target_hp_changed)
	target_frame.visible = false
	if _target_hp_label:
		_target_hp_label.visible = false

func _on_self_target_hp_changed(current: float, maximum: float) -> void:
	target_hp_bar.max_value = maximum
	target_hp_bar.value = current
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_target_changed(enemy) -> void:
	if _self_targeted:
		_clear_self_target()
	if is_instance_valid(_tracked_target):
		if _tracked_target.is_connected("hp_changed", _on_target_hp_changed):
			_tracked_target.hp_changed.disconnect(_on_target_hp_changed)
		if _tracked_target.is_connected("mp_changed", _on_target_mp_changed):
			_tracked_target.mp_changed.disconnect(_on_target_mp_changed)
		if _tracked_target.is_connected("stamina_changed", _on_target_stamina_changed):
			_tracked_target.stamina_changed.disconnect(_on_target_stamina_changed)
		if _tracked_target.has_signal("cast_started") and _tracked_target.is_connected("cast_started", _on_target_cast_started):
			_tracked_target.cast_started.disconnect(_on_target_cast_started)
		if _tracked_target.has_signal("cast_ended") and _tracked_target.is_connected("cast_ended", _on_target_cast_ended):
			_tracked_target.cast_ended.disconnect(_on_target_cast_ended)
		if _tracked_target.has_signal("buffs_changed") and _tracked_target.is_connected("buffs_changed", _on_target_buffs_changed):
			_tracked_target.buffs_changed.disconnect(_on_target_buffs_changed)
		if _tracked_target.has_signal("died") and _tracked_target.is_connected("died", _on_target_enemy_died):
			_tracked_target.died.disconnect(_on_target_enemy_died)
		# Track 21B — drop the RemoteEnemy target_changed sub so the
		# old target's targeting doesn't bleed into ToT after retarget.
		if _tracked_target.has_signal("target_changed") and _tracked_target.is_connected("target_changed", _on_tracked_target_target_changed):
			_tracked_target.target_changed.disconnect(_on_tracked_target_target_changed)
	# Track 21B — also drop any binding to the previous target-of-
	# target entity. _refresh_tot will rebuild + rebind below.
	_clear_tot_entity_binding()
	_tracked_target = enemy
	# MP/Stamina/Cast/Buffs are peer-only; hide on every transition and
	# re-show in the remote-player branch below if applicable.
	target_mp_bar.visible = false
	target_st_bar.visible = false
	target_cast_bar.visible = false
	target_cast_label.visible = false
	target_buffs_label.visible = false
	if _target_buff_icons != null and is_instance_valid(_target_buff_icons):
		_target_buff_icons.visible = false
	if _target_mp_label:
		_target_mp_label.visible = false
	if _target_st_label:
		_target_st_label.visible = false
	if enemy == null or not is_instance_valid(enemy):
		target_frame.visible = false
		target_hp_bar.visible = true
		if _target_hp_label:
			_target_hp_label.visible = false
		if _tot_frame != null:
			_tot_frame.visible = false
		return
	target_frame.visible = true
	if enemy is Corpse:
		# Slice 3 — a corpse can be targeted (a Cleric/Paladin resurrects it).
		# No hp bar; just the "<owner>'s corpse" name (skip the friendly-NPC
		# branch below, which would throw on the missing npc_name field).
		target_name_label.text = "%s's corpse" % enemy.owner_name
		target_level_label.text = ""
		target_hp_bar.visible = false
		if _target_hp_label:
			_target_hp_label.visible = false
		if _tot_frame != null:
			_tot_frame.visible = false
		return
	if enemy.is_in_group("remote_players"):
		_setup_peer_target(enemy)
		return
	if enemy.is_in_group("pets") or enemy.is_in_group("remote_pets"):
		# Pet target frame — render like enemies (HP bar + level)
		# but key off pet_name. Subscribe to hp_changed + died so
		# the bar tracks regen / damage / dismissal.
		var pname: String = enemy.pet_name if "pet_name" in enemy else "Pet"
		var plvl: int = enemy.level if "level" in enemy else 1
		target_name_label.text = pname
		target_level_label.text = "Level %d" % plvl
		target_hp_bar.visible = true
		target_hp_bar.max_value = enemy.max_hp
		target_hp_bar.value = enemy.hp
		if _target_hp_label:
			_target_hp_label.text = "%d / %d" % [int(enemy.hp), int(enemy.max_hp)]
			_target_hp_label.visible = true
		if enemy.has_signal("hp_changed"):
			enemy.hp_changed.connect(_on_target_hp_changed)
		if enemy.has_signal("died"):
			enemy.died.connect(_on_target_enemy_died)
		# Track 13 — pets carry a buff snapshot now; render it in the
		# target frame like a peer's (RemotePet mirrors the buff surface).
		if enemy.has_signal("buffs_changed"):
			enemy.buffs_changed.connect(_on_target_buffs_changed)
		_refresh_target_buffs_label()
		return
	if not enemy.is_in_group("enemies"):
		# Friendly NPC target frame. Each NPC type exposes its own name/subtitle
		# fields (vendor_name/_type, banker_name, npc_name/_title) — resolve by
		# group rather than assuming one shape, or a wrong .field access throws
		# and the frame keeps the previous target's name.
		var nm := ""
		var subtitle := ""
		if enemy.is_in_group("vendor_npcs"):
			nm = enemy.vendor_name
			subtitle = enemy.vendor_type
		elif enemy.is_in_group("banker_npcs"):
			nm = enemy.banker_name
			subtitle = "Banker"
		else:
			nm = enemy.npc_name
			subtitle = enemy.npc_title
		target_name_label.text = nm
		target_level_label.text = subtitle
		target_hp_bar.visible = false
		if _target_hp_label:
			_target_hp_label.visible = false
		if _tot_frame != null:
			_tot_frame.visible = false
		return
	target_hp_bar.visible = true
	target_name_label.text = enemy.mob_name
	target_level_label.text = "Level %d" % enemy.level
	target_hp_bar.max_value = enemy.max_hp
	target_hp_bar.value = enemy.hp
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(enemy.hp), int(enemy.max_hp)]
		_target_hp_label.visible = true
	enemy.hp_changed.connect(_on_target_hp_changed)
	enemy.died.connect(_on_target_enemy_died)
	# Track 21B — RemoteEnemy fires target_changed when the server's
	# EntityTarget broadcast lands; subscribe so the ToT frame
	# follows the tracked enemy's target across the fight (e.g. an
	# enemy switching from the tank to the healer).
	if enemy.has_signal("target_changed"):
		enemy.target_changed.connect(_on_tracked_target_target_changed)
	_refresh_tot()

# Targeting a remote player. Resources are server-replicated via Track 4
# ResourceUpdate fan-out and cached on the RemotePlayer node; we read the
# current values now and subscribe to its hp/mp/stamina signals so the bars
# tick as fresh broadcasts arrive.
func _setup_peer_target(peer) -> void:
	target_name_label.text = peer.mob_name
	# Per design: peer level isn't surfaced in the target frame. Class /
	# race subtitle could land here later; left empty for now.
	target_level_label.text = ""
	target_hp_bar.visible = true
	target_hp_bar.max_value = maxf(peer.max_hp, 1.0)
	target_hp_bar.value = peer.hp
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(peer.hp), int(peer.max_hp)]
		_target_hp_label.visible = true
	target_mp_bar.visible = true
	target_mp_bar.max_value = maxf(peer.max_mp, 1.0)
	target_mp_bar.value = peer.mp
	if _target_mp_label:
		_target_mp_label.text = "%d / %d" % [int(peer.mp), int(peer.max_mp)]
		_target_mp_label.visible = true
	target_st_bar.visible = true
	target_st_bar.max_value = maxf(peer.max_stamina, 1.0)
	target_st_bar.value = peer.stamina
	if _target_st_label:
		_target_st_label.text = "%d / %d" % [int(peer.stamina), int(peer.max_stamina)]
		_target_st_label.visible = true
	peer.hp_changed.connect(_on_target_hp_changed)
	peer.mp_changed.connect(_on_target_mp_changed)
	peer.stamina_changed.connect(_on_target_stamina_changed)
	peer.cast_started.connect(_on_target_cast_started)
	peer.cast_ended.connect(_on_target_cast_ended)
	peer.buffs_changed.connect(_on_target_buffs_changed)
	# Pick up an in-progress cast at target-time (peer may have been
	# casting before we targeted them; the bar should appear immediately).
	if peer.is_casting():
		_show_target_cast_bar(peer.cast_spell_name)
	_refresh_target_buffs_label()
	# Track 22.H — RemotePlayer now broadcasts target_changed when
	# the server's EntityTarget for them lands. Subscribe + refresh
	# so the ToT frame shows what tracked peers are attacking.
	if peer.has_signal("target_changed"):
		peer.target_changed.connect(_on_tracked_target_target_changed)
	_refresh_tot()

func _on_target_mp_changed(current: float, maximum: float) -> void:
	target_mp_bar.max_value = maxf(maximum, 1.0)
	target_mp_bar.value = current
	if _target_mp_label:
		_target_mp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_target_stamina_changed(current: float, maximum: float) -> void:
	target_st_bar.max_value = maxf(maximum, 1.0)
	target_st_bar.value = current
	if _target_st_label:
		_target_st_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_target_cast_started(spell_name: String, _duration: float) -> void:
	_show_target_cast_bar(spell_name)

func _on_target_cast_ended() -> void:
	target_cast_bar.visible = false
	target_cast_label.visible = false

func _show_target_cast_bar(spell_name: String) -> void:
	target_cast_bar.visible = true
	target_cast_bar.value = 0.0
	target_cast_label.text = spell_name
	target_cast_label.visible = true

func _on_target_buffs_changed() -> void:
	_refresh_target_buffs_label()

# Render the target's buffs as a small icon row (wrapping HFlowContainer)
# — the same colored-border panel style as the main buff bar, scaled down
# to fit the target frame. Works for any target exposing the buff snapshot
# surface (peer or pet).
func _refresh_target_buffs_label() -> void:
	var container := _ensure_target_buff_container()
	for child in container.get_children():
		child.queue_free()
	if not is_instance_valid(_tracked_target) or not _tracked_target.has_method("apply_buff_snapshot"):
		container.visible = false
		return
	var names: PackedStringArray = _tracked_target.buff_names
	var durations: PackedFloat32Array = _tracked_target.buff_durations
	if names.is_empty():
		container.visible = false
		return
	for i in names.size():
		var d: float = durations[i] if i < durations.size() else 0.0
		container.add_child(_make_target_buff_icon(names[i], d))
	container.visible = true

# Lazily create the icon row under the (now-hidden) BuffsLabel's parent so
# it lives inside the target frame's VBox and scales with the HUD layout.
func _ensure_target_buff_container() -> HFlowContainer:
	if _target_buff_icons != null and is_instance_valid(_target_buff_icons):
		return _target_buff_icons
	target_buffs_label.visible = false
	_target_buff_icons = HFlowContainer.new()
	_target_buff_icons.add_theme_constant_override("h_separation", 2)
	_target_buff_icons.add_theme_constant_override("v_separation", 2)
	var parent := target_buffs_label.get_parent()
	parent.add_child(_target_buff_icons)
	parent.move_child(_target_buff_icons, target_buffs_label.get_index() + 1)
	return _target_buff_icons

func _buff_icon_color(buff_name: String) -> Color:
	return _TARGET_BUFF_COLORS.get(buff_name, Color(0.45, 0.65, 0.45))

# Short label that fits a 30px icon AND stays distinguishable. Multi-word
# buffs become initials of their significant words ("Spirit of the Bear" →
# "SB", "Spirit of Wolf" → "SW") so similar names don't collapse to the
# same 4-char prefix; single-word buffs use their first 4 characters. The
# full name is on the icon's tooltip.
func _buff_abbrev(buff_name: String) -> String:
	var base := buff_name
	var rk := base.find(" Rk.")
	if rk != -1:
		base = base.substr(0, rk)
	var significant: Array = []
	for w in base.split(" ", false):
		if (w as String).to_lower() in ["of", "the", "a", "an"]:
			continue
		significant.append(w)
	if significant.size() >= 2:
		var s := ""
		for w in significant:
			s += (w as String).substr(0, 1).to_upper()
		return s
	return base.left(4)

# A 30×30 dark panel with a colored border + truncated name and (if timed)
# a countdown — the target-frame-scale twin of hud_buff_bar's _add_icon.
func _make_target_buff_icon(buff_name: String, remaining: float) -> Panel:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = buff_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	style.border_color = _buff_icon_color(buff_name)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	icon.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = _buff_abbrev(buff_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 7)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	# Timed buffs get a countdown; infinite-duration sentinels (Lich) show
	# just the icon.
	if remaining > 0.0 and remaining < 99999.0:
		var t_lbl := Label.new()
		t_lbl.text = "%ds" % int(ceil(remaining))
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 8)
		t_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(t_lbl)
	return icon

func _on_target_hp_changed(current: float, maximum: float) -> void:
	target_hp_bar.max_value = maximum
	target_hp_bar.value = current
	if _target_hp_label:
		_target_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_target_enemy_died(_enemy) -> void:
	_tracked_target = null
	target_frame.visible = false
	# Track 21B — also drop the ToT binding so the next target's
	# ToT doesn't carry a stale hp_changed subscription from the
	# previous one.
	_clear_tot_entity_binding()
	if _tot_frame != null:
		_tot_frame.visible = false

# Track 21B — resolves "what is my target currently targeting?" and
# renders it in the ToT frame.
#
# Source of truth varies by tracked-target kind:
#   - RemoteEnemy: server-sent `target_id` field (driven by EntityTarget
#     broadcasts). Resolved through the id partition to a RemotePlayer
#     / RemoteEnemy / RemotePet / local player.
#   - Local Enemy (solo / Test Room): the legacy local AI always
#     chases the player when aggro'd, so we show "You" iff the enemy
#     is in CHASE / ATTACK. Hidden in IDLE / LEASH / FLEE / DEAD.
#   - Other tracked kinds (peer player, vendor, pet target frame
#     usage, etc.): hidden — server doesn't broadcast peer→peer
#     targeting yet.
func _refresh_tot() -> void:
	if _tot_frame == null:
		_clear_tot_entity_binding()
		return
	if _tracked_target == null or not is_instance_valid(_tracked_target):
		_clear_tot_entity_binding()
		_tot_frame.visible = false
		return

	var tot_id: int = _resolve_tracked_target_target_id()
	if tot_id == 0:
		_clear_tot_entity_binding()
		_tot_frame.visible = false
		return

	# Self-target sentinel: tracked target is hitting the local player.
	# PlayerStats is the source; we keep _tot_entity = null and let the
	# existing _on_hp_changed handler tick the bar.
	var own_id: int = Net.get_player_id() if Net.get_player_id() > 0 else -1
	if tot_id == own_id or tot_id == -1:
		_clear_tot_entity_binding()
		var pname := PlayerStats.player_name if PlayerStats.player_name != "" else "You"
		_tot_name_label.text = pname
		_tot_hp_bar.max_value = maxf(PlayerStats.max_hp, 1.0)
		_tot_hp_bar.value = PlayerStats.hp
		if _tot_hp_label:
			_tot_hp_label.text = "%d / %d" % [int(PlayerStats.hp), int(PlayerStats.max_hp)]
		_tot_frame.visible = true
		return

	# Otherwise resolve to a remote entity by id partition. If the
	# entity isn't visible yet (AOI gap, despawn race), hide the
	# frame until the next refresh.
	var entity: Node = _resolve_remote_entity(tot_id)
	if entity == null or not is_instance_valid(entity):
		_clear_tot_entity_binding()
		_tot_frame.visible = false
		return

	_bind_tot_entity(entity)
	_render_tot_entity()

func _resolve_tracked_target_target_id() -> int:
	# RemoteEnemy / RemotePlayer both carry an authoritative
	# target_id from the server's EntityTarget broadcasts (Track 21B
	# for enemies, Track 22.H for peers). Same field name on both.
	if (_tracked_target.is_in_group("remote_enemies")
			or _tracked_target.is_in_group("remote_players")) \
			and "target_id" in _tracked_target:
		return int(_tracked_target.target_id)
	# Local Enemy: solo / Test Room only. Approximate via state — the
	# stock enemy AI in enemy.gd always chases the local player.
	if _tracked_target.is_in_group("enemies") and "state" in _tracked_target:
		var s: int = _tracked_target.state
		# Enemy.State.CHASE = 1, Enemy.State.ATTACK = 2. Use literals
		# rather than the enum reference so a future enum reorder is
		# caught here.
		if s == 1 or s == 2:
			return -1  # sentinel: local player
	return 0

func _resolve_remote_entity(id: int) -> Node:
	if id <= 0:
		return null
	const _ENEMY_BASE: int = 1_000_000_000
	const _LOOT_BAG_BASE: int = 2_000_000_000
	const _PET_BASE: int = 3_000_000_000
	if id >= _PET_BASE:
		return RemotePetManager.get_by_id(id)
	if id >= _LOOT_BAG_BASE:
		return null  # bags aren't combat targets
	if id >= _ENEMY_BASE:
		return RemoteEnemyManager.get_by_id(id)
	# Player char_ids land below ENEMY_ID_BASE.
	return RemotePlayerManager.get_by_id(id)

func _bind_tot_entity(entity: Node) -> void:
	if _tot_entity == entity:
		return
	_clear_tot_entity_binding()
	_tot_entity = entity
	if entity.has_signal("hp_changed"):
		entity.hp_changed.connect(_on_tot_entity_hp_changed)
	if entity.has_signal("died"):
		entity.died.connect(_on_tot_entity_died)

func _clear_tot_entity_binding() -> void:
	if not is_instance_valid(_tot_entity):
		_tot_entity = null
		return
	if _tot_entity.has_signal("hp_changed") and _tot_entity.is_connected("hp_changed", _on_tot_entity_hp_changed):
		_tot_entity.hp_changed.disconnect(_on_tot_entity_hp_changed)
	if _tot_entity.has_signal("died") and _tot_entity.is_connected("died", _on_tot_entity_died):
		_tot_entity.died.disconnect(_on_tot_entity_died)
	_tot_entity = null

func _render_tot_entity() -> void:
	if not is_instance_valid(_tot_entity):
		return
	var nm := "Unknown"
	if "mob_name" in _tot_entity and _tot_entity.mob_name != "":
		nm = _tot_entity.mob_name
	elif "pet_name" in _tot_entity:
		nm = _tot_entity.pet_name
	var hp: float = _tot_entity.hp if "hp" in _tot_entity else 0.0
	var max_hp: float = _tot_entity.max_hp if "max_hp" in _tot_entity else 1.0
	_tot_name_label.text = nm
	_tot_hp_bar.max_value = maxf(max_hp, 1.0)
	_tot_hp_bar.value = hp
	if _tot_hp_label:
		_tot_hp_label.text = "%d / %d" % [int(hp), int(max_hp)]
	_tot_frame.visible = true

func _on_tot_entity_hp_changed(current: float, maximum: float) -> void:
	_tot_hp_bar.max_value = maxf(maximum, 1.0)
	_tot_hp_bar.value = current
	if _tot_hp_label:
		_tot_hp_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_tot_entity_died(_who) -> void:
	_clear_tot_entity_binding()
	if _tot_frame != null:
		_tot_frame.visible = false

func _on_tracked_target_target_changed(_target_id: int) -> void:
	# RemoteEnemy fired its target_changed signal. Re-resolve.
	_refresh_tot()

# ── Player state ──────────────────────────────────────────────────────────────

func _on_player_state_changed(new_state: int) -> void:
	if _state_label == null:
		return
	if new_state == PlayerCharacter.PlayerState.SITTING:
		_state_label.text = "Resting / Meditating"
		_state_label.visible = true
	else:
		_state_label.visible = false

# ── Command input ─────────────────────────────────────────────────────────────

func _handle_chat_input(text: String) -> void:
	var my_name := PlayerStats.player_name if PlayerStats.player_name != "" else "You"

	if not text.begins_with("/"):
		CombatLog.add_line("%s says, '%s'" % [my_name, text], CombatLog.MsgType.SAY)
		return

	var lower := text.to_lower()

	if lower == "/sit":
		if is_instance_valid(_player):
			_player.sit()
		return
	if lower == "/stand":
		if is_instance_valid(_player):
			_player.stand()
		return
	# Camp slice B — voluntary sit-gated logout. The server is authoritative on
	# the gate and the countdown; we pre-check sit state locally for a fast
	# rejection line so a standing player never spams the wire. `/camp cancel`
	# aborts an in-progress countdown.
	if lower == "/camp":
		if Combat.is_player_seated():
			Net.broadcast_camp()
		else:
			CombatLog.add_line("You must be sitting to camp.", CombatLog.MsgType.INFO)
		return
	if lower == "/camp cancel":
		Net.broadcast_cancel_camp()
		return
	# Track 22.C — manual dismount. Summon is right-click-the-whistle;
	# this command lets the player step off without using the whistle
	# again or waiting to take a hit.
	if lower == "/dismount":
		MountManager.dismount()
		return
	if lower == "/pet follow":
		PetManager.command_follow()
		return
	if lower == "/pet guard":
		PetManager.command_guard()
		return
	if lower == "/pet passive" or lower == "/pet sit":
		PetManager.command_passive()
		return
	if lower == "/pet dismiss":
		PetManager.dismiss_pet()
		return
	# Track 12 Piece A — direct pet commands. /pet attack uses the
	# current target; /pet back returns to follow.
	if lower == "/pet attack":
		PetManager.command_attack()
		return
	if lower == "/pet back":
		PetManager.command_back()
		return

	for prefix in ["/say ", "/s "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("%s says, '%s'" % [my_name, msg], CombatLog.MsgType.SAY)
			Net.broadcast_chat(Net.CHAT_CHANNEL_SAY, msg)
			return

	for prefix in ["/shout ", "/sh "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("%s shouts, '%s'" % [my_name, msg], CombatLog.MsgType.SHOUT)
			Net.broadcast_chat(Net.CHAT_CHANNEL_SHOUT, msg)
			return

	if lower.begins_with("/ooc "):
		var msg := text.substr("/ooc ".length())
		CombatLog.add_line("[OOC] %s: %s" % [my_name, msg], CombatLog.MsgType.OOC)
		Net.broadcast_chat(Net.CHAT_CHANNEL_OOC, msg)
		return

	for prefix in ["/tell ", "/t "]:
		if lower.begins_with(prefix):
			var rest := text.substr(prefix.length())
			var space_idx := rest.find(" ")
			if space_idx > 0:
				var target_name := rest.substr(0, space_idx)
				var msg := rest.substr(space_idx + 1)
				CombatLog.add_line("You -> %s: %s" % [target_name, msg], CombatLog.MsgType.TELL_OUT)
				Net.broadcast_chat(Net.CHAT_CHANNEL_TELL, msg, target_name)
			else:
				CombatLog.add_line("Usage: /tell <name> <message>", CombatLog.MsgType.INFO)
			return

	for prefix in ["/g ", "/group "]:
		if lower.begins_with(prefix):
			var msg := text.substr(prefix.length())
			CombatLog.add_line("[Group] %s: %s" % [my_name, msg], CombatLog.MsgType.GROUP_CHAT)
			# Server fans this to every other group member via the new
			# Group arm in the chat handler. GroupManager.broadcast_group_chat
			# uses Godot's RPC system which isn't wired in launcher mode
			# (no Godot multiplayer peer); that path was the bug.
			Net.broadcast_chat(Net.CHAT_CHANNEL_GROUP, msg)
			return

	if lower == "/inspect":
		var target = Combat.current_target
		if not is_instance_valid(target) or not (target is RemotePlayer):
			CombatLog.add_line("Target a player to inspect.", CombatLog.MsgType.INFO)
			return
		var rp: RemotePlayer = target
		if rp.char_id < 0:
			CombatLog.add_line("Target has no character id.", CombatLog.MsgType.INFO)
			return
		if _inspect_window != null:
			_inspect_window.open_for(rp.char_id, rp.player_name)
		Net.broadcast_inspect_player(rp.char_id)
		return

	if lower == "/sense" or lower == "/sense heading":
		if is_instance_valid(_player):
			CombatLog.add_line(SenseHeading.query(_player.rotation.y), CombatLog.MsgType.INFO)
		return

	if lower == "/track":
		if _track_window != null:
			_track_window.toggle()
		return

	if lower == "/languages":
		var known: Array = []
		for lang in Languages.skills:
			if Languages.skills[lang] > 0:
				known.append(lang)
		if known.is_empty():
			CombatLog.add_line("You know no languages.", CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("Known languages:", CombatLog.MsgType.INFO)
			for lang in known:
				var active_marker := " (active)" if lang == Languages.active_language else ""
				CombatLog.add_line("  %s — %d%s" % [lang, Languages.skills[lang], active_marker], CombatLog.MsgType.INFO)
		return

	if lower.begins_with("/lang "):
		var lang_name := text.substr(6).strip_edges()
		if lang_name == "":
			CombatLog.add_line("Usage: /lang [language name]", CombatLog.MsgType.INFO)
		elif Languages.get_skill(lang_name) > 0:
			Languages.set_active_language(lang_name)
			CombatLog.add_line("You are now speaking %s." % lang_name, CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("You do not know the language '%s'." % lang_name, CombatLog.MsgType.INFO)
		return

	# Dev command — drop any ItemRegistry-known item into inventory.
	# Syntax: `/give <substring> [count]`. Empty query lists nothing
	# (the registry has ~100 entries; a dedicated /items command can
	# dump them later). Ambiguous query lists candidates and bails
	# without giving so the dev can refine. Single-match → gives.
	# Inventory authority is client-only today; when it goes server
	# side, this should gate on `accounts.is_gm`.
	if lower.begins_with("/give "):
		var rest := text.substr("/give ".length()).strip_edges()
		if rest == "":
			CombatLog.add_line("Usage: /give <item name> [count]", CombatLog.MsgType.INFO)
			return
		var count := 1
		# Optional trailing integer = stack count. Walks back from the
		# end so multi-word names with spaces still parse cleanly
		# ("/give iron short sword 3" → name="iron short sword", count=3).
		var tokens := rest.split(" ", false)
		if tokens.size() > 1 and tokens[tokens.size() - 1].is_valid_int():
			count = int(tokens[tokens.size() - 1])
			tokens.remove_at(tokens.size() - 1)
			rest = " ".join(tokens)
		var matches := ItemRegistry.find_matches(rest, 10)
		if matches.is_empty():
			CombatLog.add_line("No items match '%s'." % rest, CombatLog.MsgType.INFO)
			return
		if matches.size() > 1:
			CombatLog.add_line("Multiple matches for '%s':" % rest, CombatLog.MsgType.INFO)
			for m: ItemData in matches:
				CombatLog.add_line("  • %s" % m.item_name, CombatLog.MsgType.INFO)
			CombatLog.add_line("Refine your search.", CombatLog.MsgType.INFO)
			return
		var item_name := (matches[0] as ItemData).item_name
		# Track 15.2 follow-up — launcher mode routes /give through
		# the wire so the spawned item exists server-side. The server
		# fans InventoryDelta which Inventory autoload applies. Solo /
		# Test Room keeps the legacy local ItemRegistry.give_by_name.
		if Net.is_launcher_mode():
			Net.broadcast_gm_command("give %s %d" % [item_name, count])
			var suffix := " x%d" % count if count > 1 else ""
			CombatLog.add_line("Requested %s%s from server." % [item_name, suffix], CombatLog.MsgType.INFO)
			return
		if ItemRegistry.give_by_name(item_name, count):
			var suffix := " x%d" % count if count > 1 else ""
			CombatLog.add_line("Spawned %s%s." % [item_name, suffix], CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("Couldn't spawn %s (inventory full?)." % item_name, CombatLog.MsgType.INFO)
		return

	# Track 6 sub-task 3 dev — toggle PvP authorization on this client.
	# Both attacker and target need /pvp on for combat::can_attack to
	# allow damage. Used to verify the PvP HP application path before
	# the duel / PvP-zone / PvP-server design lands.
	if lower == "/pvp" or lower == "/pvp on" or lower == "/pvp off":
		var on := lower != "/pvp off"
		Net.broadcast_pvp_toggle(on)
		CombatLog.add_line("PvP override: %s" % ("on" if on else "off"), CombatLog.MsgType.INFO)
		return

	# Per-player loot auto-split. /autosplit off keeps coin you loot for
	# yourself instead of splitting it among the nearby group in Round
	# Robin. See docs/design/group_loot_and_coin.md.
	if lower == "/autosplit" or lower == "/autosplit on" or lower == "/autosplit off":
		var split_on := lower != "/autosplit off"
		Net.broadcast_autosplit(split_on)
		CombatLog.add_line("Auto-split loot: %s" % ("on" if split_on else "off"), CombatLog.MsgType.INFO)
		return

	# Group loot distribution mode (leader only). Bare /loot reports the
	# current mode; /loot rr | ffa sets it. See group_loot_and_coin.md.
	if lower.begins_with("/loot"):
		if lower == "/loot":
			CombatLog.add_line("Loot mode: %s. Leader: /loot rr or /loot ffa." % GroupManager.loot_mode_name(), CombatLog.MsgType.INFO)
			return
		if lower == "/loot rr" or lower == "/loot roundrobin" or lower == "/loot ffa" or lower == "/loot freeforall":
			if not GroupManager.is_leader:
				CombatLog.add_line("Only the group leader can set the loot mode.", CombatLog.MsgType.INFO)
				return
			var ffa := lower == "/loot ffa" or lower == "/loot freeforall"
			var mode := GroupManager.LOOT_FREE_FOR_ALL if ffa else GroupManager.LOOT_ROUND_ROBIN
			GroupManager.set_loot_mode(mode)
			CombatLog.add_line("Loot mode set to %s." % ("Free-for-all" if ffa else "Round Robin"), CombatLog.MsgType.INFO)
			return

	# Dev-only — backup trigger for the in-game debug console when the
	# F2 keybind isn't reaching the game window (editor focus, OS
	# steals, etc.). Round-7B fallback.
	if lower == "/console":
		if _debug_console != null:
			_debug_console.toggle()
			CombatLog.add_line(
				"Debug console: %s (%d lines buffered)" % [
					"ON" if _debug_console.visible else "OFF",
					DebugLog.recent_lines.size(),
				],
				CombatLog.MsgType.INFO,
			)
		return

	# Track 6 sub-task 3 dev — bypass-the-spell-system self damage.
	# Routes through the same server damage path PvP and (future) spells
	# use, exercising regen + death detection end-to-end. Replaced by
	# proper CastSpell handling once the spell table is server-side.
	if lower.begins_with("/damage "):
		var arg := text.substr("/damage ".length()).strip_edges()
		if not arg.is_valid_int():
			CombatLog.add_line("Usage: /damage <amount>", CombatLog.MsgType.INFO)
			return
		Net.broadcast_damage_self(int(arg))
		CombatLog.add_line("Dev damage self: %s" % arg, CombatLog.MsgType.INFO)
		return

	# Track 6 sub-task 5 — group commands (launcher mode). Test Room
	# single-player can't form groups via these — invites need a real
	# peer over renet.
	if lower == "/invite" or lower.begins_with("/invite "):
		var target_name := ""
		if lower.begins_with("/invite "):
			target_name = text.substr("/invite ".length()).strip_edges()
		# No name given → fall back to the currently-targeted RemotePlayer.
		if target_name == "":
			var target = Combat.current_target
			if is_instance_valid(target) and target is RemotePlayer:
				target_name = target.player_name
		if target_name == "":
			CombatLog.add_line("Usage: /invite <character name> — or target a player first.", CombatLog.MsgType.INFO)
			return
		if Net.is_launcher_mode():
			GroupManager.invite_player_by_name(target_name)
			CombatLog.add_line("Invited %s to your group." % target_name, CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("/invite requires multiplayer.", CombatLog.MsgType.INFO)
		return

	if lower == "/accept" or lower == "/accept invite":
		if GroupManager.pending_invite_from == 0:
			CombatLog.add_line("No pending group invite.", CombatLog.MsgType.INFO)
			return
		GroupManager.accept_invite()
		CombatLog.add_line("Accepted the group invite.", CombatLog.MsgType.INFO)
		return

	if lower == "/leave" or lower == "/leave group":
		if not GroupManager.in_group:
			CombatLog.add_line("You aren't in a group.", CombatLog.MsgType.INFO)
			return
		GroupManager.leave_group()
		CombatLog.add_line("You left the group.", CombatLog.MsgType.INFO)
		return

	if lower.begins_with("/kick "):
		var target_name := text.substr("/kick ".length()).strip_edges()
		if target_name == "":
			CombatLog.add_line("Usage: /kick <character name>", CombatLog.MsgType.INFO)
			return
		if not GroupManager.is_leader:
			CombatLog.add_line("Only the group leader can kick.", CombatLog.MsgType.INFO)
			return
		if Net.is_launcher_mode():
			GroupManager.kick_member_by_name(target_name)
			CombatLog.add_line("Kicked %s from the group." % target_name, CombatLog.MsgType.INFO)
		else:
			CombatLog.add_line("/kick requires multiplayer.", CombatLog.MsgType.INFO)
		return

	# Track 6 sub-task 3 dev — bypass-the-spell-system self heal.
	# Verifies that server-applied heals stick (the regression we noted
	# during sub-task 1 verification) before the CastSpell port lands.
	if lower.begins_with("/heal "):
		var arg := text.substr("/heal ".length()).strip_edges()
		if not arg.is_valid_int():
			CombatLog.add_line("Usage: /heal <amount>", CombatLog.MsgType.INFO)
			return
		Net.broadcast_heal_self(int(arg))
		CombatLog.add_line("Dev heal self: %s" % arg, CombatLog.MsgType.INFO)
		return

	# Dev command — list items whose name matches a substring without
	# spawning. Pairs with /give for discoverability without flooding
	# the inventory.
	if lower.begins_with("/items"):
		var rest := text.substr("/items".length()).strip_edges()
		if rest == "":
			CombatLog.add_line("Usage: /items <substring> (registry has %d items)" % ItemRegistry.count(), CombatLog.MsgType.INFO)
			return
		var matches := ItemRegistry.find_matches(rest, 30)
		if matches.is_empty():
			CombatLog.add_line("No items match '%s'." % rest, CombatLog.MsgType.INFO)
			return
		CombatLog.add_line("Items matching '%s' (%d):" % [rest, matches.size()], CombatLog.MsgType.INFO)
		for m: ItemData in matches:
			CombatLog.add_line("  • %s" % m.item_name, CombatLog.MsgType.INFO)
		return

	CombatLog.add_line("Unknown command: %s" % text, CombatLog.MsgType.INFO)
