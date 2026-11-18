class_name UITheme
extends RefCounted
## Ink-blue panels, stepped metalwork and mineral-glass accents.

const BG := Color("101d30f4")
const BG_SOFT := Color("1b2e42")
const BORDER := Color("426173")
const BRASS := Color("ffd6a2")
const CREAM := Color("edf4ee")
const MUTED := Color("a5bac6")
const JADE := Color("89e2cc")
const GOOD := Color("b6e59c")
const BAD := Color("ffa192")

static var serif: SystemFont
static var sans: SystemFont
static var _theme: Theme
static var _icons: Dictionary = {}
# Eleven-pixel silhouettes are enlarged on their native grid.
const GLYPHS := {
	"forest": [".....+.....","....+++....","...+++++...","....+++....","..+++++++..","...+++++...",".+++++++++.","....++.....","....++....."],
	"desert": [".......++..",".......++..","...........","....+......","...+++.....","..+++++.++.","++++++..+++","+++....++++","+++++++++++"],
	"volcano": [".....+.....","....+.+....",".....+.....","....+++....","...++.++...","...+.+++...","..+++++++..",".+++++++++.","+++++++++++"],
	"snow": [".....+.....","....+++....","...+++++...","..++.++++..","..+...++++.",".+.....++.+","++++...++++","+++++.+++++","+++++++++++"],
	"tide": ["...........","....++++...","...++..++..","..+++......","..++++..+..",".+++++++++.","...........",".++..++..++","...++..++.."],
	"glossary": ["...........","++++.+++++.","+...++...+.", "+...++...+.", "+...++...+.", "+...++...+.", "++++.+++++.", "....++.....","..........."],
	"settings": ["...+...+...","..++...++..","...+++++...",".+++...+++.","+++.....+++",".+++...+++.","...+++++...","..++...++..","...+...+..."],
	"save": [".++++++++..",".++...+.++.",".++...+.++.",".+++++++++.",".++.....++.",".++.+++.++.",".++.+++.++.",".++.....++.","..+++++++.."],
	"load": ["....++.....","....++.....","..+.++.+...","...++++....","....++.....","...........",".+......+..",".+......+..",".++++++++.."],
	"menu": ["...........",".+++++++++.","...........","...........",".+++++++++.","...........","...........",".+++++++++.","..........."],
	"continue": ["...+.......","...++......","...+++.....","...++++....","...+++++...","...++++....","...+++.....","...++......","...+......."],
	"new": [".....+.....","....+++....","...+++++...","....+++....",".....+.....","...........","...+++++...",".++.....++.","...+++++..."]
}

static func icon(id: String, tint: Color = JADE) -> Texture2D:
	var key := id + tint.to_html()
	if _icons.has(key): return _icons[key]
	var pattern: Array = GLYPHS[id]
	var surface := Image.create_empty(22, 18, false, Image.FORMAT_RGBA8)
	for y in pattern.size():
		for x in pattern[y].length():
			if pattern[y][x] == "+":
				var paint := tint if y < 5 else tint.darkened(0.16)
				surface.fill_rect(Rect2i(x * 2, y * 2, 2, 2), paint)
	_icons[key] = ImageTexture.create_from_image(surface)
	return _icons[key]

static func fonts() -> void:
	if serif != null: return
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Source Han Serif SC", "SimSun", "Songti SC", "Noto Serif CJK SC", "Georgia", "serif"])
	serif.font_weight = 650
	serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI", "DejaVu Sans", "sans-serif"])

