extends Node
## Game scene: owns the current BiomeView and the HUD, handles travel between the four scenes.

const BiomeViewScript := preload("res://scripts/world/biome_view.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

var hud: CanvasLayer
var view: Node3D
var biome: String = "forest"
var _fade: ColorRect
var _travelling: bool = false

func _ready() -> void:
	if not Sim.running:
		Sim.new_game(randi() % 1000000)
	hud = HudScript.new()
	add_child(hud)
	hud.travel_requested.connect(travel)
	hud.menu_requested.connect(_to_menu)
	var fl := CanvasLayer.new()
	fl.layer = 20
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color("120e10")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	_load_biome(biome)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)

func _load_biome(id: String) -> void:
	if view != null:
		view.queue_free()
	biome = id
	view = BiomeViewScript.new()
	view.name = "BiomeView_" + id
	add_child(view)
	view.setup(id)
	view.clicked.connect(_on_clicked)
	hud.set_biome(id, view)

func travel(id: String) -> void:
	if _travelling: return
	_travelling = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: _load_biome(id))
	tw.tween_property(_fade, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: _travelling = false)

func _on_clicked(cell: Vector2i, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		if hud.build_type != "": hud.select_build("")
		else: view.select_cell(Vector2i(-1, -1))
		return
	if not Land.in_grid(cell): return
	if hud.build_type != "":
		var reason: String = Sim.place_machine(hud.build_type, biome, cell)
		if reason != "": hud.show_toast(reason, UITheme.BAD)
		elif not Input.is_key_pressed(KEY_SHIFT): hud.select_build("")
		return
	view.select_cell(cell if view.selected_cell != cell else Vector2i(-1, -1))
	hud._inspect_dirty = true

func _process(delta: float) -> void:
	if view == null or Settings.is_open(): return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	view.pan_keys(dir, delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if Settings.is_open(): return
	var k: InputEventKey = event
	if not k.pressed or k.echo: return
	match k.keycode:
		KEY_ESCAPE:
			if hud.build_type != "": hud.select_build("")
			elif Land.in_grid(view.selected_cell): view.select_cell(Vector2i(-1, -1))
			else: _to_menu()
		KEY_Q: view.rotate_view(-1)
		KEY_E: view.rotate_view(1)
		KEY_HOME: view.reset_view()
		KEY_SPACE: hud._set_speed(0.0)
		KEY_V: hud.cycle_view_mode()
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			var i: int = k.keycode - KEY_F1
			if i < Data.biome_order.size(): travel(Data.biome_order[i])
		KEY_F5: Sim.save_game()
		KEY_F9:
			if Sim.load_game(): travel(biome)
		KEY_R:
			var m: Dictionary = Sim.machine_at(biome, view.selected_cell)
			if not m.is_empty(): Sim.cycle_recipe(m.uid)
		KEY_DELETE, KEY_X:
			var m2: Dictionary = Sim.machine_at(biome, view.selected_cell)
			if not m2.is_empty(): Sim.remove_machine(m2.uid)
		_:
			if k.keycode >= KEY_0 and k.keycode <= KEY_9:
				var idx: int = (k.keycode - KEY_1) if k.keycode != KEY_0 else 9
				if idx >= 0 and idx < Data.machine_order.size():
					var id: String = Data.machine_order[idx]
					hud.select_build(id if hud.build_type != id else "")

func _to_menu() -> void:
	Sim.save_game()
	Sim.running = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
