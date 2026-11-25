class_name UITheme

# The UI palette the runtime code colours with (bars, states, rarities, the
# character creation screen). The defaults below are dark wood and brass (the
# direction chosen 2026-11-18); apply_palette(id) swaps them for any palette in
# data/ui_theme_palettes.gd when the player picks another theme in Options,
# Interface. The Theme resources under assets/ui/themes/ carry the same
# palettes into every Control with no override (a Label is the body colour, a
# Button the plate, a window names a variation: WindowPanel, SectionPanel,
# SlotCell, Tooltip, SpeechPanel, BarStrip, TitleLabel, CoinsLabel); they are
# generated from the same table, and tools/check_ui_theme_lockstep.gd keeps
# the files, the table and these defaults in step. Pieces built from these
# values at runtime take a new palette when they are next built.

# The default palette's runtime colours, from the one table.
static var _DEFAULTS: Dictionary = UIThemePalettes.runtime_colors(UIThemePalettes.DEFAULT_ID)

# Brass, three weights, and the body text
static var C_BORDER       : Color = _DEFAULTS["C_BORDER"]  # dim brass: hairlines, slot cells, sections
static var C_GOLDEN_BORDER : Color = _DEFAULTS["C_GOLDEN_BORDER"]  # brass: the band round a window, a lit button
static var C_TITLE        : Color = _DEFAULTS["C_TITLE"]  # bright brass: titles
static var C_TEXT         : Color = _DEFAULTS["C_TEXT"]  # candle amber

# Wood, three depths
static var C_WINDOW_BG  : Color = _DEFAULTS["C_WINDOW_BG"]  # a window's field, deep walnut
static var C_SCREEN_BG  : Color = _DEFAULTS["C_SCREEN_BG"]         # character creation full-screen
static var C_PANEL_BG   : Color = _DEFAULTS["C_PANEL_BG"]         # raised section panels

# Slot cells (inventory grid, equipment frames): oiled dark wood
static var C_SLOT_BG : Color = _DEFAULTS["C_SLOT_BG"]

# Tooltip / overlay
static var C_TOOLTIP : Color = _DEFAULTS["C_TOOLTIP"]

# Buttons (brass plates) and the selected state
static var C_SELECTED  : Color = _DEFAULTS["C_SELECTED"]
static var C_BTN_NORM  : Color = _DEFAULTS["C_BTN_NORM"]
static var C_BTN_HOVER : Color = _DEFAULTS["C_BTN_HOVER"]

# Character creation: locked (unavailable) race/class buttons
static var C_BTN_LOCKED_BG     : Color = _DEFAULTS["C_BTN_LOCKED_BG"]
static var C_BTN_LOCKED_BORDER : Color = _DEFAULTS["C_BTN_LOCKED_BORDER"]
static var C_BTN_LOCKED_TEXT   : Color = _DEFAULTS["C_BTN_LOCKED_TEXT"]

# Character creation: "Begin Adventure" confirm button states
static var C_CONFIRM_BG          : Color = _DEFAULTS["C_CONFIRM_BG"]
static var C_CONFIRM_BG_HOVER    : Color = _DEFAULTS["C_CONFIRM_BG_HOVER"]
static var C_CONFIRM_BG_DISABLED : Color = _DEFAULTS["C_CONFIRM_BG_DISABLED"]
static var C_CONFIRM_BORDER_DISABLED : Color = _DEFAULTS["C_CONFIRM_BORDER_DISABLED"]

# Stat delta colours
const C_POSITIVE := Color(0.40, 0.90, 0.40)
const C_NEGATIVE := Color(0.90, 0.35, 0.35)
static var C_NEUTRAL: Color = _DEFAULTS["C_NEUTRAL"]

# Currency & encumbrance
static var C_COINS: Color = _DEFAULTS["C_COINS"]  # wallet text (vendor + inventory windows)
const C_ENCUMBERED := Color(0.95, 0.85, 0.30)  # weight over capacity — movement slowed
const C_OVERLOADED := Color(0.95, 0.30, 0.25)  # weight ≥ 2× capacity — stamina regen stopped

# Resource bars
const C_BAR_HP      := Color(0.80, 0.10, 0.10)
const C_BAR_STAMINA := Color(0.85, 0.75, 0.00)
const C_BAR_MANA    := Color(0.10, 0.30, 0.90)
const C_BAR_XP      := Color(0.65, 0.50, 0.10)
const C_BAR_BG      := Color(0.08, 0.08, 0.08, 0.90)

# The palette id the defaults above belong to.
static var current_palette: String = UIThemePalettes.DEFAULT_ID

# Take the runtime colours of palette `id` (the Theme resource is applied by
# GameSettings.apply_ui_theme; this is the half the code reads).
static func apply_palette(id: String) -> void:
	var colors := UIThemePalettes.runtime_colors(id)
	current_palette = id if UIThemePalettes.is_known(id) else UIThemePalettes.DEFAULT_ID
	C_BORDER = colors["C_BORDER"]
	C_GOLDEN_BORDER = colors["C_GOLDEN_BORDER"]
	C_TITLE = colors["C_TITLE"]
	C_TEXT = colors["C_TEXT"]
	C_WINDOW_BG = colors["C_WINDOW_BG"]
	C_SCREEN_BG = colors["C_SCREEN_BG"]
	C_PANEL_BG = colors["C_PANEL_BG"]
	C_SLOT_BG = colors["C_SLOT_BG"]
	C_TOOLTIP = colors["C_TOOLTIP"]
	C_SELECTED = colors["C_SELECTED"]
	C_BTN_NORM = colors["C_BTN_NORM"]
	C_BTN_HOVER = colors["C_BTN_HOVER"]
	C_BTN_LOCKED_BG = colors["C_BTN_LOCKED_BG"]
	C_BTN_LOCKED_BORDER = colors["C_BTN_LOCKED_BORDER"]
	C_BTN_LOCKED_TEXT = colors["C_BTN_LOCKED_TEXT"]
	C_CONFIRM_BG = colors["C_CONFIRM_BG"]
	C_CONFIRM_BG_HOVER = colors["C_CONFIRM_BG_HOVER"]
	C_CONFIRM_BG_DISABLED = colors["C_CONFIRM_BG_DISABLED"]
	C_CONFIRM_BORDER_DISABLED = colors["C_CONFIRM_BORDER_DISABLED"]
	C_NEUTRAL = colors["C_NEUTRAL"]
	C_COINS = colors["C_COINS"]

static func style_bar(bar: ProgressBar, color: Color, with_label: bool = true) -> Label:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BAR_BG
	bg.set_corner_radius_all(4)
	bg.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.85)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)
	if not with_label:
		return null
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(lbl)
	return lbl

# A standard button: the theme's brass plate, at the standard size.
static func make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(96.0, 34.0)
	return btn

static func make_stylebox(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_GOLDEN_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	return s

static func set_all_margins(node: MarginContainer, px: int) -> void:
	node.add_theme_constant_override("margin_top",    px)
	node.add_theme_constant_override("margin_left",   px)
	node.add_theme_constant_override("margin_right",  px)
	node.add_theme_constant_override("margin_bottom", px)
