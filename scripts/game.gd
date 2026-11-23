extends Node
## Game scene: owns the current BiomeView and the HUD, handles travel between the four scenes.

const BiomeViewScript := preload("res://scripts/world/biome_view.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PauseScript := preload("res://scripts/ui/pause_menu.gd")
const RadialScript := preload("res://scripts/ui/radial_menu.gd")
const TutorialDirector := preload("res://scripts/tutorial/tutorial_director.gd")
const TutorialOverlay := preload("res://scripts/tutorial/tutorial_overlay.gd")

@export var tutorial_mode := false
var tutorial: Node
var tutorial_overlay: Control

var hud: CanvasLayer
var view: Node3D
var biome: String = "forest"
var _fade: ColorRect
var _transition := ShaderMaterial.new()
var _arrival: Tween
var _travelling: bool = false
var pause_menu: Control
var radial: Control
var _context_cell := Vector2i(-1,-1)
var _context_uid: int = -1

func _ready() -> void:
	if tutorial_mode:
		Sim.start_tutorial()
	elif not Sim.running:
		Sim.new_game(randi() % 1000000)
	hud = HudScript.new()
	add_child(hud)
	hud.travel_requested.connect(travel)
	hud.menu_requested.connect(_open_pause)
	var context_layer := CanvasLayer.new()
	context_layer.layer = 30
	add_child(context_layer)
	radial = RadialScript.new()
	context_layer.add_child(radial)
	radial.chosen.connect(_context_action)
	if tutorial_mode:
		tutorial = TutorialDirector.new()
		add_child(tutorial)
		var guide_layer := CanvasLayer.new()
		guide_layer.layer = 31
		add_child(guide_layer)
		tutorial_overlay = TutorialOverlay.new()
		guide_layer.add_child(tutorial_overlay)
		radial.dismissed.connect(tutorial.cancel_selection)
		tutorial.finished.connect(_on_tutorial_finished)
		hud.set_tutorial_guidance(true)
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 40
	add_child(pause_layer)
	pause_menu = PauseScript.new()
	pause_menu.allow_save = not tutorial_mode
	pause_layer.add_child(pause_menu)
	pause_menu.return_to_title.connect(_to_menu)
	var fl := CanvasLayer.new()
	fl.layer = 20
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color.WHITE
	_transition.shader = preload("res://assets/shaders/region_transition.gdshader")
	_fade.material = _transition
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	_load_biome(biome)
	_arrival = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_arrival.tween_property(_fade, "color:a", 0.0, 0.6)
	if tutorial_mode:
		view.set_growth_labels_visible(false)
		tutorial_overlay.setup(view, radial)
		# The last row finishes its staggered rise 1.36 seconds after scene entry.
		_arrival.tween_interval(0.77)
		_arrival.tween_callback(tutorial.start.bind(biome, tutorial_overlay))

func _on_tutorial_finished() -> void:
	view.set_growth_labels_visible(true)
	hud.set_tutorial_guidance(false)

func _guiding() -> bool:
	return tutorial_mode and is_instance_valid(tutorial) and not tutorial.is_complete()

func _exit_tree() -> void:
	if tutorial_mode:
		if is_instance_valid(tutorial): tutorial.stop()
		Sim.running = false
		Sim.tutorial_session = false

func _load_biome(id: String) -> void:
	if view != null:
		remove_child(view)
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
	if _travelling or _guiding(): return
	radial.cancel()
	_travelling = true
	if _arrival: _arrival.kill()
	_transition.set_shader_parameter("glimmer", Data.palette(id, "accent"))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	_load_biome(id)
	var reveal := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(_fade, "color:a", 0.0, 0.45)
	await reveal.finished
	_travelling = false

func _on_clicked(cell: Vector2i, button: int) -> void:
	if _guiding():
		if button == MOUSE_BUTTON_LEFT and tutorial.is_armed() and Land.in_grid(cell) and not pause_menu.active:
			tutorial.place_at(cell)
		return
	if button == MOUSE_BUTTON_RIGHT:
		if hud.build_type != "": hud.select_build("")
		else: view.select_cell(Vector2i(-1, -1))
		return
	if not Land.in_grid(cell): return
	if pause_menu.active: return
	view.select_cell(cell if view.selected_cell != cell else Vector2i(-1, -1))
	hud._inspect_dirty = true

func _process(delta: float) -> void:
	if view == null or Settings.is_open() or radial.active or pause_menu.active or _guiding(): return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	view.pan_keys(dir, delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if Settings.is_open() or pause_menu.active: return
	var k: InputEventKey = event
	if not k.pressed or k.echo: return
	if _guiding():
		if k.keycode == KEY_ESCAPE:
			if tutorial.is_armed(): tutorial.cancel_selection()
			else: _open_pause()
		get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_ESCAPE: _open_pause()
		KEY_Q: view.rotate_view(-1)
		KEY_E: view.rotate_view(1)
		KEY_HOME: view.reset_view()
		KEY_SPACE: hud._set_speed(0.0)
		KEY_V: hud.cycle_view_mode()
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			var i: int = k.keycode - KEY_F1
			if i < Data.biome_order.size(): travel(Data.biome_order[i])
		KEY_F5:
			if not tutorial_mode: Sim.save_game()
		KEY_F9:
			if not tutorial_mode and Sim.load_game(): travel(biome)
		KEY_DELETE, KEY_X:
			var m2: Dictionary = Sim.machine_at(biome, view.selected_cell)
			if not m2.is_empty(): Sim.remove_machine(m2.uid)

func _to_menu() -> void:
	radial.cancel()
	if not tutorial_mode: Sim.save_game()
	Sim.running = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _open_context(cell: Vector2i, point: Vector2) -> void:
	if _travelling or Settings.is_open() or pause_menu.active: return
	if _guiding():
		if tutorial.is_armed():
			tutorial.cancel_selection()
			return
		if Land.in_grid(cell) and tutorial.open_menu(cell):
			var label := "投放生灵点" if Settings.language == "zh_CN" else "Plant Life"
			radial.open_at(point, [
				{"label": tr("Inspect"), "action": "inspect", "enabled": false},
				{"label": label, "action": "plant", "enabled": true},
				{"label": tr("Condense Life"), "action": "life", "enabled": false},
				{"label": tr("Condense Ember"), "action": "ember", "enabled": false},
			], true)
		return
	if not Land.in_grid(cell): return
	_context_cell = cell
	var machine: Dictionary = Sim.machine_at(biome, cell)
	_context_uid = int(machine.get("uid", -1))
	if hud.build_type != "": hud.select_build("")
	view.select_cell(cell)
	view._set_hover(Vector2i(-1,-1))
	hud._inspect_dirty = true
	var entries: Array = [{"label": tr("Inspect"), "action": "inspect", "enabled": true}]
	if not machine.is_empty():
		entries.append({"label": "图鉴" if Settings.language == "zh_CN" else "Codex", "action": "codex", "enabled": true})
		entries.append({"label": tr("Dismantle"), "action": "dismantle", "enabled": true})
		entries.append({"label": tr("Pause") if machine.enabled else tr("Resume"), "action": "toggle", "enabled": true})
	else:
		var parcel: Dictionary = Land.get_parcel(biome, cell)
		var planting := Sim.growth_at(biome, cell).is_empty()
		var label := ("投放生灵点" if planting else "追加生灵点") if Settings.language == "zh_CN" else ("Plant Life" if planting else "Add Life")
		entries.append({"label": label, "action": "plant", "enabled": Sim.can_add_life(biome, cell) == ""})
		entries.append({"label": tr("Condense Life"), "action": "life", "enabled": float(parcel.elements.life) >= 20.0})
		entries.append({"label": tr("Condense Ember"), "action": "ember", "enabled": float(parcel.elements.ember) >= 20.0})
	radial.open_at(point, entries)

func _context_action(action: String) -> void:
	if _guiding():
		if action == "plant": tutorial.arm_life()
		return
	if not Land.in_grid(_context_cell): return
	var machine: Dictionary = Sim.machine_at(biome, _context_cell)
	if action in ["codex", "dismantle", "toggle"]:
		if machine.is_empty() or int(machine.uid) != _context_uid: return
	match action:
		"inspect":
			view.select_cell(_context_cell)
			hud._tabs.current_tab = 0
		"codex":
			pause_menu.open()
			pause_menu.open_codex()
			pause_menu._show_machine(machine.type)
		"dismantle": Sim.remove_machine(_context_uid)
		"toggle": Sim.toggle_enabled(_context_uid)
		"plant":
			var reason: String = Sim.add_life_point(biome,_context_cell)
			if reason != "": hud.show_toast(reason,UITheme.BAD)
		"clear": Land.clear_attachment(biome, _context_cell)
		"life", "ember": Sim.condense(biome, _context_cell, action)
	hud._inspect_dirty = true

func _open_pause() -> void:
	radial.cancel()
	if _guiding() and tutorial.is_armed(): tutorial.cancel_selection()
	pause_menu.open()
