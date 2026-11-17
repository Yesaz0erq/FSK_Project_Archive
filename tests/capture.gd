extends Node
## Renders screenshots of the title and every biome into docs/ (needs a display / xvfb).
var tree: SceneTree
func _ready() -> void:
	tree = get_tree()
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
	get_window().size = Vector2i(1600, 960)
	var title: Node = load("res://scenes/title.tscn").instantiate()
	tree.root.add_child.call_deferred(title)
	await _frames(25)
	if only == "" or only == "title": _shot("title")
	title.queue_free()
	Sim.machines.clear()
	Sim.new_game(2026)
	Sim.money = 2000
	Sim.reputation = 8
	for item: String in Data.items: Sim.inventory[item] = 30
	var game: Node = load("res://scenes/game.tscn").instantiate()
	tree.root.add_child(game)
	await _frames(30)
	var plan: Dictionary = {
		"forest": ["taproot_drill", "taproot_drill", "leafwing_turbine", "seedpod_kiln", "spore_garden", "pitcher_still", "vine_loom", "mist_fern"],
		"desert": ["taproot_drill", "taproot_drill", "leafwing_turbine", "seedpod_kiln", "pitcher_still", "ember_lily", "vine_loom"],
		"volcano": ["taproot_drill", "taproot_drill", "gourd_kettle", "seedpod_kiln", "bloom_press", "leafwing_turbine", "ember_lily"],
		"snow": ["taproot_drill", "taproot_drill", "gourd_kettle", "ember_lily", "seedpod_kiln", "leafwing_turbine", "mist_fern"]}
	for b: String in Data.biome_order:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(b)
		for id: String in plan[b]:
			for attempt in 200:
				var c := Vector2i(rng.randi_range(1, 9), rng.randi_range(1, 9))
				if Sim.place_machine(id, b, c) == "": break
	for i in 120: Sim.step(0.25)
	for b: String in Data.biome_order:
		if only != "" and only != b: continue
		game.travel(b)
		await _frames(30)
		var ms: Array = Sim.machines_in(b)
		var sel: Vector2i = ms[mini(2, ms.size() - 1)].cell
		game.view.select_cell(sel)
		game.hud._inspect_dirty = true
		await _frames(20)
		_shot("game_" + b)
		game.view.select_cell(Vector2i(-1, -1))
		game.hud.set_view_mode("temperature" if b != "volcano" else "fire")
		game.view._set_hover(Vector2i(5, 5))
		await _frames(15)
		_shot("view_" + b)
		game.hud.set_view_mode("none")
	if only != "" and only != "extra":
		tree.quit()
		return
	game.travel("snow")
	await _frames(30)
	game.hud.select_build("seedpod_kiln")
	game.view._set_hover(Vector2i(4, 6))
	game.hud._inspect_dirty = true
	await _frames(20)
	_shot("build_preview")
	game.hud.select_build("")
	Sim.start_weather("desert", "sandstorm", 30.0)
	game.travel("desert")
	await _frames(40)
	_shot("weather_desert")
	print("CAPTURE DONE")
	tree.quit()

func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/screenshot_%s.png" % name))
	print("shot ", name)

func _frames(n: int) -> void:
	for i in n: await tree.process_frame
