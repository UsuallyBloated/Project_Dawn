class_name UITheme

# The UI palette: dark wood and brass (the direction chosen 2026-11-18). Deep
# walnut fields, brass bands and titles, candle-amber text. The project theme
# (assets/ui/dark_wood_brass.tres, set in project.godot) carries the same
# palette into every Control with no override: a Label is amber, a Button a
# brass plate, and a window names a variation (WindowPanel, SectionPanel,
# SlotCell, Tooltip, TitleLabel) instead of building its own style box. These
# constants are for code that colours things at runtime (bars, states,
# rarities); tools/check_ui_theme_lockstep.gd keeps the two in step.

# Brass, three weights, and the body text
const C_BORDER       := Color(0.50, 0.37, 0.15)  # dim brass: hairlines, slot cells, sections
const C_GOLDEN_BORDER := Color(0.78, 0.60, 0.26)  # brass: the band round a window, a lit button
const C_TITLE        := Color(0.94, 0.78, 0.40)  # bright brass: titles
const C_TEXT         := Color(0.92, 0.84, 0.66)  # candle amber

# Wood, three depths
const C_WINDOW_BG  := Color(0.13, 0.085, 0.05, 0.96)  # a window's field, deep walnut
const C_SCREEN_BG  := Color(0.06, 0.04, 0.025)         # character creation full-screen
const C_PANEL_BG   := Color(0.20, 0.13, 0.075)         # raised section panels

# Slot cells (inventory grid, equipment frames): oiled dark wood
const C_SLOT_BG := Color(0.09, 0.06, 0.035)

# Tooltip / overlay
const C_TOOLTIP := Color(0.10, 0.065, 0.04, 0.97)

# Buttons (brass plates) and the selected state
const C_SELECTED  := Color(0.55, 0.40, 0.16)
const C_BTN_NORM  := Color(0.26, 0.17, 0.09)
const C_BTN_HOVER := Color(0.36, 0.24, 0.12)

# Character creation: locked (unavailable) race/class buttons
const C_BTN_LOCKED_BG     := Color(0.10, 0.07, 0.05)
const C_BTN_LOCKED_BORDER := Color(0.30, 0.16, 0.12)
const C_BTN_LOCKED_TEXT   := Color(0.45, 0.32, 0.26)

# Character creation: "Begin Adventure" confirm button states
const C_CONFIRM_BG          := Color(0.30, 0.20, 0.08)
const C_CONFIRM_BG_HOVER    := Color(0.45, 0.32, 0.12)
const C_CONFIRM_BG_DISABLED := Color(0.14, 0.10, 0.06)
const C_CONFIRM_BORDER_DISABLED := Color(0.32, 0.24, 0.11)

# Stat delta colours
const C_POSITIVE := Color(0.40, 0.90, 0.40)
const C_NEGATIVE := Color(0.90, 0.35, 0.35)
const C_NEUTRAL  := Color(0.75, 0.70, 0.55)

# Currency & encumbrance
const C_COINS      := Color(1.00, 0.88, 0.30)  # wallet text (vendor + inventory windows)
const C_ENCUMBERED := Color(0.95, 0.85, 0.30)  # weight over capacity — movement slowed
const C_OVERLOADED := Color(0.95, 0.30, 0.25)  # weight ≥ 2× capacity — stamina regen stopped

# Resource bars
const C_BAR_HP      := Color(0.80, 0.10, 0.10)
const C_BAR_STAMINA := Color(0.85, 0.75, 0.00)
const C_BAR_MANA    := Color(0.10, 0.30, 0.90)
const C_BAR_XP      := Color(0.65, 0.50, 0.10)
const C_BAR_BG      := Color(0.08, 0.08, 0.08, 0.90)

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