static func box(bg: Color, border: Color = BORDER, radius: int = 6, bw: int = 1, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 1
	s.anti_aliasing = false
	s.set_content_margin_all(margin)
	s.shadow_color = Color("040b1880")
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s

## A pixel-cut nine-patch. The short engraved stripes and corner rivets are
## confined to the frame so its interior stays quiet behind Chinese text.
static func frame(fill: Color = BG, margin: int = 14) -> StyleBoxTexture:
	var img := Image.create_empty(36, 36, false, Image.FORMAT_RGBA8)
	for y in 36:
		for x in 36:
			var dx := mini(x, 35 - x)
			var dy := mini(y, 35 - y)
			var edge := mini(dx, dy)
			if dx + dy < 6: continue
			var color := fill
			if edge == 0 or dx + dy == 6:
				color = Color("5a7885") if y < 18 else Color("2c4358")
			elif edge == 1 or dx + dy == 7:
				color = Color("0b1524")
			elif dy == 2 and dx > 5:
				color = Color("283c50") if y < 18 else Color("172939")
			if (y == 0 and x >= 7 and x <= 14) or (x == 0 and y >= 7 and y <= 11):
				color = JADE
			if dx == 4 and dy == 5:
				color = Color("809497")
			img.set_pixel(x, y, color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(img)
	for side in [SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM, SIDE_LEFT]:
		style.set_texture_margin(side, 16.0)
		style.set_content_margin(side, margin)
	return style

static func build() -> Theme:
	if _theme != null: return _theme
	fonts()
	var t := Theme.new()
	t.default_font = sans
	t.default_font_size = 15
	var panel := frame()
	for type in ["PanelContainer", "Panel", "AcceptDialog", "PopupMenu"]:
		t.set_stylebox("panel", type, panel)
	t.set_color("font_color", "Label", CREAM)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var bg: Color = BG_SOFT
		var br: Color = BORDER
		match state:
			"hover": bg = Color("284658"); br = JADE
			"pressed", "hover_pressed": bg = Color("255354"); br = JADE
			"disabled": bg = Color("172432"); br = Color("314252")
			"focus": bg = Color.TRANSPARENT; br = BRASS
		var sb := box(bg, br, 4, 1, 6)
		sb.shadow_size = 0
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", JADE)
	t.set_color("font_disabled_color", "Button", Color("83919d"))
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_stylebox("tab_selected", "TabContainer", box(Color("244749"), JADE, 4, 1, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(BG, BORDER, 4, 1, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(BG_SOFT, JADE, 4, 1, 8))
	t.set_color("font_selected_color", "TabContainer", JADE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	for state: String in ["normal", "focus"]:
		t.set_stylebox(state, "LineEdit", box(Color("101c2b"), JADE if state == "focus" else BORDER, 4, 1, 7))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("caret_color", "LineEdit", JADE)
	t.set_stylebox("panel", "TooltipPanel", frame(Color("111d2dfc"), 10))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 14)
	for type: String in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = Color("385363")
		line.vertical = type == "VSeparator"
		t.set_stylebox("separator", type, line)
	_theme = t
	return t

static func label(text: String, size: int = 15, color: Color = CREAM, use_serif: bool = false) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(size, 13))
	l.add_theme_color_override("font_color", color)
	if use_serif: l.add_theme_font_override("font", serif)
	return l

static func reveal(control: Control, duration: float = 0.25, delay: float = 0.0) -> void:
	var previous: Tween = control.get_meta(&"reveal", null) if control.has_meta(&"reveal") else null
	if previous: previous.kill()
	var tw := control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	control.set_meta(&"reveal", tw)
	control.modulate.a = 0.0
	tw.tween_property(control, "modulate:a", 1.0, duration).set_delay(delay)

static func button_motion(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var adjust := func(target: Color, duration: float) -> void:
		var previous: Tween = button.get_meta(&"light", null) if button.has_meta(&"light") else null
		if previous: previous.kill()
		var tw := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		button.set_meta(&"light", tw)
		tw.tween_property(button, "self_modulate", target, duration)
	button.mouse_entered.connect(func() -> void: adjust.call(Color(1.13, 1.13, 1.08), 0.15))
	button.mouse_exited.connect(func() -> void: adjust.call(Color.WHITE, 0.18))
	button.button_down.connect(func() -> void: adjust.call(Color(0.84, 0.95, 0.95), 0.06))
	button.button_up.connect(func() -> void: adjust.call(Color.WHITE, 0.13))

static func bar(value: float, color: Color, width: float = 150.0, height: float = 10.0, marker: float = -1.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color("0b1421")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(0.0, (width - 2) * clampf(value, 0.0, 1.0)), height - 2)
	c.add_child(fill)
	var shine := ColorRect.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.color = Color(1, 1, 1, 0.34)
	shine.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shine.offset_bottom = 1
	fill.add_child(shine)
	if marker >= 0.0:
		var mk := ColorRect.new()
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mk.color = Color(1, 1, 1, 0.75)
		mk.position = Vector2((width - 2) * clampf(marker, 0.0, 1.0), -2)
		mk.size = Vector2(2, height + 4)
		c.add_child(mk)
	return c
