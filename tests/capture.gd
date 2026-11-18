extends Node
## Captures the title, starter machines, terrain overlays, codex and weather (display required).

const FloraFixture := preload("res://tests/flora_scene_fixture.gd")
var output_directory := OS.get_cache_dir().path_join("project-archive-captures")

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture needs a rendering display")
		get_tree().quit(1)
		return
	Settings.autosave_seconds = 0
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.substr(7)
		if arg.begins_with("--output-dir="): output_directory = arg.trim_prefix("--output-dir=")
	assert(DirAccess.make_dir_recursive_absolute(output_directory) == OK)
	get_window().size = Vector2i(1600, 960)
	if only in ["", "title"]:
		var title: Node = load("res://scenes/title.tscn").instantiate()
		add_child(title)
		await get_tree().create_timer(0.8).timeout
		await _capture_frame("title")
		title.queue_free()
		if only == "title":
			get_tree().quit()
			return
	Sim.new_game(2026)
	Sim.paused = true
	Sim.inventory.life = 30
	var plots := {}
	for biome: String in Data.biome_order:
		plots[biome] = FloraFixture.grow_starters(biome)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for biome: String in Data.biome_order:
		if only not in ["", biome]: continue
		if game.biome != biome: await game.travel(biome)
		var cell: Vector2i = plots[biome].collector
		game.view.select_cell(cell)
		game.hud._inspect_dirty = true
		await get_tree().create_timer(1.5).timeout
		await _capture_frame("game_" + biome)
		game.view.select_cell(Vector2i(-1, -1))
		game.hud.set_view_mode("ember" if biome == "volcano" else "life")
		game.view._set_hover(cell)
		await get_tree().create_timer(0.35).timeout
		await _capture_frame("view_" + biome)
		game.hud.set_view_mode("none")
	if only in ["", "extra"]:
		game._open_pause()
		game.pause_menu.open_codex()
		game.pause_menu._show_machine("extractor")
		await get_tree().create_timer(0.4).timeout
		await _capture_frame("machine_codex")
		game.pause_menu.close()
		Sim.start_weather("desert", "sandstorm", 30.0)
		if game.biome != "desert": await game.travel("desert")
		await get_tree().create_timer(1.5).timeout
		await _capture_frame("weather_desert")
	print("CAPTURE DONE: ", output_directory)
	get_tree().quit()

func _capture_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(output_directory.path_join("screenshot_%s.png" % label))
	assert(result == OK, "Could not write screenshot: " + label)
	print("shot ", label)
