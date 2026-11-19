extends Node

const GAME := preload("res://scenes/game.tscn")
var _output := ""
var _game: Node

func _ready() -> void:
	var seed_value := 2026
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): _output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--seed="): seed_value = arg.trim_prefix("--seed=").to_int()
	if not _output.is_empty(): DirAccess.make_dir_recursive_absolute(_output)
	Settings.tide_seconds = 0.0
	Settings.autosave_seconds = 0.0
	Sim.new_game(seed_value)
	Sim.set_process(false)
	get_window().size = Vector2i(1600,960)
	_game = GAME.instantiate()
	add_child(_game)
	_game.hud.hide()
	await get_tree().create_timer(1.6).timeout
	var high := _check_mouths(false)
	await _shot("full")
	for stage in ["ebb", "refill"]:
		Land.start_tide()
		Land.tick(Land.TIDE_ROW_SECONDS * Land.GRID + 0.001)
		await get_tree().create_timer(1.35).timeout
		assert(_game.view._tide_tweens.is_empty())
		var levels := _check_mouths(stage == "ebb")
		if stage == "refill": assert(levels == high)
		if stage == "ebb": await _shot(stage)
	print("RIVER LANDSCAPE OK · seed=", seed_value, " · ", Land.river_mouths.forest)
	get_tree().quit()

func _check_mouths(ebb: bool) -> Array:
	var view: Node3D = _game.view
	var terrain: Node3D = view.scenery.land
	var fence: MeshInstance3D = view.scenery.get_node("WorkspaceFence")
	assert(fence.mesh.get_surface_count() == 1)
	var levels := []
	for mouth: Dictionary in Land.river_mouths.forest:
		var border := 0 if mouth.edge in [0, 2] else Land.GRID - 1
		var outward: Vector2 = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][mouth.edge]
		var kinds := {}
		for lane in range(mouth.first, mouth.last + 1):
			var cell := Vector2i(border, lane) if mouth.edge < 2 else Vector2i(lane, border)
			var p: Dictionary = Land.get_parcel("forest", cell)
			var tile: MeshInstance3D = view._tiles[cell]
			assert(tile.get_meta("land_id") == p.land)
			assert(tile.mesh.resource_name == str(p.land) + "_six_faces")
			kinds[p.land] = true
			levels.append(p.land)
			var center: Vector3 = view.cell_to_world(cell)
			var lip: Vector2 = Vector2(center.x, center.z) + outward * (view.TILE * .5 + .002)
			assert(absf(terrain.height_at(lip.x, lip.y) - p.height) < .012)
			var wet: bool = p.land != "sheet_riverbed"
			assert(terrain.is_water_at(lip.x, lip.y) == wet)
			# Follow this lane along the curved course to a point beyond the collar.
			var axis: float = -1.0 if border == 0 else 1.0
			var distant: Vector2 = terrain.river_span_at(axis * (terrain.EDGE + 8.0))
			var t := (lane - int(mouth.first) + .5) / (int(mouth.last) - int(mouth.first) + 1)
			if mouth.edge < 2: t = 1.0 - t
			var point := terrain.to_global(Vector3(lerpf(distant.x, distant.y, t), 0, axis * (terrain.EDGE + 8.0)))
			assert(terrain.is_water_at(point.x, point.z) == wet)
		if ebb: assert(kinds.has("sheet_river_low") and kinds.has("sheet_riverbed"))
		else: assert(kinds.keys() == ["sheet_river"])
	return levels

func _shot(stage: String) -> void:
	if _output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var file := _output.path_join("%d-%s.png" % [Land.world_seed, stage])
	assert(get_viewport().get_texture().get_image().save_png(file) == OK)
