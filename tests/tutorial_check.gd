extends Node

var game: Node
var director: Node
var overlay: Control
var buttons := 0
var failed := false
var output_dir := ""

func _ready() -> void:
	get_window().size = Vector2i(1600, 960)
	Settings.autosave_seconds = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir=") and DisplayServer.get_name() != "headless":
			output_dir = arg.trim_prefix("--output-dir=")
			_check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "create screenshot directory")
	get_tree().create_timer(40.0).timeout.connect(func() -> void: _check(false, "tutorial check timed out"))
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/tutorial.tscn").instantiate()
	add_child(game)
	director = game.tutorial
	overlay = game.tutorial_overlay
	for frame in 480:
		if not director.hints.is_empty(): break
		await get_tree().process_frame
	if not _check(director.hints.size() == 1, "arrival gives one highlighted parcel"): return
	await _capture("01-first-parcel")
	var first: Vector2i = director.hints[0]
	var spare := _other_visible_cell()
	var start_life := Sim.count("life")
	var stage = director.Stage

	_click(_point(first))
	_button(MOUSE_BUTTON_RIGHT, true, _point(spare))
	_check(game.radial.active, "holding right on an unmarked parcel also opens the wheel")
	_button(MOUSE_BUTTON_RIGHT, false, _point(spare))
	_check(not game.radial.active and not director.is_armed(), "right release dismisses the wheel")
	_check(Sim.count("life") == start_life and Sim.growth_at(game.biome, first).is_empty(), "left click alone cannot plant")

	_open(first)
	if DisplayServer.get_name() != "headless":
		await _check_optional_icons()
	await _capture("02-wheel")
	_click(game.radial.center + Vector2.UP * 85)
	_check(not director.is_armed(), "disabled sector cannot arm Life")
	_move(game.radial.center + Vector2.RIGHT * 85)
	_button(MOUSE_BUTTON_RIGHT, false, game.radial.center + Vector2.RIGHT * 85)
	_check(not game.radial.active and not director.is_armed(), "right release alone cancels the wheel")
	_arm(first)
	_check(overlay._left and overlay._count == "X1", "first placement shows left click X1")
	await _capture("03-placement")
	_click(_point(spare))
	_check(director.stage == stage.FIRST and Sim.count("life") == start_life, "invalid terrain cannot advance or spend a point")
	_check(Sim.growth_at(game.biome, spare).is_empty(), "invalid terrain stays empty")
	if not director.is_armed(): _arm(first)
	var alternate: Vector2i = director._eligible.filter(func(cell: Vector2i) -> bool: return cell != first)[0]
	_click(_point(alternate))
	first = alternate
	if not _check(director.stage == stage.PAIRS and director.hints.size() == 2, "first Life reveals the two branch parcels"): return
	_check(Sim.count("life") == start_life - 1, "first parcel costs one Life")
	var pair: Array = director.hints.duplicate()
	_check(pair[0] != pair[1] and not pair.has(first), "guide uses three distinct parcels")
	await _capture("04-pair")

	# Exercise either-order support by beginning with the second highlighted parcel.
	for cell: Vector2i in [pair[1], pair[0]]:
		for click in 2:
			if not director.is_armed(): _arm(cell)
			if cell == pair[1] and click == 0:
				_check(overlay._left and overlay._count == "X2", "paired placement shows left click X2")
				await _capture("05-pair-placement")
			_click(_point(cell))
		_check(Sim.growth_at(game.biome, cell).get("stage") == "phase2_2", "two points choose branch 2-2")
	if not _check(director.stage == stage.WAIT_PROPAGATOR, "both two-point plots enter the first wait"): return
	_check(Sim.count("life") == start_life - 5, "two points spent per paired parcel")
	if not _advance_to(stage.PROPAGATOR_CARD): return
	await _card("propagator", first)
	if not _check(director.stage == stage.THIRD and director.hints.size() == 1, "propagator card reveals third-point target"): return
	var highlighted: Vector2i = director.hints[0]
	var last: Vector2i = pair[0] if highlighted == pair[1] else pair[1]
	var collector: Vector2i = pair[0] if pair[1] == last else pair[1]
	_check(pair.has(last), "third point targets a two-point parcel")
	await _capture("06-third-parcel")
	if not director.is_armed(): _arm(last)
	_check(overlay._left and overlay._count == "X1", "third placement shows left click X1")
	_click(_point(last))
	_check(Sim.growth_at(game.biome, last).get("stage") == "phase3_2", "third point chooses branch 3-2")
	if not _check(director.stage == stage.WAIT_COLLECTOR, "third point starts collector wait"): return
	_check(Sim.count("life") == start_life - 6, "guided branches cost six points")
	if not _advance_to(stage.COLLECTOR_CARD): return
	await _card("collector", collector)
	if not _check(director.stage == stage.WAIT_EXTRACTOR, "collector card leads to extractor wait"): return
	if not _advance_to(stage.EXTRACTOR_CARD): return
	await _card("extractor", last)
	_check(director.stage == stage.COMPLETE and director.is_complete(), "last card completes the guide")
	_check(Sim.machines.size() == 3, "all three field machines exist")
	_check(not overlay._card.visible and game.view._show_growth_labels, "free-play presentation restored")
	if not failed:
		print("TUTORIAL CHECK OK: viewport mouse gestures, invalid actions, six placements, all three branches and cards, free play")
	get_tree().quit(1 if failed else 0)

