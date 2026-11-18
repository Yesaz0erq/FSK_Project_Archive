extends Node
func _ready() -> void:
	get_window().size = Vector2i(1600, 960)
	Sim.new_game(2026)
	Sim.paused = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	var view: Node3D = game.view
	assert(view._tiles.size() == 121)
	assert(view._tiles[Vector2i(0, 0)].position.y < view._tile_heights[Vector2i(0, 0)] - 0.6)
	for b: String in Data.biome_order:
		var river: Dictionary = {}
		for y in range(11):
			var count: int = 0
			for x in range(11):
				var p: Dictionary = Land.get_parcel(b, Vector2i(x,y))
				if p.land == "sheet_river":
					river[Vector2i(x,y)] = true
					count += 1
			assert(count > 0)
		var pending: Array = [river.keys()[0]]
		var visited: Dictionary = {}
		while not pending.is_empty():
			var c: Vector2i = pending.pop_back()
			if visited.has(c): continue
			visited[c] = true
			for dir: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if river.has(c + dir) and not visited.has(c + dir): pending.append(c + dir)
		assert(visited.size() == river.size())
	await get_tree().create_timer(1.6).timeout
	var cell := Vector2i(3,4)
	var rest: float = view._tiles[cell].position.y
	view.select_cell(cell)
	await get_tree().create_timer(0.35).timeout
	assert(view._tiles[cell].position.y > rest + 0.3)
	assert(view._tile_mats[cell].emission_enabled)
	var screen: Vector2 = view.camera.unproject_position(view._tiles[cell].global_position + Vector3(0,0.31,0))
	assert(view._pick(screen) == cell)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/board-motion-preview.png")
	view.select_cell(Vector2i(-1,-1))
	await get_tree().create_timer(0.35).timeout
	assert(absf(view._tiles[cell].position.y - rest) < 0.02)
	print("BOARD CHECK OK: 121 blocks, connected central river, entry wave, raised selection, highlight, picking, deselection")
	get_tree().quit()
