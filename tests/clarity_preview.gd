extends Node

func _ready() -> void:
	var output_dir := "res://docs"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	Settings.autosave_seconds = 0
	get_window().size = Vector2i(1920,1080)
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(1.8).timeout
	assert(title.get_child(1) is CanvasLayer)
	assert(title.get_child(1).layer == 5)
	var panel: Control = title.get_child(1).get_child(0).get_child(0)
	assert(panel.get_global_rect().end.y < get_viewport().get_visible_rect().size.y)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("title-hd-clarity.png"))
	title.queue_free()
	await get_tree().process_frame
	Sim.new_game(2026)
	Sim.paused = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.view.select_cell(Vector2i(3,4))
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("game-hd-clarity.png"))
	game.hud.hide()
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	# The old pass replicated every aligned 2x2 group at 1080p. Use the
	# rendered landscape itself so a crisp HUD cannot hide that regression.
	var center := frame.get_size() / 2
	center -= Vector2i(center.x % 2, center.y % 2)
	var distinct_groups := 0
	for y in range(center.y-64, center.y+64, 2):
		for x in range(center.x-64, center.x+64, 2):
			var a := frame.get_pixel(x,y)
			if a != frame.get_pixel(x+1,y) or a != frame.get_pixel(x,y+1) or a != frame.get_pixel(x+1,y+1):
				distinct_groups += 1
	assert(distinct_groups > 400, "The 3D image is losing native pixel detail at 1080p")
	print("HD CLARITY OK: title UI, inspection panel and native world detail at ", frame.get_size(), "; distinct groups ", distinct_groups, "/4096")
	get_tree().quit()
