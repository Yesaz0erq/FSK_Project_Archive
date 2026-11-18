extends Node
var game: Node
var cell := Vector2i(3,4)
var uid: int
func _ready() -> void:
	get_window().size = Vector2i(1600,960)
	Settings.autosave_seconds = 0
	Sim.new_game(2026)
	Sim.paused = true
	Sim.money = 5000
	Sim.reputation = 30
	for id: String in Data.items: Sim.inventory[id] = 100
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for y in Land.GRID:
		for x in Land.GRID:
			var candidate := Vector2i(x, y)
			if Sim.can_add_life("forest", candidate) == "" and Sim.machine_site_reason("propagator", "forest", candidate) == "":
				cell = candidate
				break
		if cell.y == y and Sim.can_add_life("forest", cell) == "" and Sim.machine_site_reason("propagator", "forest", cell) == "": break
	assert(Sim.add_life_point("forest", cell) == "")
	Sim._tick_life_growth(15.0)
	uid = int(Sim.machine_at("forest",cell).uid)
	await get_tree().create_timer(1.7).timeout
	_open()
	assert(game.radial.active)
	assert(game._context_uid == uid)
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
	game.radial._input(escape)
	assert(not game.radial.active)
	assert(Sim.machines.has(uid))
	_open()
	_drag(Vector2.DOWN * 90)
	_release(Vector2.DOWN * 90)
	assert(not Sim.machines.has(uid))
	_open()
	assert(game.radial.options[1].action == "plant")
	_drag(Vector2.RIGHT * 90)
	_release(Vector2.RIGHT * 90)
	assert(Sim.growth_at("forest",cell).stage == "phase1")
	Sim._tick_life_growth(5.0)
	_open()
	assert(not game.radial.options[1].enabled)
	_drag(Vector2.RIGHT * 90)
	_release(Vector2.RIGHT * 90)
	assert(not game.radial.active)
	print("RADIAL CHECK OK: view input, four directions, release execution, center cancel, Esc cancel, disabled options, empty plot actions")
	get_tree().quit()

func _open() -> void:
	var point: Vector2 = game.view.camera.unproject_position(game.view._tiles[cell].global_position + Vector3(0,0.31,0))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = point
	game.view._unhandled_input(event)

func _drag(offset: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = game.radial.center + offset
	game.radial._input(event)

func _release(offset: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = false
	event.position = game.radial.center + offset
	game.radial._input(event)
