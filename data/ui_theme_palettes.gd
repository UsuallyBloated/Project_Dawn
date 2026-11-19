class_name UIThemePalettes

# The ten UI palettes (2026-11-18; the user picked dark wood and brass first, then asked
# for the other nine from the list of ten). Each is about sixteen colours plus a corner
# radius and a shadow size; tools/author_ui_themes.gd renders every one into
# assets/ui/themes/<id>.tres through ONE template, and UITheme.apply_palette(id) takes the
# runtime colours from the same table, so the two can never disagree. Structural numbers
# (border widths, content margins) live in the template, never here: one geometry fixture
# holds for all ten.
#
# Keys (every palette has all of them):
#   window_bg, window_border   a window's field and the band round it
#   section_bg, section_border raised sections and the tab panel
#   slot_bg, slot_border       slot cells, input fields, the hairline border
#   text, title, text_dim      body text, titles, secondary text
#   coins                      the wallet line
#   btn_normal, btn_hover, btn_pressed, btn_border, btn_border_lit, btn_text, btn_text_hover
#   tooltip_bg                 the tooltip field (speech panels and the buff strip derive)
#   screen_bg                  the character creation full-screen field
#   radius (int), shadow (int)

const DEFAULT_ID := "dark_wood_brass"

# In the order the picker shows them.
const ORDER: Array[String] = [
	"dark_wood_brass", "weathered_parchment", "carved_stone", "illuminated_manuscript",
	"ironbound", "clean_flat", "swg_datapad", "faded_tapestry", "rune_bone", "gilded_cathedral",
]

