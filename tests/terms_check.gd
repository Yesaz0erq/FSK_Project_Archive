extends Node
var flips: int = 0
func _ready() -> void:
	get_window().size = Vector2i(1600,960)
	Sim.new_game(2026)
	Sim.paused = true
	assert(Data.element_ids == ["life", "ember", "silence", "eternity"])
	var cell := Vector2i(3,4)
	var original: Dictionary = Land.get_parcel("forest",cell)
	assert(original.elements.silence == 0 and original.elements.eternity == 0)
	var life: int = Sim.count("life")
	Sim.condense("forest",cell,"ember")
	assert(Sim.count("ember") == 11)
	Land.tide_tile_changed.connect(func(_b: String, _c: Vector2i, old: String, next: String, _e: int) -> void:
		assert(Data.land_types[old].sheet.flip_to == next)
		flips += 1)
	Land.start_tide()
	for i in range(11): Land.tick(0.71)
	assert(flips > 0)
	assert(Sim.count("life") >= life)
	var old_rule: String = Data.land_types.sheet_sand.sheet.tide
	Data.land_types.sheet_sand.sheet.tide = "转变"
	Land._base.forest[cell.y*11+cell.x].land = "sheet_sand"
	Land._cache.clear()
	Land._tide_replace("forest",cell,0)
	assert(Land.get_parcel("forest",cell).land == "sheet_grass")
	Data.land_types.sheet_sand.sheet.tide = old_rule
	Land.bind_effect("eternity_field","forest",cell,1,"machine","test",-1)
	Sim.record_eternity("forest",cell)
	var recorded: String = str(Land.get_parcel("forest",cell).land)
	Land._base.forest[cell.y*11+cell.x].land = "sheet_sand"
	Land._cache.clear()
	Sim.reshape_eternity("forest",cell)
	assert(Land.get_parcel("forest",cell).land == recorded)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.view.select_cell(cell)
	for mode in ["life","ember","silence","eternity","temperature","none"]: game.hud.set_view_mode(mode)
	Settings.open_glossary()
	await get_tree().process_frame
	for child in Settings.get_children():
		if child is AcceptDialog: child.queue_free()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/world-terms-preview.png")
	print("TERMS CHECK OK: natural energies, artificial technology, condensing, paired flip, different-variant transformation, eternity reconstruction, glossary, HUD")
	get_tree().quit()
