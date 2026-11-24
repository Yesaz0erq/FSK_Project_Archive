extends Node
var game: Node
const CELL := Vector2i(5, 5)
const OTHER := Vector2i(4, 5)
var buttons := 0
var uid: int
func _ready() -> void:
	get_window().size = Vector2i(1600,960)
	Settings.autosave_seconds = 0
	Sim.new_game(2026)
	Sim.paused = true
	Sim.money = 5000
	Sim.reputation = 30
	for id: String in Data.items: Sim.inventory[id] = 100
	Land.restore_terrain({Land.parcel_key("forest", CELL): "sheet_grass", Land.parcel_key("forest", OTHER): "sheet_grass"})
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	get_tree().create_timer(30).timeout.connect(func() -> void: get_tree().quit(1))
	assert(Sim.add_life_point("forest", CELL) == "")
	Sim._tick_life_growth(15.0)
	uid = int(Sim.machine_at("forest", CELL).uid)
	await get_tree().create_timer(1.7).timeout
	_open()
	assert(game.radial.active)
	assert(game._context_uid == uid)
	_click(game.hud._speed_buttons[3.0].get_global_rect().get_center())
	assert(not Sim.paused and Sim.time_scale == 3.0 and game.radial.active)
	_click(game.hud._speed_buttons[0.0].get_global_rect().get_center())
	assert(Sim.paused and game.radial.active)
	_click(game.hud._speed_buttons[1.0].get_global_rect().get_center())
	assert(not Sim.paused and Sim.time_scale == 1.0 and game.radial.active)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	get_viewport().push_input(space, true)
	space.pressed = false
	get_viewport().push_input(space, true)
	assert(Sim.paused and game.radial.active)
	_click(_point(OTHER))
	assert(game.view.selected_cell == CELL and game.radial.active, "The open wheel must intercept board clicks")
	_drag(Vector2.UP * 90)
	_release(Vector2.UP * 90)
	assert(not game.radial.active and game.hud._tabs.current_tab == 0)
	_open()
	_release(Vector2.ZERO)
	assert(Sim.machines[uid].enabled)
	_open()
	_drag(Vector2.LEFT * 90)
	_release(Vector2.LEFT * 90)
	assert(not Sim.machines[uid].enabled)
	_open()
	_drag(Vector2.RIGHT * 90)
	_release(Vector2.RIGHT * 90)
	assert(game.pause_menu.active and game.pause_menu._preview_id == "propagator")
	game.pause_menu.close()
	_open()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	assert(not game.radial.active)
	_release(Vector2.ZERO)
	assert(Sim.machines.has(uid))
	var life_before_dismantle := Sim.count("life")
	_open()
	_drag(Vector2.DOWN * 90)
	_release(Vector2.DOWN * 90)
	assert(not Sim.machines.has(uid))
	assert(Sim.count("life") == life_before_dismantle + 1)
	var ember := Sim.count("ember")
	_open()
	_drag(Vector2.LEFT * 180)
	_release(Vector2.LEFT * 180)
	assert(Sim.count("ember") == ember, "A release beyond the drawn sector must cancel")
	_open()
	_drag(Vector2.LEFT * 90)
	_release(Vector2.LEFT * 90)
	assert(Sim.count("ember") == ember + 1)
	_open()
	assert(game.radial.options[2].action == "clear" and game.radial.options[2].enabled)
	_drag(Vector2.DOWN * 90)
	_release(Vector2.DOWN * 90)
	assert(Land.get_parcel("forest", CELL).attachment_cleared)
	_open()
	assert(game.radial.options[1].action == "plant")
	var before := Sim.count("life")
	_drag(Vector2.RIGHT * 90)
	_click(game.radial.center + Vector2.RIGHT * 90)
	assert(game.radial.active)
	_release(Vector2.RIGHT * 90)
	assert(Sim.growth_at("forest", CELL).is_empty() and Sim.count("life") == before, "Selecting Life must only arm placement")
	_click(_point(OTHER))
	assert(Sim.growth_at("forest", OTHER).stage == "phase1" and Sim.count("life") == before - 1)
	_click(_point(CELL))
	assert(Sim.growth_at("forest", CELL).stage == "phase1" and Sim.count("life") == before - 2)
	_button(MOUSE_BUTTON_RIGHT, true, _point(CELL))
	assert(not game.radial.active, "Cancel must not open another wheel")
	_release(Vector2.RIGHT * 90)
	_click(_point(CELL))
	assert(Sim.growth_at("forest", CELL).stage == "phase1" and Sim.count("life") == before - 2)
	Sim.inventory["life"] = 0
	_open()
	assert(not game.radial.options[1].enabled)
	assert(not game.radial.options[2].enabled)
	_drag(Vector2.RIGHT * 90)
	_release(Vector2.RIGHT * 90)
	assert(not game.radial.active)
	Sim._tick_life_growth(15.0)
	game.view.select_cell(OTHER)
	var delete_key := InputEventKey.new()
	delete_key.keycode = KEY_DELETE
	delete_key.pressed = true
	get_viewport().push_input(delete_key, true)
	assert(Sim.machine_at("forest", OTHER).is_empty() and Sim.count("life") == 1)
	get_viewport().push_input(delete_key, true)
	assert(Sim.count("life") == 1)
	print("RADIAL CHECK OK: board input, four sectors, release selection, two consecutive target plots, right cancel, disabled options")
	get_tree().quit()

func _open() -> void:
	_button(MOUSE_BUTTON_RIGHT, true, _point(CELL))

func _point(cell: Vector2i) -> Vector2:
	return game.view.camera.unproject_position(game.view._tiles[cell].global_position + Vector3(0,0.31,0))

func _button(button: MouseButton, pressed: bool, point: Vector2) -> void:
	var bit := 1 << (button - 1)
	buttons = (buttons | bit) if pressed else (buttons & ~bit)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.button_mask = buttons as MouseButtonMask
	event.pressed = pressed
	event.position = point
	event.global_position = point
	get_viewport().push_input(event, true)

func _click(point: Vector2) -> void:
	_button(MOUSE_BUTTON_LEFT, true, point)
	_button(MOUSE_BUTTON_LEFT, false, point)

func _drag(offset: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = game.radial.center + offset
	event.global_position = event.position
	event.button_mask = buttons as MouseButtonMask
	get_viewport().push_input(event, true)

func _release(offset: Vector2) -> void:
	_button(MOUSE_BUTTON_RIGHT, false, game.radial.center + offset)
