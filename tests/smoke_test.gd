extends Node
## Loads the title and all four playable regions. Run with the headless or desktop renderer.

const FloraFixture := preload("res://tests/flora_scene_fixture.gd")

func _ready() -> void:
	Settings.autosave_seconds = 0
	Settings.tide_seconds = 0
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title.queue_free()
	Sim.new_game(2026)
	var layout := Land._base.duplicate(true)
	var effects := Land.bindings.duplicate(true)
	Sim.new_game(2027)
	assert(Land._base != layout)
	Sim.new_game(2026)
	assert(layout == Land._base and effects == Land.bindings)
	Sim.paused = true
	Sim.inventory.life = 30
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	for biome: String in Data.biome_order:
		if game.biome != biome: await game.travel(biome)
		assert(game.biome == biome and game.view.biome == biome)
		var placements := FloraFixture.grow_starters(biome)
		assert(Sim.machines_in(biome).size() == 3)
		for mode: String in ["life", "ember", "silence", "eternity", "temperature", "effects", "none"]:
			game.hud.set_view_mode(mode)
			assert(game.view.overlay == mode)
		for cell: Vector2i in placements.values():
			game.view.select_cell(cell)
			game.view._set_hover(cell)
			await get_tree().process_frame
		var weather: String = Data.biomes[biome].weather[0]
		Sim.start_weather(biome, weather, 0.5)
		for effect: Dictionary in Land.get_parcel(biome, Vector2i.ZERO).effects:
			if effect.source == "weather": assert(effect.effect == weather)
		assert(Sim.weather[biome].effect == weather and not Land.save_bindings().is_empty())
		Sim.step(0.6)
		assert(not Sim.weather.has(biome) and Land.save_bindings().is_empty())
	assert(Sim.machines.size() == 12 and Sim.count("life") == 6)
	var path := "user://smoke-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert(Sim.save_game(path))
	Sim.new_game(9801)
	assert(Sim.machines.is_empty())
	assert(Sim.load_game(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for biome: String in Data.biome_order: assert(Sim.machines_in(biome).size() == 3)
	assert(Sim.seed_value == 2026 and Sim.count("life") == 6)
	print("SMOKE DONE: reproducible seed, four regions, twelve grown machines, overlays, weather and temporary save round-trip")
	get_tree().quit()
