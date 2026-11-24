extends Node
## Run with godot --headless --path . res://tests/sim_test.tscn.

const BIOME := "forest"
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func _ready() -> void:
	Settings.tide_seconds = 0.0
	_check_river_cycle()
	Sim.new_game(2026)
	Sim.paused = true
	check(Data.machines.size() == 3, "Only the three FT1 flora machines are registered")
	check(Land.machine_neighbors(Vector2i(5, 5), "adjacent").size() == 4, "Four edge neighbors")
	check(Land.machine_neighbors(Vector2i(5, 5), "surrounding").size() == 8, "Eight surrounding neighbors")
	check(Land.machine_neighbors(Vector2i.ZERO, "adjacent").size() == 2, "Corner clips four-way range")
	check(Land.machine_neighbors(Vector2i.ZERO, "surrounding").size() == 3, "Corner clips eight-way range")
	var all_plots: Dictionary = {}
	for b: String in Data.biome_order:
		for y in Land.GRID:
			for x in Land.GRID:
				all_plots[Land.parcel_key(b, Vector2i(x, y))] = "sheet_burnt"
	var test_cell := Vector2i(0, 1)
	var site_key := Land.parcel_key(BIOME, test_cell)
	for id: String in ["sheet_river", "sheet_river_low", "sheet_oasis"]:
		all_plots[site_key] = id
		Land.restore_terrain(all_plots)
		for machine: String in Data.machines:
			check(not Sim.machine_site_reason(machine, BIOME, test_cell).is_empty(), "Unsupported site: " + machine)
	all_plots[site_key] = "sheet_sand"
	Land.restore_terrain(all_plots)
	check(Sim.machine_site_reason("propagator", BIOME, test_cell).is_empty(), "Sand and shrub have concentration 0")
	check(not Sim.machine_site_reason("collector", BIOME, test_cell).is_empty(), "Collector needs concentration 1")
	var start_life := Sim.count("life")
	var natural_life: float = Land.get_parcel(BIOME, test_cell).elements.life
	Sim.condense(BIOME, test_cell, "life")
	check(Sim.count("life") == start_life and Land.get_parcel(BIOME, test_cell).elements.life == natural_life, "Natural Life cannot mint points")
	Land.clear_attachment(BIOME, test_cell)
	check(Sim.count("life") == start_life, "Clearing shrubs cannot mint points")
	check(Land.get_parcel(BIOME, test_cell).life_concentration == -1, "Removing the shrub reveals negative concentration")
	check(not Sim.machine_site_reason("propagator", BIOME, test_cell).is_empty(), "Propagator refuses negative site")
	check(Sim.machine_site_reason("extractor", BIOME, test_cell).is_empty(), "Extractor has no site concentration requirement")

	# Isolate production in a uniform biome with known concentrations.
	all_plots[site_key] = "sheet_burnt"
	Land.restore_terrain(all_plots)
	for y in Land.GRID:
		for x in Land.GRID: Land.change_concentration(BIOME, Vector2i(x, y), -2)
	var producer := _machine("extractor", Vector2i(5, 4))
	var collector := _machine("collector", Vector2i(5, 5))
	var propagator := _machine("propagator", Vector2i(4, 4))
	var corner_pump := _machine("extractor", Vector2i.ZERO)
	var suppressed := _machine("propagator", Vector2i(10, 10))
	for cell in Land.machine_neighbors(suppressed.cell, "adjacent"):
		Land.change_concentration(BIOME, cell, -5)
	for cell in [Vector2i(6, 5), Vector2i(5, 6)]: Land.change_concentration(BIOME, cell, 2)
	var life_before := Sim.count("life")
	Sim.step(14.9)
	check(propagator.cycles == 0 and collector.cycles == 0, "No self-powered machine fires early")
	var order_time: float = Sim.orders[0].remaining
	var weather_time: float = Sim.weather_timer[BIOME]
	var cycle_time: float = collector.cycle_elapsed
	Land.start_tide()
	Sim.step(Land.TIDE_ROW_SECONDS * (Land.GRID - 1), {}, 3.0)
	check(Land.tide_state.row == Land.GRID and producer.cycles == 0 and corner_pump.carry.is_empty(), "Last row is animating before tidal machines settle")
	Sim.step(Land.TIDE_ROW_SECONDS, {}, 0.0)
	check(Land.tide_state.is_empty() and is_equal_approx(Sim.game_time, 14.9) and Land.tide_elapsed == 0.0, "The wave takes wall time and freezes the game clock")
	check(Sim.orders[0].remaining == order_time and Sim.weather_timer[BIOME] == weather_time and collector.cycle_elapsed == cycle_time, "Orders, weather and machine timers stay frozen")
	check(propagator.cycles == 0 and collector.cycles == 0 and Sim.count("life") == life_before, "Tide never triggers self-powered machines")
	check(producer.cycles == 1 and Sim.count("liquid_energy_canister") == 1, "Extractor produces one canister from eight")
	check(corner_pump.cycles == 0 and corner_pump.carry.concentration == 3, "Corner pump retains three extracted points")
	Sim.step(0.1)
	check(propagator.cycles == 4, "Propagator seeds four plots after exactly 15 game seconds")
	check(collector.cycles == 1 and Sim.count("life") == life_before + 1, "Timed collection follows simultaneous seeding")
	check(suppressed.cycles == 0, "A wholly negative neighborhood cannot activate")
	var seeded := Vector2i(3, 4)
	var diagonal := Vector2i(3, 3)
	check(Land.get_parcel(BIOME, seeded).stabilized and Land.get_parcel(BIOME, seeded).land == "sheet_grass", "Seeded cardinal is stable grass")
	check(not Land.get_parcel(BIOME, diagonal).stabilized and Land.get_parcel(BIOME, diagonal).land == "sheet_burnt", "Diagonal excluded from seeding")
	var before: int = Land.get_parcel(BIOME, seeded).life_concentration
	Sim.toggle_enabled(propagator.uid)
	_full_tide()
	check(Land.get_parcel(BIOME, seeded).land == "sheet_grass", "Stable grass does not flip")
	check(Land.get_parcel(BIOME, seeded).life_concentration == before + 1, "Stable grass receives tidal concentration")
	check(propagator.cycles == 4, "Disabled machine does not seed")
	_full_tide()
	check(corner_pump.cycles == 1 and corner_pump.carry.concentration == 1, "Partial extractions carry across three tides")
	var saved_path := "user://ft1-tide-test-%s.json" % OS.get_process_id()
	Sim.step(5.0)
	var saved_cycle: float = collector.cycle_elapsed
	Land.start_tide()
	Sim.step(2.24)
	var wave_row: int = Land.tide_state.row
	var mouths := Land.river_mouths.duplicate(true)
	var corner_uid: int = corner_pump.uid
	var cans_before := Sim.count("liquid_energy_canister")
	check(Sim.save_game(saved_path), "Can save mid-wave")
	Sim.new_game(7)
	check(Sim.load_game(saved_path), "Can restore mid-wave")
	check(Land.generation_version == Land.GENERATOR_VERSION and Land.river_mouths == mouths, "River course survives reload")
	check(Land.tide_state.row == wave_row and Sim.count("liquid_energy_canister") == cans_before, "Loading does not settle an unfinished tide")
	check(is_equal_approx(Sim.machines[int(collector.uid)].cycle_elapsed, saved_cycle), "Timed machine progress survives loading mid-wave")
	check(Sim.machines[corner_uid].carry.concentration == 1 and Land.get_parcel(BIOME, seeded).stabilized, "Stored concentration, stability, and machine carry survive loading")
	Sim.step(5.5)
	check(Land.tide_state.is_empty() and Sim.machines[corner_uid].carry.concentration == 4, "Restored wave settles exactly once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))

	# A flooded riverbed destroys its installed machine when the front crosses.
	var flooded := Vector2i(2, 7)
	Land.restore_terrain({Land.parcel_key(BIOME, flooded): "sheet_riverbed"})
	var on_riverbed := _machine("extractor", flooded)
	_full_tide()
	check(not Sim.machines.has(on_riverbed.uid) and Land.get_parcel(BIOME, flooded).land == "sheet_river", "Flooded riverbed removes its machine")
	_check_clock_boundaries()
	print("FT1 TIDE CHECK: ", failures, " failures")
	get_tree().quit(1 if failures > 0 else 0)

func _machine(id: String, cell: Vector2i) -> Dictionary:
	var m := Sim._make_machine(id, BIOME, cell, Sim.next_uid)
	Sim.machines[m.uid] = m
	Sim.next_uid += 1
	return m

func _full_tide() -> void:
	Land.start_tide()
	Sim.step(Land.TIDE_ROW_SECONDS * Land.GRID + 0.01)

func _check_clock_boundaries() -> void:
	Sim.new_game(2026)
	var cell := Vector2i(4, 4)
	Land.restore_terrain({Land.parcel_key(BIOME, cell): "sheet_grass"})
	check(Sim.add_life_point(BIOME, cell) == "", "Can plant for the clock test")
	Sim.step(44.999)
	var m := Sim.machine_at(BIOME, cell)
	check(m.get("cycles") == 4, "New machines count their own age after growing in a large time step")
	Sim.step(0.001)
	check(m.cycles == 8, "Second 15-second cycle fires exactly once")
	Settings.tide_seconds = 6.0
	Sim.step(2.0, {}, 3.0)
	check(Land.tide_state.row == 1 and is_equal_approx(Sim.game_time, 51.0), "Automatic wave starts precisely at its gameplay deadline")
	var seconds := Land.TIDE_ROW_SECONDS * Land.GRID
	Sim.step(seconds + 0.4, {}, 2.0)
	check(Land.tide_state.is_empty() and is_equal_approx(Sim.game_time, 51.8), "Only time left after the wave receives the selected speed")
	check(is_equal_approx(Land.tide_elapsed, 0.8), "The next countdown excludes the entire wave")

func _check_river_cycle() -> void:
	var axes := {}
	var mouth_locations := {}
	for seed_value: int in [7, 47, 149, 2026]:
		Sim.new_game(seed_value)
		for b: String in Data.biome_order:
			var mouth: Dictionary = Land.river_mouths[b][0]
			axes[mouth.edge] = true
			mouth_locations[mouth.first] = true
	check(axes.size() == 2 and mouth_locations.size() >= 3, "Seeds change the river axis and the inlet position")
	var full_water := {}
	for y in Land.GRID:
		for x in Land.GRID:
			var cell := Vector2i(x, y)
			if Land.get_parcel(BIOME, cell).land == "sheet_river": full_water[cell] = true
	var mouths := Land.river_mouths.duplicate(true)
	_full_tide()
	var channel := {}
	var banks := 0
	for cell: Vector2i in full_water:
		var id: String = Land.get_parcel(BIOME, cell).land
		if id == "sheet_river_low": channel[cell] = true
		elif id == "sheet_riverbed": banks += 1
	check(not channel.is_empty() and banks > 0 and banks + channel.size() == full_water.size(), "Ebb exposes banks and leaves water in the channel")
	var open: Array = channel.keys().slice(0, 1)
	var visited := {}
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		if visited.has(cell): continue
		visited[cell] = true
		for neighbor in Land.machine_neighbors(cell, "adjacent"):
			if channel.has(neighbor): open.append(neighbor)
	check(visited.size() == channel.size(), "The low-water channel remains connected")
	_full_tide()
	for cell: Vector2i in full_water:
		check(Land.get_parcel(BIOME, cell).land == "sheet_river", "Flood restores the original water surface")
	check(Land.river_mouths == mouths, "Tides preserve the original river course")
