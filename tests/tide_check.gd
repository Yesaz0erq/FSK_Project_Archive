extends Node
var events: int = 0
var last_row: int = -1
func _ready() -> void:
	Sim.new_game(2026)
	Sim.paused = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	Land.tide_tile_changed.connect(_changed)
	Land.start_tide()
	var edge: int = int(Land.tide_state.edge)
	for row in range(11):
		last_row = row
		Land.tick(0.71)
		await get_tree().process_frame
	assert(Land.tide_state.is_empty())
	assert(events > 0)
	for b: String in Data.biome_order:
		for y in range(11):
			for x in range(11):
				var p: Dictionary = Land.get_parcel(b, Vector2i(x, y))
				assert(p.land != "sheet_burnt")
	var saved: Dictionary = Land.terrain_overrides.duplicate()
	Land.generate(2026)
	Land.restore_terrain(saved)
	assert(Land.terrain_overrides == saved)
	Sim.paused = false
	await get_tree().create_timer(1.0).timeout
	assert(game.view._tide_tweens.is_empty())
	print("TIDE CHECK OK: edge=", edge, ", eligible flips=", events, ", matching base/level, traversal, restore, animation completed")
	get_tree().quit()

func _changed(b: String, c: Vector2i, old_id: String, next_id: String, edge: int) -> void:
	var old: Dictionary = Data.land_types[old_id].sheet
	var next: Dictionary = Data.land_types[next_id].sheet
	assert(old.tide == "翻转")
	assert(old.base == next.base and str(old.level) == str(next.level))
	var row: int = c.x if edge == 0 else (10 - c.x if edge == 1 else (c.y if edge == 2 else 10 - c.y))
	assert(row == last_row)
	assert(Land.get_parcel(b, c).land == next_id)
	events += 1
