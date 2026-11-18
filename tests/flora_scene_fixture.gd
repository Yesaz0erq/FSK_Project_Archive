extends RefCounted

## Grow the three starter machines on naturally eligible plots near the camera center.
static func grow_starters(biome: String) -> Dictionary:
	var anchors := {"propagator": Vector2i(3, 4), "collector": Vector2i(6, 4), "extractor": Vector2i(5, 7)}
	var placements := {}
	for id: String in anchors:
		var anchor: Vector2i = anchors[id]
		var nearest := Vector2i(-1, -1)
		var distance := Land.GRID * Land.GRID * 2
		for y in range(1, Land.GRID - 1):
			for x in range(1, Land.GRID - 1):
				var cell := Vector2i(x, y)
				if cell.distance_squared_to(anchor) >= distance or not Sim.growth_at(biome, cell).is_empty(): continue
				if Sim.can_add_life(biome, cell) != "" or Sim.machine_site_reason(id, biome, cell) != "": continue
				distance = cell.distance_squared_to(anchor)
				nearest = cell
		assert(Land.in_grid(nearest), "No valid site for %s in %s" % [id, biome])
		for point in int(Data.machines[id].deployment.life_cost):
			var reason := Sim.add_life_point(biome, nearest)
			assert(reason == "", reason)
		placements[id] = nearest
	Sim._tick_life_growth(20.0)
	for id: String in placements:
		assert(Sim.machine_at(biome, placements[id]).get("type", "") == id)
	return placements