const ALL: Dictionary = {
	"dark_wood_brass": {
		"display": "Dark wood and brass",
		"window_bg": Color(0.13, 0.085, 0.05, 0.96), "window_border": Color(0.78, 0.60, 0.26),
		"section_bg": Color(0.20, 0.13, 0.075), "section_border": Color(0.50, 0.37, 0.15),
		"slot_bg": Color(0.09, 0.06, 0.035), "slot_border": Color(0.50, 0.37, 0.15),
		"text": Color(0.92, 0.84, 0.66), "title": Color(0.94, 0.78, 0.40), "text_dim": Color(0.75, 0.70, 0.55),
		"coins": Color(1.00, 0.88, 0.30),
		"btn_normal": Color(0.26, 0.17, 0.09), "btn_hover": Color(0.36, 0.24, 0.12), "btn_pressed": Color(0.18, 0.12, 0.06),
		"btn_border": Color(0.50, 0.37, 0.15), "btn_border_lit": Color(0.78, 0.60, 0.26),
		"btn_text": Color(0.92, 0.84, 0.66), "btn_text_hover": Color(0.94, 0.78, 0.40),
		"tooltip_bg": Color(0.10, 0.065, 0.04, 0.97), "screen_bg": Color(0.06, 0.04, 0.025),
		"radius": 3, "shadow": 6,
	},
	"weathered_parchment": {
		"display": "Weathered parchment",
		"window_bg": Color(0.82, 0.74, 0.58, 0.97), "window_border": Color(0.36, 0.22, 0.12),
		"section_bg": Color(0.76, 0.67, 0.50), "section_border": Color(0.45, 0.30, 0.16),
		"slot_bg": Color(0.70, 0.60, 0.44), "slot_border": Color(0.45, 0.30, 0.16),
		"text": Color(0.16, 0.11, 0.07), "title": Color(0.42, 0.12, 0.08), "text_dim": Color(0.38, 0.30, 0.22),
		"coins": Color(0.45, 0.30, 0.05),
		"btn_normal": Color(0.60, 0.16, 0.12), "btn_hover": Color(0.70, 0.22, 0.16), "btn_pressed": Color(0.48, 0.12, 0.09),
		"btn_border": Color(0.30, 0.08, 0.06), "btn_border_lit": Color(0.85, 0.60, 0.25),
		"btn_text": Color(0.96, 0.90, 0.78), "btn_text_hover": Color(1.00, 0.95, 0.85),
		"tooltip_bg": Color(0.90, 0.84, 0.70, 0.98), "screen_bg": Color(0.62, 0.54, 0.40),
		"radius": 2, "shadow": 4,
	},
	"carved_stone": {
		"display": "Carved stone",
		"window_bg": Color(0.22, 0.23, 0.25, 0.97), "window_border": Color(0.55, 0.38, 0.18),
		"section_bg": Color(0.28, 0.29, 0.31), "section_border": Color(0.40, 0.41, 0.44),
		"slot_bg": Color(0.15, 0.16, 0.18), "slot_border": Color(0.40, 0.41, 0.44),
		"text": Color(0.85, 0.84, 0.80), "title": Color(0.80, 0.58, 0.30), "text_dim": Color(0.62, 0.62, 0.60),
		"coins": Color(0.90, 0.72, 0.35),
		"btn_normal": Color(0.30, 0.31, 0.34), "btn_hover": Color(0.50, 0.36, 0.20), "btn_pressed": Color(0.20, 0.21, 0.23),
		"btn_border": Color(0.45, 0.46, 0.49), "btn_border_lit": Color(0.80, 0.58, 0.30),
		"btn_text": Color(0.85, 0.84, 0.80), "btn_text_hover": Color(0.98, 0.88, 0.70),
		"tooltip_bg": Color(0.14, 0.15, 0.17, 0.97), "screen_bg": Color(0.12, 0.13, 0.14),
		"radius": 2, "shadow": 4,
	},
	"illuminated_manuscript": {
		"display": "Illuminated manuscript",
		"window_bg": Color(0.94, 0.90, 0.78, 0.98), "window_border": Color(0.80, 0.62, 0.20),
		"section_bg": Color(0.90, 0.85, 0.70), "section_border": Color(0.62, 0.48, 0.16),
		"slot_bg": Color(0.86, 0.80, 0.64), "slot_border": Color(0.62, 0.48, 0.16),
		"text": Color(0.18, 0.12, 0.08), "title": Color(0.55, 0.10, 0.10), "text_dim": Color(0.40, 0.32, 0.24),
		"coins": Color(0.60, 0.45, 0.10),
		"btn_normal": Color(0.16, 0.24, 0.48), "btn_hover": Color(0.22, 0.32, 0.60), "btn_pressed": Color(0.12, 0.18, 0.38),
		"btn_border": Color(0.80, 0.62, 0.20), "btn_border_lit": Color(0.95, 0.80, 0.35),
		"btn_text": Color(0.95, 0.92, 0.80), "btn_text_hover": Color(1.00, 0.96, 0.85),
		"tooltip_bg": Color(0.97, 0.94, 0.85, 0.98), "screen_bg": Color(0.78, 0.72, 0.58),
		"radius": 3, "shadow": 4,
	},
	"ironbound": {
		"display": "Ironbound",
		"window_bg": Color(0.08, 0.08, 0.09, 0.98), "window_border": Color(0.35, 0.36, 0.38),
		"section_bg": Color(0.12, 0.12, 0.13), "section_border": Color(0.28, 0.29, 0.31),
		"slot_bg": Color(0.05, 0.05, 0.06), "slot_border": Color(0.28, 0.29, 0.31),
		"text": Color(0.78, 0.78, 0.76), "title": Color(0.86, 0.86, 0.84), "text_dim": Color(0.55, 0.55, 0.54),
		"coins": Color(0.75, 0.70, 0.55),
		"btn_normal": Color(0.16, 0.16, 0.18), "btn_hover": Color(0.24, 0.24, 0.26), "btn_pressed": Color(0.10, 0.10, 0.11),
		"btn_border": Color(0.40, 0.41, 0.43), "btn_border_lit": Color(0.70, 0.20, 0.16),
		"btn_text": Color(0.78, 0.78, 0.76), "btn_text_hover": Color(0.95, 0.90, 0.88),
		"tooltip_bg": Color(0.05, 0.05, 0.06, 0.98), "screen_bg": Color(0.04, 0.04, 0.045),
		"radius": 0, "shadow": 0,
	},
	"clean_flat": {
		"display": "Clean low-poly flat",
		"window_bg": Color(0.15, 0.17, 0.19, 0.94), "window_border": Color(0.22, 0.25, 0.28),
		"section_bg": Color(0.19, 0.21, 0.24), "section_border": Color(0.25, 0.28, 0.31),
		"slot_bg": Color(0.11, 0.13, 0.15), "slot_border": Color(0.25, 0.28, 0.31),
		"text": Color(0.90, 0.92, 0.93), "title": Color(0.33, 0.78, 0.72), "text_dim": Color(0.62, 0.66, 0.68),
		"coins": Color(0.95, 0.80, 0.35),
		"btn_normal": Color(0.24, 0.27, 0.31), "btn_hover": Color(0.30, 0.34, 0.38), "btn_pressed": Color(0.18, 0.21, 0.24),
		"btn_border": Color(0.24, 0.27, 0.31), "btn_border_lit": Color(0.33, 0.78, 0.72),
		"btn_text": Color(0.90, 0.92, 0.93), "btn_text_hover": Color(1.00, 1.00, 1.00),
		"tooltip_bg": Color(0.11, 0.13, 0.15, 0.96), "screen_bg": Color(0.10, 0.12, 0.14),
		"radius": 6, "shadow": 0,
	},
	"swg_datapad": {
		"display": "SWG datapad",
		"window_bg": Color(0.08, 0.12, 0.16, 0.80), "window_border": Color(0.20, 0.75, 0.85),
		"section_bg": Color(0.10, 0.16, 0.21, 0.85), "section_border": Color(0.15, 0.50, 0.60),
		"slot_bg": Color(0.05, 0.09, 0.12), "slot_border": Color(0.15, 0.50, 0.60),
		"text": Color(0.80, 0.92, 0.96), "title": Color(0.45, 0.90, 1.00), "text_dim": Color(0.55, 0.70, 0.76),
		"coins": Color(0.95, 0.85, 0.45),
		"btn_normal": Color(0.10, 0.22, 0.28), "btn_hover": Color(0.14, 0.32, 0.40), "btn_pressed": Color(0.07, 0.15, 0.20),
		"btn_border": Color(0.20, 0.55, 0.65), "btn_border_lit": Color(0.45, 0.90, 1.00),
		"btn_text": Color(0.80, 0.92, 0.96), "btn_text_hover": Color(1.00, 1.00, 1.00),
		"tooltip_bg": Color(0.06, 0.10, 0.14, 0.92), "screen_bg": Color(0.05, 0.08, 0.11),
		"radius": 2, "shadow": 0,
	},
	"faded_tapestry": {
		"display": "Faded tapestry",
		"window_bg": Color(0.36, 0.14, 0.14, 0.97), "window_border": Color(0.60, 0.52, 0.25),
		"section_bg": Color(0.30, 0.12, 0.12), "section_border": Color(0.50, 0.42, 0.20),
		"slot_bg": Color(0.22, 0.09, 0.09), "slot_border": Color(0.50, 0.42, 0.20),
		"text": Color(0.90, 0.84, 0.72), "title": Color(0.85, 0.75, 0.45), "text_dim": Color(0.70, 0.62, 0.52),
		"coins": Color(0.92, 0.80, 0.45),
		"btn_normal": Color(0.18, 0.30, 0.18), "btn_hover": Color(0.24, 0.40, 0.24), "btn_pressed": Color(0.12, 0.22, 0.12),
		"btn_border": Color(0.40, 0.50, 0.30), "btn_border_lit": Color(0.80, 0.70, 0.40),
		"btn_text": Color(0.90, 0.84, 0.72), "btn_text_hover": Color(0.98, 0.94, 0.80),
		"tooltip_bg": Color(0.22, 0.09, 0.09, 0.97), "screen_bg": Color(0.24, 0.09, 0.09),
		"radius": 2, "shadow": 4,
	},
	"rune_bone": {
		"display": "Rune-etched bone",
		"window_bg": Color(0.80, 0.77, 0.68, 0.97), "window_border": Color(0.20, 0.18, 0.15),
		"section_bg": Color(0.72, 0.69, 0.60), "section_border": Color(0.30, 0.28, 0.24),
		"slot_bg": Color(0.64, 0.61, 0.52), "slot_border": Color(0.30, 0.28, 0.24),
		"text": Color(0.15, 0.14, 0.12), "title": Color(0.12, 0.40, 0.22), "text_dim": Color(0.36, 0.34, 0.30),
		"coins": Color(0.40, 0.30, 0.10),
		"btn_normal": Color(0.25, 0.23, 0.20), "btn_hover": Color(0.20, 0.45, 0.28), "btn_pressed": Color(0.15, 0.14, 0.12),
		"btn_border": Color(0.35, 0.33, 0.28), "btn_border_lit": Color(0.35, 0.85, 0.50),
		"btn_text": Color(0.90, 0.88, 0.80), "btn_text_hover": Color(0.95, 1.00, 0.92),
		"tooltip_bg": Color(0.86, 0.83, 0.74, 0.98), "screen_bg": Color(0.60, 0.57, 0.50),
		"radius": 3, "shadow": 3,
	},
	"gilded_cathedral": {
		"display": "Gilded cathedral",
		"window_bg": Color(0.07, 0.09, 0.20, 0.97), "window_border": Color(0.85, 0.68, 0.28),
		"section_bg": Color(0.10, 0.13, 0.27), "section_border": Color(0.60, 0.48, 0.20),
		"slot_bg": Color(0.05, 0.06, 0.14), "slot_border": Color(0.60, 0.48, 0.20),
		"text": Color(0.92, 0.90, 0.82), "title": Color(0.95, 0.80, 0.40), "text_dim": Color(0.68, 0.68, 0.64),
		"coins": Color(0.98, 0.85, 0.40),
		"btn_normal": Color(0.14, 0.18, 0.36), "btn_hover": Color(0.20, 0.26, 0.48), "btn_pressed": Color(0.09, 0.12, 0.26),
		"btn_border": Color(0.60, 0.48, 0.20), "btn_border_lit": Color(0.95, 0.80, 0.40),
		"btn_text": Color(0.92, 0.90, 0.82), "btn_text_hover": Color(1.00, 0.95, 0.80),
		"tooltip_bg": Color(0.05, 0.06, 0.14, 0.97), "screen_bg": Color(0.05, 0.06, 0.14),
		"radius": 3, "shadow": 6,
	},
}

