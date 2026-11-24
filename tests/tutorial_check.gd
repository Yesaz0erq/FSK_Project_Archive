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
	Settings.tide_seconds = 30.0
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
	_check(not Sim.is_processing(), "the director is the sole clock owner during guidance")
	_check_clock_controls()

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
	_button(MOUSE_BUTTON_RIGHT, false, game.radial.center + Vector2.UP * 85)
	_check(not game.radial.active and not director.is_armed(), "releasing over a disabled sector cancels the wheel")
	_arm(first)
	_check(overlay._left and overlay._counts.get(first) == "X1", "first placement shows left click X1")
	await _capture("03-placement")
	_click(_point(spare))
	_check(director.stage == stage.FIRST and Sim.count("life") == start_life, "invalid terrain cannot advance or spend a point")
	_check(Sim.growth_at(game.biome, spare).is_empty(), "invalid terrain stays empty")
	_check(director.is_armed(), "an invalid placement keeps Life selected")
	_wait_through_first_tide()
	first = director.hints[0]
	var alternate: Vector2i = director._eligible.filter(func(cell: Vector2i) -> bool: return cell != first)[0]
	_click(_point(alternate))
	first = alternate
	if not _check(director.stage == stage.PAIRS and director.hints.size() == 2, "first Life reveals the two branch parcels"): return
	_check(director.is_armed(), "the tool remains selected after the first placement")
	_check_scripted_pause()
	_check(Sim.count("life") == start_life - 1, "first parcel costs one Life")
	var pair: Array = director.hints.duplicate()
	_check(pair[0] != pair[1] and not pair.has(first), "guide uses three distinct parcels")
	await _capture("04-pair")

	# Exercise either-order support by beginning with the second highlighted parcel.
	for cell: Vector2i in [pair[1], pair[0]]:
		for click in 2:
			_check(director.is_armed(), "Life stays selected between allowed placements")
			if cell == pair[1] and click == 0:
				_check(overlay._left and overlay._counts.get(cell) == "X2", "paired placement shows left click X2")
				await _capture("05-pair-placement")
			_click(_point(cell))
			if cell == pair[1] and click == 0:
				_check(overlay._counts.get(cell) == "X1", "the marker counts down for the partially planted parcel")
				_button(MOUSE_BUTTON_RIGHT, true, _point(cell))
				_button(MOUSE_BUTTON_RIGHT, false, _point(cell))
				_check(not director.is_armed() and not game.radial.active, "a second right press cancels the tool")
				_click(_point(cell))
				_check(Sim.growth_at(game.biome, cell).get("stage") == "phase1", "cancelled tool cannot place")
				_arm(cell)
		_check(Sim.growth_at(game.biome, cell).get("stage") == "phase2_2", "two points choose branch 2-2")
	if not _check(director.stage == stage.WAIT_PROPAGATOR, "both two-point plots enter the first wait"): return
	_check(Sim.count("life") == start_life - 5, "two points spent per paired parcel")
	_check(not Sim.paused and Sim.time_scale == 1.0, "scripted pause releases at 1x")
	_check_clock_controls()
	if not _advance_to(stage.PROPAGATOR_CARD): return
	await _card("propagator", first)
	if not _check(director.stage == stage.THIRD and director.hints.size() == 1, "propagator card reveals third-point target"): return
	var highlighted: Vector2i = director.hints[0]
	var last: Vector2i = pair[0] if highlighted == pair[1] else pair[1]
	var collector: Vector2i = pair[0] if pair[1] == last else pair[1]
	_check(pair.has(last), "third point targets a two-point parcel")
	await _capture("06-third-parcel")
	_check(director.is_armed(), "selection survives the time wait and introduction")
	_check(overlay._left and overlay._counts.get(highlighted) == "X1", "third placement shows left click X1")
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
	_check(Sim.is_processing() and not Sim.paused and Sim.time_scale == 1.0, "free play takes over the clock once at 1x")
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

func _wait_through_first_tide() -> void:
	var previous: Array = director._eligible.duplicate()
	var wave := Land.tide_count
	var before := Sim.count("life")
	_click(game.hud._speed_buttons[3.0].get_global_rect().get_center())
	var time_to_wave := (Settings.tide_seconds - Land.tide_elapsed) / 3.0
	director._process(time_to_wave + Land.GRID * Land.TIDE_ROW_SECONDS + .01)
	_check(Land.tide_count == wave + 1 and Land.tide_state.is_empty(), "the first instruction can wait through an automatic tide at 3x")
	_check(director.is_armed() and not director.hints.is_empty(), "tide refresh preserves the selected Life tool")
	_check(Land.get_parcel(game.biome, director.hints[0]).land == "sheet_grass", "first instruction still highlights current grass after the tide")
	for cell: Vector2i in previous:
		if Land.get_parcel(game.biome, cell).land == "sheet_grass": continue
		_click(_point(cell))
		_check(director.stage == director.Stage.FIRST and Sim.count("life") == before, "grass converted to sand no longer accepts the first point")
		return
	_check(false, "the test tide converted at least one old grass target")

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
	_move(sector)
	_click(sector)
	_check(game.radial.active and not director.is_armed(), "a left click cannot select the open wheel sector")
	_button(MOUSE_BUTTON_RIGHT, false, sector)
	_check(director.is_armed() and not game.radial.active, "right release selects the pointed Life sector")

func _check_clock_controls() -> void:
	var speed_buttons: Dictionary = game.hud._speed_buttons
	for button: Button in speed_buttons.values():
		_check(not button.disabled, "all clock controls work during the first step and growth waits")
	var before := Sim.game_time
	_click(speed_buttons[3.0].get_global_rect().get_center())
	director._process(.25)
	_check(Sim.time_scale == 3.0 and is_equal_approx(Sim.game_time, before + .75), "3x advances the world clock by three simulated seconds per second")
	_click(speed_buttons[0.0].get_global_rect().get_center())
	before = Sim.game_time
	director._process(1.0)
	_check(Sim.paused and Sim.game_time == before, "pause freezes the clock during guidance")
	_click(speed_buttons[1.0].get_global_rect().get_center())
	_check(not Sim.paused and Sim.time_scale == 1.0, "1x resumes guided time")

func _check_scripted_pause() -> void:
	var before := Sim.game_time
	for button: Button in game.hud._speed_buttons.values():
		_check(button.disabled, "clock controls lock for scripted pauses")
	director._process(1.0)
	_check(Sim.paused and Sim.game_time == before, "a scripted pause freezes simulation")

func _advance_to(target: int) -> bool:
	for step in 100:
		if director.stage == target: return true
		director._process(.5)
	return _check(false, "timed stage %d was not reached (current %d)" % [target, director.stage])

func _card(machine: String, cell: Vector2i) -> void:
	if not _check(overlay._card.visible and overlay._intro_cell == cell, "%s card attached to its plot" % machine): return
	_check_scripted_pause()
	_check(Sim.machine_at(game.biome, cell).get("type") == machine, "%s exists when introduced" % machine)
	var expected_count: int = ["propagator", "collector", "extractor"].find(machine) + 1
	_check(Sim.machines.size() == expected_count and Sim.machine_at(game.biome, cell).uid == expected_count, "%s is newly grown and later machines are still seedlings" % machine)
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
