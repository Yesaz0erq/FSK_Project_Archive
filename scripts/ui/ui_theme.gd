class_name UITheme
extends RefCounted
## Warm, dark storybook UI: deep plum-brown panels, brass borders, cream text.

const BG := Color(0.11, 0.09, 0.105, 0.90)
const BG_SOFT := Color(0.17, 0.14, 0.15, 0.95)
const BORDER := Color("6a5038")
const BRASS := Color("d9a85a")
const CREAM := Color("efe2c6")
const MUTED := Color("a8998a")
const GOOD := Color("9fd07a")
const BAD := Color("e8806a")

static var serif: SystemFont
static var sans: SystemFont

static func fonts() -> void:
	if serif != null: return
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Palatino Linotype", "Book Antiqua", "Palatino", "Georgia", "DejaVu Serif", "serif"])
	serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI", "Noto Sans", "Helvetica Neue", "DejaVu Sans", "sans-serif"])

static func box(bg: Color, border: Color = BORDER, radius: int = 10, bw: int = 2, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 4
	return s

static func build() -> Theme:
	fonts()
	var t := Theme.new()
	t.default_font = sans
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box(BG))
	t.set_stylebox("panel", "Panel", box(BG))
	t.set_color("font_color", "Label", CREAM)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg: Color = BG_SOFT
		var br: Color = BORDER
		match state:
			"hover": bg = Color("3a2f33"); br = BRASS
			"pressed": bg = Color("5a4230"); br = BRASS
			"disabled": bg = Color(0.14, 0.12, 0.13, 0.8); br = Color("3a3030")
			"focus": bg = Color(0, 0, 0, 0); br = Color(BRASS, 0.6)
		var sb := box(bg, br, 8, 2, 6)
		sb.shadow_size = 0
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color("fff4dc"))
	t.set_color("font_pressed_color", "Button", Color("fff4dc"))
	t.set_color("font_disabled_color", "Button", Color("6e645c"))
	t.set_stylebox("panel", "TabContainer", box(BG, BORDER, 10, 2, 8))
	t.set_stylebox("tab_selected", "TabContainer", box(Color("4a3828"), BRASS, 8, 2, 6))
	t.set_stylebox("tab_unselected", "TabContainer", box(BG_SOFT, BORDER, 8, 2, 6))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color("3a2f33"), BRASS, 8, 2, 6))
	t.set_color("font_selected_color", "TabContainer", Color("fff4dc"))
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_stylebox("normal", "LineEdit", box(Color("150f12"), BORDER, 6, 2, 6))
	t.set_stylebox("focus", "LineEdit", box(Color("150f12"), BRASS, 6, 2, 6))
	t.set_color("font_color", "LineEdit", CREAM)
	var tip := box(Color("201a1d", 0.97), BRASS, 8, 2, 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 14)
	return t

static func label(text: String, size: int = 15, color: Color = CREAM, use_serif: bool = false) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if use_serif: l.add_theme_font_override("font", serif)
	return l

static func bar(value: float, color: Color, width: float = 150.0, height: float = 10.0, marker: float = -1.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	var bg := ColorRect.new()
	bg.color = Color("0f0b0d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(0.0, (width - 2) * clampf(value, 0.0, 1.0)), height - 2)
	c.add_child(fill)
	if marker >= 0.0:
		var mk := ColorRect.new()
		mk.color = Color(1, 1, 1, 0.75)
		mk.position = Vector2((width - 2) * clampf(marker, 0.0, 1.0), -2)
		mk.size = Vector2(2, height + 4)
		c.add_child(mk)
	return c
