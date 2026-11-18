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
var _open_motion: Tween
var _dismiss_motion: Tween
var _aperture := 1.0
var _weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

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
	set_process(false)

func open_at(point: Vector2, entries: Array) -> void:
	options = entries
	var bounds: Vector2 = get_viewport_rect().size
	center = point.clamp(Vector2.ONE * 150.0, bounds - Vector2.ONE * 150.0)
	_pressed_at = point
	_moved = false
	selected = -1
	active = true
	if _dismiss_motion: _dismiss_motion.kill()
	_weights.fill(0)
	_aperture = 0.76
	if _open_motion: _open_motion.kill()
	_open_motion = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_open_motion.tween_method(_set_aperture, _aperture, 1.0, 0.16)
	show()
	UITheme.reveal(self, 0.12)
	_layout_labels()
	queue_redraw()

func cancel() -> void:
	if not active: return
	active = false
	if _open_motion: _open_motion.kill()
	set_process(false)
	var entering: Tween = get_meta(&"reveal")
	entering.kill()
	_dismiss_motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_dismiss_motion.tween_property(self, "modulate:a", 0.0, 0.11)
	_dismiss_motion.tween_callback(hide)
	selected = -1

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
	var next := direction_at(point) if _moved else -1
	if selected == next: return
	selected = next
	set_process(true)
	_layout_labels()
	queue_redraw()

func _layout_labels() -> void:
	for i in range(4):
		var direction := Vector2.from_angle(-PI * 0.5 + float(i) * PI * 0.5)
		_labels[i].position = center + direction * 91.0 * _aperture - _labels[i].size * 0.5
		_labels[i].text = str(options[i].label)
		var enabled: bool = bool(options[i].enabled)
		_labels[i].add_theme_color_override("font_color", UITheme.BRASS if enabled and selected == i else (UITheme.CREAM if enabled else Color("77777f")))
	_center_label.position = center - _center_label.size * 0.5
	_center_label.text = tr("Cancel") if selected < 0 else (tr("Release") if bool(options[selected].enabled) else tr("Unavailable"))

func _set_aperture(value: float) -> void:
	_aperture = value
	_layout_labels()
	queue_redraw()

func _process(delta: float) -> void:
	var moving := false
	for i in range(4):
		var target := 1.0 if selected == i else 0.0
		_weights[i] = move_toward(_weights[i], target, delta * 7.5)
		if not is_equal_approx(_weights[i], target): moving = true
	queue_redraw()
	set_process(moving)

func _draw() -> void:
	if not active: return
	var ring := OUTER * _aperture
	for i in range(4):
		var angle := -PI * 0.5 + i * PI * 0.5
		var enabled: bool = options[i].enabled
		var weight := _weights[i]
		var first := angle - PI * 0.24
		var last := angle + PI * 0.24
		var radius := ring + weight * 5.0
		var points := PackedVector2Array()
		# Seven facets per sector keep the aperture and highlighted rim visibly cut.
		for step in range(7):
			points.append(center + Vector2.from_angle(lerpf(first,last,step/6.0)) * radius)
		for step in range(6,-1,-1):
			points.append(center + Vector2.from_angle(lerpf(first,last,step/6.0)) * INNER)
		var ink := Color("142638f6") if enabled else Color("152030ed")
		var lit := Color("285653") if enabled else Color("27313d")
		draw_colored_polygon(points, ink.lerp(lit, weight))
		points.append(points[0])
		var rim := UITheme.BORDER.lerp(UITheme.JADE if enabled else UITheme.MUTED, weight)
		draw_polyline(points, rim, 1.0, true)
		draw_arc(center, radius - 5, angle - 0.16 - weight * 0.14, angle + 0.16 + weight * 0.14, 4, rim, 3.0)
		var cursor := center + Vector2.from_angle(angle) * (INNER + 11)
		draw_rect(Rect2(cursor.round() - Vector2(2,2), Vector2(4,4)), rim)
	draw_circle(center, INNER - 3, Color("0c1829ef"))
	draw_arc(center, INNER - 4, 0.0, TAU, 12, UITheme.BORDER, 1.5)