static func get_palette(id: String) -> Dictionary:
	return ALL.get(id, ALL[DEFAULT_ID])

static func is_known(id: String) -> bool:
	return ALL.has(id)

static func theme_path(id: String) -> String:
	return "res://assets/ui/themes/%s.tres" % id

# ── Derived colours: one rule for every palette ─────────────────────────────

static func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)

# The runtime colours UITheme carries, derived from the palette so a palette
# never has to spell out every state.
static func runtime_colors(id: String) -> Dictionary:
	var p := get_palette(id)
	var window: Color = p["window_bg"]
	var opaque_window := Color(window.r, window.g, window.b, 1.0)
	return {
		"C_BORDER": p["slot_border"],
		"C_GOLDEN_BORDER": p["window_border"],
		"C_TITLE": p["title"],
		"C_TEXT": p["text"],
		"C_WINDOW_BG": p["window_bg"],
		"C_SCREEN_BG": p["screen_bg"],
		"C_PANEL_BG": p["section_bg"],
		"C_SLOT_BG": p["slot_bg"],
		"C_TOOLTIP": p["tooltip_bg"],
		"C_SELECTED": _mix(p["btn_border_lit"], opaque_window, 0.35),
		"C_BTN_NORM": p["btn_normal"],
		"C_BTN_HOVER": p["btn_hover"],
		"C_BTN_LOCKED_BG": _mix(p["btn_normal"], opaque_window, 0.6),
		"C_BTN_LOCKED_BORDER": _mix(p["btn_border"], opaque_window, 0.5),
		"C_BTN_LOCKED_TEXT": _mix(p["text"], opaque_window, 0.55),
		"C_CONFIRM_BG": _mix(p["btn_normal"], p["btn_border_lit"], 0.25),
		"C_CONFIRM_BG_HOVER": _mix(p["btn_hover"], p["btn_border_lit"], 0.35),
		"C_CONFIRM_BG_DISABLED": _mix(p["btn_normal"], opaque_window, 0.6),
		"C_CONFIRM_BORDER_DISABLED": _mix(p["btn_border"], opaque_window, 0.5),
		"C_NEUTRAL": p["text_dim"],
		"C_COINS": p["coins"],
	}

