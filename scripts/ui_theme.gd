class_name UITheme

# Shared color palette used across all UI windows and the character creation screen.
# Reference these constants instead of hardcoding colors in individual scripts.

# Common window chrome
const C_BORDER       := Color(0.30, 0.22, 0.08)
const C_GOLDEN_BORDER := Color(0.55, 0.40, 0.10)  # loot window, confirm button
const C_TITLE        := Color(0.95, 0.78, 0.25)
const C_TEXT         := Color(0.90, 0.82, 0.65)

# Panel backgrounds (vary slightly by window type)
const C_WINDOW_BG  := Color(0.07, 0.06, 0.04, 0.95)  # inventory, paperdoll, loot
const C_SCREEN_BG  := Color(0.04, 0.03, 0.02)          # character creation full-screen
const C_PANEL_BG   := Color(0.10, 0.08, 0.06)          # raised section panels

# Slot cells (inventory grid, equipment frames)
const C_SLOT_BG := Color(0.12, 0.10, 0.07)

# Tooltip / overlay
const C_TOOLTIP := Color(0.04, 0.03, 0.02, 0.95)

# Character creation — selection states
const C_SELECTED  := Color(0.60, 0.44, 0.12)
const C_BTN_NORM  := Color(0.14, 0.11, 0.07)
const C_BTN_HOVER := Color(0.22, 0.17, 0.09)

# Character creation — locked (unavailable) race/class buttons
const C_BTN_LOCKED_BG     := Color(0.07, 0.05, 0.04)
const C_BTN_LOCKED_BORDER := Color(0.22, 0.12, 0.10)
const C_BTN_LOCKED_TEXT   := Color(0.38, 0.26, 0.22)

# Character creation — "Begin Adventure" confirm button states
const C_CONFIRM_BG          := Color(0.18, 0.12, 0.03)
const C_CONFIRM_BG_HOVER    := Color(0.35, 0.25, 0.07)
const C_CONFIRM_BG_DISABLED := Color(0.10, 0.08, 0.04)
const C_CONFIRM_BORDER_DISABLED := Color(0.25, 0.18, 0.06)

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
	bg.border_color = Color(0.25, 0.18, 0.06, 0.85)
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

static func make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(96.0, 34.0)
	btn.add_theme_stylebox_override("normal",  make_stylebox(C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",   make_stylebox(C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", make_stylebox(C_BTN_HOVER))
	btn.add_theme_color_override("font_color", C_TITLE)
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
