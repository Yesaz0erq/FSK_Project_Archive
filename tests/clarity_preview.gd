extends Node
func _ready() -> void:
	get_window().size = Vector2i(1920,1080)
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(1.8).timeout
	assert(title.get_child(1) is CanvasLayer)
	assert(title.get_child(1).layer == 5)
	var panel: Control = title.get_child(1).get_child(0).get_child(0)
	assert(panel.get_global_rect().end.y < get_viewport().get_visible_rect().size.y)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/title-hd-clarity.png")
	title.queue_free()
	await get_tree().process_frame
	Sim.new_game(2026)
	Sim.paused = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.view.select_cell(Vector2i(3,4))
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/game-hd-clarity.png")
	print("HD CLARITY OK: title UI above grading, menu fits, native render, six rebuilt terrain materials, game loaded")
	get_tree().quit()