func _point(cell: Vector2i) -> Vector2:
	var tile: MeshInstance3D = game.view._tiles[cell]
	return game.view.camera.unproject_position(tile.to_global(Vector3(0, .31, 0)))

func _check_optional_icons() -> void:
	var saved: Array = game.radial.options.duplicate(true)
	for entry: Dictionary in saved:
		_check(entry.get("icon") is Texture2D, "each tutorial sector supplies its intended artwork")
	# Exercise the renderer with a missing icon, explicit null and an invalid value.
	# Keep the active Life sector intact so it still draws alongside these entries.
	game.radial.options[0].erase("icon")
	game.radial.options[2]["icon"] = null
	game.radial.options[3]["icon"] = "ember"
	game.radial.queue_redraw()
	await RenderingServer.frame_post_draw
	game.radial.options = saved
	game.radial.queue_redraw()

func _other_visible_cell() -> Vector2i:
	for cell: Vector2i in game.view._tiles:
		if Land.get_parcel(game.biome, cell).land == "sheet_grass": continue
		var point := _point(cell)
		if not director.hints.has(cell) and get_viewport().get_visible_rect().grow(-160).has_point(point) and game.view._pick(point) == cell:
			return cell
	_check(false, "another visible parcel exists for rejection test")
	return Vector2i.ZERO

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

func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.button_mask = buttons as MouseButtonMask
	get_viewport().push_input(motion, true)

func _click(point: Vector2) -> void:
	_move(point)
	_button(MOUSE_BUTTON_LEFT, true, point)
	_button(MOUSE_BUTTON_LEFT, false, point)

func _open(cell: Vector2i) -> void:
	var point := _point(cell)
	_move(point)
	_button(MOUSE_BUTTON_RIGHT, true, point)
	_check(game.radial.active, "holding right on %s opens the wheel" % cell)

func _arm(cell: Vector2i) -> void:
	_open(cell)
	var sector: Vector2 = game.radial.center + Vector2.RIGHT * 85
	_click(sector)
	_button(MOUSE_BUTTON_RIGHT, false, sector)
	_check(director.is_armed() and not game.radial.active, "left sector selection arms a placement through right release")

func _advance_to(target: int) -> bool:
	for step in 100:
		if director.stage == target: return true
		director._process(.5)
	return _check(false, "timed stage %d was not reached (current %d)" % [target, director.stage])

func _card(machine: String, cell: Vector2i) -> void:
	if not _check(overlay._card.visible and overlay._intro_cell == cell, "%s card attached to its plot" % machine): return
	_check(Sim.machine_at(game.biome, cell).get("type") == machine, "%s exists when introduced" % machine)
	_check(overlay._title.text == tr(str(Data.machines[machine].name)), "%s card title" % machine)
	_check(overlay._description.text == tr(str(Data.machines[machine].description)), "%s card description" % machine)
	_check(overlay._portrait.texture == Art.machine(machine), "%s card artwork" % machine)
	await _capture(machine + "-card")
	var card: Control = overlay._card
	var outside := Vector2(8, get_viewport().get_visible_rect().size.y - 8)
	_click(outside)
	_check(card.visible, "clicking outside leaves the %s card visible" % machine)
	_click(card.get_global_rect().get_center())
	_check(not card.visible, "click dismisses the %s card" % machine)

func _capture(label: String) -> void:
	if output_dir.is_empty(): return
	# Capture the settled guide after the wheel's reveal tween.
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(output_dir.path_join(label + ".png")) == OK, "capture " + label)

func _check(ok: bool, description: String) -> bool:
	if not ok:
		failed = true
		push_error("TUTORIAL CHECK FAILED: " + description)
		get_tree().quit(1)
	return ok
