extends Control
## Screen-space guide anchored to the animated parcel mesh and radial menu.
signal intro_dismissed

const POINTER := preload("res://assets/tutorial/field_pointer.svg")
const HOTSPOT := Vector2(2, 1)
const DARK := Color("#102534")
const JADE := Color("#7ad9bd")
const IVORY := Color("#fff3b9")
const TOP_CORNERS := [
	Vector3(-.766, .314, -.766), Vector3(.766, .314, -.766),
	Vector3(.766, .314, .766), Vector3(-.766, .314, .766),
]

enum Hint { NONE, TILES, SECTOR, INTRO }
var _hint := Hint.NONE
var _cells: Array = []
var _left := false
var _count := ""
var _age := 0.0
var _cursor_outline := PackedVector2Array()
var _view: Node3D
var _radial: Control
var _card: PanelContainer
var _portrait: TextureRect
var _title: Label
var _description: Label
var _intro_cell := Vector2i(-1, -1)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = UITheme.build()
	var mask := BitMap.new()
	mask.create_from_image_alpha(POINTER.get_image())
	var shapes := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask.get_size()), .45)
	if not shapes.is_empty(): _cursor_outline = shapes[0]
	_build_card()
	set_process(false)

func setup(view: Node3D, radial: Control) -> void:
	_view = view
	_radial = radial
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(POINTER, Input.CURSOR_ARROW, HOTSPOT)

func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func show_tiles(cells: Array, left_click: bool, count_text := "") -> void:
	_cells = cells.duplicate()
	_left = left_click
	_count = count_text
	_set_hint(Hint.TILES)

func show_sector(count_text := "") -> void:
	_count = count_text
	_set_hint(Hint.SECTOR)

func show_intro(cell: Vector2i, machine_id: String) -> void:
	_intro_cell = cell
	var machine: Dictionary = Data.machines[machine_id]
	_title.text = tr(str(machine.name))
	_description.text = tr(str(machine.description))
	_portrait.texture = Art.machine(machine_id)
	_set_hint(Hint.INTRO)
	_position_card()

func clear_hint() -> void:
	_cells.clear()
	_set_hint(Hint.NONE)

func _set_hint(kind: Hint) -> void:
	_hint = kind
	_card.visible = kind == Hint.INTRO
	set_process(kind != Hint.NONE)
	queue_redraw()

func _process(delta: float) -> void:
	_age = fmod(_age + delta, 16.0)
	if _hint == Hint.INTRO: _position_card()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_view): return
	var pulse := .5 + .5 * cos(_age * TAU / 1.6)
	match _hint:
		Hint.TILES:
			var centers := PackedVector2Array()
			for cell: Vector2i in _cells:
				var tile: MeshInstance3D = _view._tiles.get(cell)
				if not is_instance_valid(tile): continue
				var contour := PackedVector2Array()
				for corner: Vector3 in TOP_CORNERS:
					contour.append(_project(tile.to_global(corner)))
				_outline(contour, pulse)
				centers.append((contour[0] + contour[2]) * .5)
			for i in centers.size():
				var tip := centers[i].round()
				var left_side := centers.size() == 2 and tip.x < centers[1-i].x
				_draw_pointer(tip, pulse)
				_mouse(tip + (Vector2(-34, 3) if left_side else Vector2(29, 3)), _left, pulse, left_side)
		Hint.SECTOR:
			if not _radial.active: return
			for i in _radial.options.size():
				if _radial.options[i].action != "plant": continue
				var polygon: PackedVector2Array = _radial.sector_polygon(i)
				_outline(polygon, pulse)
				var direction := Vector2.from_angle(-PI * .5 + i * PI * .5)
				var radius: float = _radial.center.distance_to(polygon[3])
				_mouse(_radial.center + direction * radius * .61 + Vector2(-11, 9), true, pulse, false)
				break
		Hint.INTRO:
			if not _view._tiles.has(_intro_cell): return
			var anchor := _machine_anchor()
			if not Rect2(Vector2.ZERO, size).has_point(anchor): return
			var near := anchor.clamp(_card.position, _card.position + _card.size)
			draw_line(anchor, near, DARK, 3.5, true)
			draw_line(anchor, near, JADE, 1.5, true)
			draw_circle(anchor, 3.5, DARK)
			draw_circle(anchor, 2, IVORY)

