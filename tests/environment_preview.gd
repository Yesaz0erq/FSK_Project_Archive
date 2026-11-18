extends Node

const Flora := preload("res://tests/flora_scene_fixture.gd")
var _destination := OS.get_cache_dir().path_join("ProjectArchive/landscape")
var _game: Node

func _ready() -> void:
	get_window().size = Vector2i(1600,960)
	Settings.autosave_seconds = 0
	Settings.tide_seconds = 0
	Sim.new_game(2026)
	Sim.inventory.life = 40
	Sim.set_process(false)
	for id: String in Data.biome_order: Flora.grow_starters(id)
	_game = preload("res://scenes/game.tscn").instantiate()
	add_child(_game)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): _destination = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(_destination)
	for id: String in Data.biome_order:
		if id != _game.biome: await _game.travel(id)
		await get_tree().create_timer(1.45).timeout
		var view: Node3D = _game.view
		var land: Node3D = view.scenery.land
		assert(view.scenery.env.background_mode == Environment.BG_SKY)
		assert(view._tiles.size() == 121 and land.has_node("Valley"))
		var batches: Array = view.scenery.find_children("*", "MultiMeshInstance3D", true, false)
		assert(batches.size() > 2 and view.scenery.find_children("*", "Sprite3D", true, false).is_empty())
		for cell: Vector2i in [Vector2i(0,4), Vector2i(10,6), Vector2i(5,0), Vector2i(5,10)]:
			var point: Vector3 = view.cell_to_world(cell)
			var axis := Vector2(signf(point.x), 0) if absf(point.x) > absf(point.z) else Vector2(0,signf(point.z))
			var edge: Vector2 = Vector2(point.x,point.z) + axis * (view.TILE * 0.5 + 0.002)
			assert(absf(land.height_at(edge.x,edge.y) - Land.get_parcel(id,cell).height) < 0.012, "boundary height in "+id)
		_game.hud.hide()
		view._zoom_target = 27.0
		await get_tree().create_timer(0.55).timeout
		await _shot(id)
		if id == "forest":
			_game.hud.show()
			await _shot("play")
			_game.hud.hide()
			view.rotate_view(1)
			await get_tree().create_timer(1.15).timeout
			await _shot("forest-turn")
			view._pan = Vector3(-12,0,12)
			view._zoom_target = 32.0
			await get_tree().create_timer(0.75).timeout
			await _shot("forest-limit")
			var cell := Vector2i(6,5)
			view._pan = Vector3.ZERO
			view._zoom_target = 12.0
			await get_tree().create_timer(0.75).timeout
			var location: Vector2 = view.camera.unproject_position(view._tiles[cell].global_position + Vector3.UP*0.31)
			assert(view._pick(location) == cell)
			assert(not Land.in_grid(view._pick(view.camera.unproject_position(Vector3(19,0,0)))))
		print("3D DISTRICT ", id, " · 121 plots / ", batches.size(), " prop batches")
	print("3D DISTRICT CHECK PASSED · ", _destination)
	get_tree().quit()

func _shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := _destination.path_join(id + ".png")
	assert(get_viewport().get_texture().get_image().save_png(path) == OK, "Cannot save screenshot "+path)
