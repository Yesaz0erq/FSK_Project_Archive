extends Node
## Loads the title, then the game; places machines, travels through all four scenes,
## cycles land views and the build preview. Fails on any script error in the log.
var tree: SceneTree
func _ready() -> void:
	tree = get_tree()
	var title: Node = load("res://scenes/title.tscn").instantiate()
	tree.root.add_child.call_deferred(title)
	await _frames(20)
	title.queue_free()
	Sim.machines.clear()
	Sim.new_game(2026)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	tree.root.add_child(game)
	await _frames(20)
	var placed: int = 0
	for b: String in Data.biome_order:
		game.travel(b)
		await _frames(50)
		for mode in ["fire", "water", "earth", "air", "temperature", "effects", "none"]:
			game.hud.set_view_mode(mode)
			await _frames(2)
		Sim.money = 5000
		Sim.reputation = 20
		for id: String in Data.machines: Sim.inventory = {}
		for item: String in Data.items: Sim.inventory[item] = 50
		var cells: Array = []
		for y in 11:
			for x in 11:
				cells.append(Vector2i(x, y))
		for id: String in Data.machine_order:
			game.hud.select_build(id)
			game.view._set_hover(cells[placed % cells.size()])
			await _frames(1)
			for c: Vector2i in cells:
				if Sim.place_machine(id, b, c) == "":
					placed += 1
					cells.erase(c)
					break
		game.hud.select_build("")
		for c2: Vector2i in [Vector2i(5, 5), Vector2i(0, 0)]:
			game.view.select_cell(c2)
			game.view._set_hover(c2)
			await _frames(3)
		for i in 200: Sim.step(0.25)
		await _frames(10)
		Sim.start_weather(b, str(Data.biomes[b].weather[0]), 5.0)
		await _frames(5)
	print("placed machines: ", placed)
	print("inventory after run: ", Sim.inventory)
	game.hud._top_action("save")
	print("SMOKE DONE")
	game._to_menu()
	tree.quit()

func _frames(n: int) -> void:
	for i in n: await tree.process_frame
