extends Node
func _ready() -> void:
	get_window().size = Vector2i(1600,960)
	Sim.new_game(2026)
	Sim.paused = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for biome: String in Data.biome_order:
		if biome != "forest": game.travel(biome)
		await get_tree().create_timer(1.2).timeout
		game.view._zoom_target = 28.0
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/environment_"+biome+".png")
		print("ENVIRONMENT RENDERED: ",biome)
	game.hud.hide()
	game.travel("forest")
	await get_tree().create_timer(1.3).timeout
	game.view._zoom_target = 32.0
	game.view._pan = Vector3(-2,0,-2)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/environment-overview.png")
	print("ENVIRONMENT CHECK COMPLETE")
	get_tree().quit()