# The style box fields the Theme template needs beyond the palette's own keys.
static func theme_colors(id: String) -> Dictionary:
	var p := get_palette(id)
	var window: Color = p["window_bg"]
	var opaque_window := Color(window.r, window.g, window.b, 1.0)
	var slot: Color = p["slot_bg"]
	return {
		"speech_bg": Color(slot.r, slot.g, slot.b, 0.9),
		"strip_bg": Color(_mix(opaque_window, Color.BLACK, 0.35).r, _mix(opaque_window, Color.BLACK, 0.35).g, _mix(opaque_window, Color.BLACK, 0.35).b, 0.7),
		"btn_disabled": _mix(p["btn_normal"], opaque_window, 0.6),
		"btn_border_disabled": _mix(p["btn_border"], opaque_window, 0.5),
		"btn_text_disabled": _mix(p["text"], opaque_window, 0.5),
		"tab_selected_bg": p["section_bg"],
		"tab_unselected_bg": p["slot_bg"],
		"tab_hover_bg": p["btn_hover"],
		"placeholder": Color(p["text_dim"].r, p["text_dim"].g, p["text_dim"].b, 0.8),
		"focus": Color(p["btn_border_lit"].r, p["btn_border_lit"].g, p["btn_border_lit"].b, 0.9),
	}
