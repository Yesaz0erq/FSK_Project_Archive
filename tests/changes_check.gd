extends Node
func _ready() -> void:
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	Settings.open()
	await get_tree().process_frame
	Settings.dialog.close_requested.emit()
	title.queue_free()
	await get_tree().process_frame
	Sim.new_game(2026)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.view.select_cell(Vector2i(1, 1))
	game.hud._inspect_dirty = true
	for i in range(30): await get_tree().process_frame
	assert(Data.item_name("life") == "生灵")
	for biome: String in Data.biome_order:
		for y in range(11):
			for x in range(11):
				var p: Dictionary = Land.get_parcel(biome, Vector2i(x, y))
				assert(p.land != "sheet_burnt" and p.land != "sheet_riverbed")
				if p.sheet.attachment != "/": Land.clear_attachment(biome, Vector2i(x, y))
	print("CHANGES CHECK OK: title, settings, game, terrain, life")
	get_tree().quit()
