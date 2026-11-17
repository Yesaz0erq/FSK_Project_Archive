extends Node
## Game scene: owns the current BiomeView and the HUD, handles travel between the four scenes.

const BiomeViewScript := preload("res://scripts/world/biome_view.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const RadialScript := preload("res://scripts/ui/radial_menu.gd")

var hud: CanvasLayer
var view: Node3D
var biome: String = "forest"
var _fade: ColorRect
var _travelling: bool = false
var radial: Control
var _context_cell := Vector2i(-1,-1)
var _context_uid: int = -1

func _ready() -> void:
	if not Sim.running:
		Sim.new_game(randi() % 1000000)
	hud = HudScript.new()
	add_child(hud)
	hud.travel_requested.connect(travel)
	hud.menu_requested.connect(_to_menu)
	var context_layer := CanvasLayer.new()
	context_layer.layer = 30
	add_child(context_layer)
	radial = RadialScript.new()
	context_layer.add_child(radial)
	radial.chosen.connect(_context_action)
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
	view.context_requested.connect(_open_context)
	hud.set_biome(id, view)

func travel(id: String) -> void:
	if _travelling: return
	radial.cancel()
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
	if view == null or Settings.is_open() or radial.active: return
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
	radial.cancel()
	Sim.save_game()
	Sim.running = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _open_context(cell: Vector2i, point: Vector2) -> void:
	if _travelling or Settings.is_open() or not Land.in_grid(cell): return
	_context_cell = cell
	var machine: Dictionary = Sim.machine_at(biome, cell)
	_context_uid = int(machine.get("uid", -1))
	if hud.build_type != "": hud.select_build("")
	view.select_cell(cell)
	view._set_hover(Vector2i(-1,-1))
	hud._inspect_dirty = true
	var entries: Array = [{"label": tr("Inspect"), "action": "inspect", "enabled": true}]
	if not machine.is_empty():
		entries.append({"label": tr("Next recipe"), "action": "recipe", "enabled": Data.machines[machine.type].get("recipes", []).size() > 1})
		entries.append({"label": tr("Dismantle"), "action": "dismantle", "enabled": true})
		entries.append({"label": tr("Pause") if machine.enabled else tr("Resume"), "action": "toggle", "enabled": true})
	else:
		var parcel: Dictionary = Land.get_parcel(biome, cell)
		entries.append({"label": tr("Clear attachment"), "action": "clear", "enabled": str(parcel.sheet.get("attachment", "/")) != "/" and not parcel.attachment_cleared})
		entries.append({"label": tr("Condense Life"), "action": "life", "enabled": float(parcel.elements.life) >= 20.0})
		entries.append({"label": tr("Condense Ember"), "action": "ember", "enabled": float(parcel.elements.ember) >= 20.0})
	radial.open_at(point, entries)

func _context_action(action: String) -> void:
	if not Land.in_grid(_context_cell): return
	var machine: Dictionary = Sim.machine_at(biome, _context_cell)
	if action in ["recipe", "dismantle", "toggle"]:
		if machine.is_empty() or int(machine.uid) != _context_uid: return
	match action:
		"inspect":
			view.select_cell(_context_cell)
			hud._tabs.current_tab = 0
		"recipe": Sim.cycle_recipe(_context_uid)
		"dismantle": Sim.remove_machine(_context_uid)
		"toggle": Sim.toggle_enabled(_context_uid)
		"clear": Land.clear_attachment(biome, _context_cell)
		"life", "ember": Sim.condense(biome, _context_cell, action)
	hud._inspect_dirty = true
