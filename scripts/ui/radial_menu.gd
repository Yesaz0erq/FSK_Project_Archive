extends Control
## Four screen-space sectors; capture the release before any HUD control can consume it.
signal chosen(action: String)
const INNER: float = 38.0
const OUTER: float = 140.0
var active: bool = false
var center := Vector2.ZERO
var selected: int = -1
var options: Array = []
var _labels: Array[Label] = []
var _center_label: Label
var _pressed_at := Vector2.ZERO
var _moved: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(4):
		var label := UITheme.label("", 16)
		label.size = Vector2(116, 44)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)
	_center_label = UITheme.label(tr("Cancel"), 13, UITheme.MUTED)
	_center_label.size = Vector2(76, 46)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_label)
	get_window().focus_exited.connect(cancel)
	hide()

func open_at(point: Vector2, entries: Array) -> void:
	options = entries
	var bounds: Vector2 = get_viewport_rect().size
	center = point.clamp(Vector2.ONE * 150.0, bounds - Vector2.ONE * 150.0)
	_pressed_at = point
	_moved = false
	selected = -1
	active = true
	show()
	_layout_labels()
	queue_redraw()

func cancel() -> void:
	active = false
	selected = -1
	hide()

func direction_at(point: Vector2) -> int:
	var delta: Vector2 = point - center
	if delta.length() < INNER or delta.length() > OUTER + 60.0: return -1
	if absf(delta.x) > absf(delta.y): return 1 if delta.x > 0 else 3
	return 2 if delta.y > 0 else 0

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseMotion:
		_moved = _moved or event.position.distance_to(_pressed_at) > 8.0
		_update_selection(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_update_selection(event.position)
		var action: String = ""
		if _moved and selected >= 0 and bool(options[selected].enabled): action = str(options[selected].action)
		cancel()
		if action != "": chosen.emit(action)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
	get_viewport().set_input_as_handled()

func _update_selection(point: Vector2) -> void:
	selected = direction_at(point) if _moved else -1
	_layout_labels()
	queue_redraw()

func _layout_labels() -> void:
	for i in range(4):
		var direction := Vector2.from_angle(-PI * 0.5 + float(i) * PI * 0.5)
		_labels[i].position = center + direction * 92.0 - _labels[i].size * 0.5
		_labels[i].text = str(options[i].label)
		var enabled: bool = bool(options[i].enabled)
		_labels[i].add_theme_color_override("font_color", UITheme.BRASS if enabled and selected == i else (UITheme.CREAM if enabled else Color("77777f")))
	_center_label.position = center - _center_label.size * 0.5
	_center_label.text = tr("Cancel") if selected < 0 else (tr("Release") if bool(options[selected].enabled) else tr("Unavailable"))

func _draw() -> void:
	if not active: return
	draw_circle(center, OUTER + 7.0, Color(0.02,0.025,0.04,0.75))
	for i in range(4):
		var angle: float = -PI * 0.5 + float(i) * PI * 0.5
		var points := PackedVector2Array()
		var first: float = angle - PI * 0.25 + 0.025
		var last: float = angle + PI * 0.25 - 0.025
		for step in range(25): points.append(center + Vector2.from_angle(lerpf(first,last,step/24.0)) * OUTER)
		for step in range(24,-1,-1): points.append(center + Vector2.from_angle(lerpf(first,last,step/24.0)) * INNER)
		var enabled: bool = bool(options[i].enabled)
		var color := Color("242938") if enabled else Color("1c1f29")
		if i == selected: color = Color("514536") if enabled else Color("2c2b32")
		draw_colored_polygon(points, color)
		draw_arc(center, OUTER, first, last, 24, UITheme.BRASS if i == selected and enabled else Color("626071"), 2.0, true)
	draw_circle(center, INNER - 2.0, Color("171b26"))
