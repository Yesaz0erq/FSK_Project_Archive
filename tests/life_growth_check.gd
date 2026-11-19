extends Node

const BIOME := "forest"
const A := Vector2i(2, 3)
const B := Vector2i(3, 3)
const C := Vector2i(4, 3)
const D := Vector2i(2, 4)
const E := Vector2i(3, 4)
const F := Vector2i(4, 4)

func _ready() -> void:
	get_window().size = Vector2i(1600, 960)
	Settings.autosave_seconds = 0
	Sim.new_game(2026)
	Sim.paused = true
	Sim.money = 0
	Sim.inventory = {"life": 12}
	var terrain := {}
	for cell: Vector2i in [A, B, C, D, E, F]:
		terrain[Land.parcel_key(BIOME, cell)] = "sheet_grass"
	Land.restore_terrain(terrain)
	assert(Sim.add_life_point(BIOME, A) == "")
	Sim._tick_life_growth(4.999)
	assert(Sim.growth_at(BIOME, A).stage == "phase1")
	Sim._tick_life_growth(0.001)
	assert(Sim.growth_at(BIOME, A).stage == "phase2_1")
	assert(Sim.add_life_point(BIOME, A) != "")
	Sim._tick_life_growth(9.999)
	assert(Sim.machine_at(BIOME, A).is_empty())
	Sim._tick_life_growth(0.001)
	assert(Sim.machine_at(BIOME, A).type == "propagator")
	assert(Sim.count("life") == 11)

	assert(Sim.add_life_point(BIOME, B) == "")
	Sim._tick_life_growth(4.999)
	assert(Sim.add_life_point(BIOME, B) == "")
	assert(Sim.growth_at(BIOME, B).remaining == 10.0)
	Sim._tick_life_growth(10.0)
	assert(Sim.growth_at(BIOME, B).stage == "phase3_1")
	assert(Sim.add_life_point(BIOME, B) != "")
	Sim._tick_life_growth(10.0)
	assert(Sim.machine_at(BIOME, B).type == "collector")
	assert(Sim.count("life") == 9)

	assert(Sim.add_life_point(BIOME, C) == "")
	assert(Sim.add_life_point(BIOME, C) == "")
	Sim._tick_life_growth(9.999)
	assert(Sim.add_life_point(BIOME, C) == "")
	assert(Sim.growth_at(BIOME, C).stage == "phase3_2")
	assert(Sim.add_life_point(BIOME, C) != "")
	Sim._tick_life_growth(10.0)
	assert(Sim.machine_at(BIOME, C).type == "extractor")
	assert(Sim.count("life") == 6 and Sim.money == 0)

	assert(Sim.add_life_point(BIOME, D) == "")
	Land.restore_terrain({Land.parcel_key(BIOME, D): "sheet_river"})
	assert(Sim.add_life_point(BIOME, D) != "" and Sim.count("life") == 5)
	Sim._tick_life_growth(20.0)
	assert(Sim.machine_at(BIOME, D).is_empty())
	assert(Sim.growth_at(BIOME, D).remaining == 0.0 and Sim.growth_at(BIOME, D).has("blocked"))
	Land.restore_terrain(terrain)
	Sim._tick_life_growth(0.1)
	assert(Sim.machine_at(BIOME, D).type == "propagator" and Sim.count("life") == 5)

	assert(Sim.add_life_point(BIOME, E) == "")
	assert(Sim.add_life_point(BIOME, E) == "")
	var concentration: int = Land.get_parcel(BIOME, E).life_concentration
	Land.change_concentration(BIOME, E, -concentration)
	Sim._tick_life_growth(20.0)
	assert(Sim.machine_at(BIOME, E).is_empty() and Sim.growth_at(BIOME, E).has("blocked"))
	Land.change_concentration(BIOME, E, 1)
	Sim._tick_life_growth(0.1)
	assert(Sim.machine_at(BIOME, E).type == "collector")

	assert(Sim.add_life_point(BIOME, F) == "")
	Sim._tick_life_growth(2.0)
	var extractor: Dictionary = Sim.machine_at(BIOME, C)
	extractor.cycles = 1
	extractor.carry = {"concentration": 7}
	extractor.last_output = {"liquid_energy_canister": 1}
	var path := "user://growth-check-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert(Sim.save_game(path))
	assert(Sim.load_game(path))
	Sim.paused = true
	assert(Sim.growth_at(BIOME, F).stage == "phase1" and Sim.growth_at(BIOME, F).remaining == 3.0)
	assert(Sim.count("life") == 2 and Sim.machines.size() == 5)
	extractor = Sim.machine_at(BIOME, C)
	assert(extractor.cycles == 1 and extractor.carry.concentration == 7 and extractor.last_output.size() == 1)
	assert(Land.get_parcel(BIOME, E).life_concentration == 1)

	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game._on_clicked(A, MOUSE_BUTTON_LEFT)
	assert(Sim.count("life") == 2)
	Sim.paused = false
	game._open_pause()
	var time_before: float = Sim.game_time
	await get_tree().create_timer(0.12).timeout
	assert(Sim.paused and Sim.game_time == time_before and Sim.growth_at(BIOME, F).remaining == 3.0)
	game.pause_menu.open_codex()
	assert(game.pause_menu._machine_buttons.size() == 3)
	var capture_directory := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): capture_directory = arg.trim_prefix("--output-dir=")
	var capture := not capture_directory.is_empty() and DisplayServer.get_name() != "headless"
	if capture:
		assert(DirAccess.make_dir_recursive_absolute(capture_directory) == OK)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_directory.path_join("life-growth-codex.png"))
	game.pause_menu.close()
	assert(not Sim.paused)
	Sim.paused = true
	game.view.select_cell(F)
	game.hud._inspect_dirty = true
	if capture:
		await get_tree().create_timer(1.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_directory.path_join("life-growth-game.png"))
	assert(game.hud._build_cards.is_empty())
	game.queue_free()
	await get_tree().process_frame

	# Reuse the isolated slot to exercise the normal version-one file loader.
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	old.version = 1
	old.erase("terrain_generator")
	old.inventory = {"life": 7}
	old.machines = [{"uid": 90, "type": "leafwing_turbine", "biome": BIOME, "cell": [2, 3]}]
	old.terrain_overrides = terrain
	old.weather_bindings = [{"effect": "leaf_draft", "biome": BIOME, "source_id": "machine:90", "remaining": -1}]
	old.eternity_records = {Land.parcel_key(BIOME, A): {"land": "sheet_grass", "machine": old.machines[0]}}
	old.life_growth = {
		"a": {"biome": BIOME, "cell": [2, 3], "stage": "stage1", "remaining": 3.0},
		"b": {"biome": BIOME, "cell": [3, 3], "stage": "stage2", "remaining": 7.0},
		"c": {"biome": BIOME, "cell": [4, 3], "stage": "mature", "remaining": 0.0},
		"d": {"biome": BIOME, "cell": [2, 4], "stage": "machine", "machine": "pitcher_still", "remaining": 4.0},
		"e": {"biome": BIOME, "cell": [3, 4], "stage": "machine", "machine": "leafwing_turbine", "remaining": 2.0},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	assert(Sim.load_game(path))
	assert(Land.generation_version == 1)
	for b: String in Data.biome_order:
		assert(Land.river_mouths[b][0].edge == 2 and Land.river_mouths[b][1].edge == 3)
	assert(Sim.save_game(path))
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).terrain_generator == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert(Sim.machines.size() == 1 and Sim.machine_at(BIOME, C).type == "propagator")
	assert(Sim.growth_at(BIOME, A).stage == "phase1" and Sim.growth_at(BIOME, A).remaining == 3.0)
	assert(Sim.growth_at(BIOME, B).stage == "phase2_1" and Sim.growth_at(BIOME, B).remaining == 7.0)
	assert(Sim.growth_at(BIOME, D).stage == "phase3_1" and Sim.growth_at(BIOME, D).remaining == 4.0)
	assert(Sim.growth_at(BIOME, E).stage == "phase3_1" and Sim.growth_at(BIOME, E).remaining == 2.0)
	assert(Sim.eternity_records[Land.parcel_key(BIOME, A)].machine.is_empty())
	for binding: Dictionary in Land.bindings:
		assert(binding.source_id != "machine:90")
	Sim._tick_life_growth(30.0)
	assert(Sim.life_growth.is_empty() and Sim.machines.size() == 5 and Sim.count("life") == 7)
	assert(Sim.machine_at(BIOME, D).type == "collector" and Sim.machine_at(BIOME, E).type == "collector")
	Sim.new_game(2026)
	Sim.paused = true
	Land.restore_terrain({Land.parcel_key(BIOME, A): "sheet_riverbed"})
	assert(Sim.add_life_point(BIOME, A) == "")
	Land.start_tide()
	Land.tick(Land.TIDE_ROW_SECONDS * Land.GRID + 0.01)
	assert(Land.get_parcel(BIOME, A).land == "sheet_river" and not Sim.growth_at(BIOME, A).is_empty())
	Sim._tick_life_growth(15.0)
	assert(Sim.growth_at(BIOME, A).has("blocked"))
	Land.start_tide()
	Land.tick(Land.TIDE_ROW_SECONDS * Land.GRID + 0.01)
	Sim._tick_life_growth(0.0)
	assert(Land.get_parcel(BIOME, A).land == "sheet_riverbed" and Sim.machine_at(BIOME, A).type == "propagator")
	print("LIFE GROWTH OK: three timed branches, exact boundaries, site recovery, costs, pause, codex, save round-trip and legacy migration")
	get_tree().quit()