func _project(point: Vector3) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * _view.camera.unproject_position(point)

func _outline(points: PackedVector2Array, pulse: float) -> void:
	if points.size() < 3: return
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, Color(DARK, .88), 6.0, true)
	draw_polyline(loop, Color(JADE, .20 + .22 * pulse), 5.0, true)
	draw_polyline(loop, JADE.lerp(IVORY, pulse), 2.0, true)

func _draw_pointer(tip: Vector2, pulse: float) -> void:
	var origin := tip - HOTSPOT
	var outline := Transform2D(0.0, origin) * _cursor_outline
	draw_texture(POINTER, origin)
	_outline(outline, pulse)

func _mouse(origin: Vector2, left: bool, pulse: float, count_on_left: bool) -> void:
	var at := origin.round()
	var rgb := JADE.lerp(IVORY, pulse)
	# Keep the same mouse silhouette for the two gestures. The held button
	# stays lit as its meter grows; the clicked button releases between taps.
	var shell := PackedVector2Array([Vector2(5,0),Vector2(17,0),Vector2(22,5),
		Vector2(22,25),Vector2(17,31),Vector2(5,31),Vector2(0,25),Vector2(0,5)])
	shell = Transform2D(0, at) * shell
	draw_colored_polygon(shell, DARK)
	var button := PackedVector2Array([Vector2(2,6),Vector2(6,2),Vector2(10,2),Vector2(10,14),Vector2(2,14)])
	if not left:
		for i in button.size(): button[i].x = 22.0 - button[i].x
	var pressed := pulse if left else .86
	draw_colored_polygon(Transform2D(0, at) * button, JADE.darkened(.26).lerp(IVORY, pressed))
	shell.append(shell[0])
	draw_polyline(shell, rgb, 1.8, true)
	draw_line(at+Vector2(11,2), at+Vector2(11,14), Color("#546b70"), 1.5)
	draw_line(at+Vector2(2,15), at+Vector2(20,15), Color("#546b70"), 1.5)
	if not left:
		draw_rect(Rect2(at+Vector2(5,22), Vector2(12,2)), Color("#39535b"))
		draw_rect(Rect2(at+Vector2(5,22), Vector2(roundf(3+9*pulse),2)), rgb)
	if not _count.is_empty():
		var label_at := at + Vector2(-29 if count_on_left else 26, 23)
		draw_string_outline(UITheme.sans, label_at, _count, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, DARK)
		draw_string(UITheme.sans, label_at, _count, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, IVORY)

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "MachineIntroduction"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.add_theme_stylebox_override("panel", UITheme.frame(Color("#142637fc"), 14))
	add_child(_card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 13)
	_card.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(62, 80)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	_title = UITheme.label("", 20, UITheme.BRASS, true)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_title)
	_description = UITheme.label("", 15)
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_description)
	_card.gui_input.connect(_on_card_input)
	_card.hide()

func _machine_anchor() -> Vector2:
	var tile: MeshInstance3D = _view._tiles[_intro_cell]
	return _project(tile.global_position + Vector3.UP * 1.55)

func _position_card() -> void:
	if not is_instance_valid(_view) or not _view._tiles.has(_intro_cell): return
	var anchor := _machine_anchor()
	var width := minf(336, maxf(160, size.x - 16))
	_card.size = Vector2(width, _card.get_combined_minimum_size().y)
	var pos := anchor + Vector2(25, -_card.size.y - 15)
	if pos.x + _card.size.x > size.x - 8: pos.x = anchor.x - 25 - _card.size.x
	if pos.y < 8: pos.y = anchor.y + 15
	_card.position = pos.clamp(Vector2(8, 8), (size - _card.size - Vector2(8, 8)).max(Vector2(8,8))).round()

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_card.accept_event()
		clear_hint()
		intro_dismissed.emit()
