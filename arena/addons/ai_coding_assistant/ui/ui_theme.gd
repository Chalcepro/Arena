@tool
extends RefCounted
class_name AIUITheme

# Modern Dark Theme with Glassmorphism
# Colors - Cyberpunk/Neon theme
const COLOR_BG_DARK = Color("#0a0c10")  # Almost black
const COLOR_BG_MED = Color("#14181c")   # Dark gray with blue tint
const COLOR_BG_LIGHT = Color("#1e2429")  # Medium dark
const COLOR_SURFACE = Color("#2a3138")   # Card background
const COLOR_SURFACE_HOVER = Color("#364048")

# Accent colors
const COLOR_ACCENT = Color("#6366f1")    # Indigo 500 - primary
const COLOR_ACCENT_SOFT = Color("#818cf8") # Indigo 400
const COLOR_ACCENT_DARK = Color("#4f46e5") # Indigo 600
const COLOR_SUCCESS = Color("#10b981")    # Emerald 500
const COLOR_WARNING = Color("#f59e0b")    # Amber 500
const COLOR_ERROR = Color("#ef4444")      # Red 500
const COLOR_INFO = Color("#3b82f6")       # Blue 500

# Text colors
const COLOR_TEXT_PRIMARY = Color("#f3f4f6")  # Almost white
const COLOR_TEXT_SECONDARY = Color("#9ca3af") # Gray 400
const COLOR_TEXT_DISABLED = Color("#4b5563")  # Gray 600
const COLOR_TEXT_DIM = Color("#6b7280")       # Gray 500

# Syntax colors for code highlighting
const COLOR_SYNTAX_KEYWORD = Color("#f472b6") # Pink 400
const COLOR_SYNTAX_FUNCTION = Color("#60a5fa") # Blue 400
const COLOR_SYNTAX_STRING = Color("#fbbf24")  # Amber 400
const COLOR_SYNTAX_COMMENT = Color("#6b7280") # Gray 500
const COLOR_SYNTAX_NUMBER = Color("#a78bfa")  # Purple 400
const COLOR_SYNTAX_TYPE = Color("#4ade80")    # Green 400

# Code block colors
const COLOR_CODE_BG = Color("#0d1117")     # GitHub dark
const COLOR_CODE_HEADER = Color("#161b22")  # Slightly lighter
const COLOR_CODE_BORDER = Color("#30363d")

# Spacing
const SPACING_XS = 4
const SPACING_SM = 8
const SPACING_MD = 12
const SPACING_LG = 16
const SPACING_XL = 24

# Border radii
const RADIUS_SM = 4
const RADIUS_MD = 6
const RADIUS_LG = 8
const RADIUS_XL = 12
const RADIUS_CIRCLE = 9999

# Animation
const ANIMATION_FAST = 0.15
const ANIMATION_NORMAL = 0.25
const ANIMATION_SLOW = 0.35

# Font sizes
const FONT_SIZE_XS = 10
const FONT_SIZE_SM = 11
const FONT_SIZE_MD = 12
const FONT_SIZE_LG = 14
const FONT_SIZE_XL = 16

# Icons (using emoji as fallback, but you can use actual icons)
static func get_icon(name: String) -> String:
	match name:
		"send": return "➤"
		"stop": return "◼"
		"settings": return "⚙"
		"clear": return "🗑"
		"copy": return "📋"
		"check": return "✓"
		"error": return "⚠"
		"success": return "✓"
		"thinking": return "⋯"
		"agent": return "🤖"
		"user": return "👤"
		"code": return "📄"
		"file": return "📁"
		"folder": return "📂"
		"model": return "🧠"
		_ : return "•"

static func apply_card_style(panel: PanelContainer, elevated: bool = false):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.corner_radius_top_left = RADIUS_LG
	style.corner_radius_top_right = RADIUS_LG
	style.corner_radius_bottom_left = RADIUS_LG
	style.corner_radius_bottom_right = RADIUS_LG
	style.content_margin_left = SPACING_LG
	style.content_margin_right = SPACING_LG
	style.content_margin_top = SPACING_LG
	style.content_margin_bottom = SPACING_LG
	
	if elevated:
		style.shadow_color = Color(0, 0, 0, 0.3)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 2)
	
	panel.add_theme_stylebox_override("panel", style)

static func apply_button_style(button: Button, variant: String = "primary"):
	var normal = StyleBoxFlat.new()
	var hover = StyleBoxFlat.new()
	var pressed = StyleBoxFlat.new()
	var disabled = StyleBoxFlat.new()
	
	normal.corner_radius_top_left = RADIUS_MD
	normal.corner_radius_top_right = RADIUS_MD
	normal.corner_radius_bottom_left = RADIUS_MD
	normal.corner_radius_bottom_right = RADIUS_MD
	normal.content_margin_left = SPACING_MD
	normal.content_margin_right = SPACING_MD
	normal.content_margin_top = SPACING_SM
	normal.content_margin_bottom = SPACING_SM
	
	hover = normal.duplicate()
	pressed = normal.duplicate()
	disabled = normal.duplicate()
	
	match variant:
		"primary":
			normal.bg_color = COLOR_ACCENT
			hover.bg_color = COLOR_ACCENT_SOFT
			pressed.bg_color = COLOR_ACCENT_DARK
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)
			button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DISABLED)
		
		"secondary":
			normal.bg_color = COLOR_SURFACE
			hover.bg_color = COLOR_SURFACE_HOVER
			pressed.bg_color = COLOR_BG_LIGHT
			button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			button.add_theme_color_override("font_hover_color", COLOR_TEXT_PRIMARY)
			button.add_theme_color_override("font_pressed_color", COLOR_TEXT_PRIMARY)
		
		"danger":
			normal.bg_color = COLOR_ERROR
			hover.bg_color = Color("#f87171") # Lighter red
			pressed.bg_color = Color("#dc2626") # Darker red
			button.add_theme_color_override("font_color", Color.WHITE)
	
	disabled.bg_color = COLOR_BG_MED
	disabled.border_color = COLOR_TEXT_DISABLED
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

static func apply_input_style(input: Control):
	var normal = StyleBoxFlat.new()
	var focus = StyleBoxFlat.new()
	
	normal.bg_color = COLOR_BG_DARK
	normal.border_color = COLOR_BG_LIGHT
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.corner_radius_top_left = RADIUS_MD
	normal.corner_radius_top_right = RADIUS_MD
	normal.corner_radius_bottom_left = RADIUS_MD
	normal.corner_radius_bottom_right = RADIUS_MD
	normal.content_margin_left = SPACING_MD
	normal.content_margin_right = SPACING_MD
	normal.content_margin_top = SPACING_SM
	normal.content_margin_bottom = SPACING_SM
	
	focus = normal.duplicate()
	focus.border_color = COLOR_ACCENT
	focus.border_width_top = 2
	focus.border_width_bottom = 2
	focus.border_width_left = 2
	focus.border_width_right = 2
	
	if input is TextEdit or input is LineEdit:
		input.add_theme_stylebox_override("normal", normal)
		input.add_theme_stylebox_override("focus", focus)
		input.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		input.add_theme_color_override("cursor_color", COLOR_ACCENT)
		input.add_theme_color_override("selection_color", Color(COLOR_ACCENT, 0.3))
