extends Node3D
func _ready() -> void:
	get_window().size = Vector2i(1440, 900)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202631")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e1ef")
	env.ambient_light_energy = 0.32
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.8
	camera.position = Vector3(0,10,14)
	add_child(camera)
	camera.look_at(Vector3(0,0,0))
	var ids := ["sheet_sand", "sheet_grass", "sheet_burnt", "sheet_oasis", "sheet_river", "sheet_river_low", "sheet_riverbed"]
	var names := ["沙地", "草地", "火烧迹地", "绿洲", "河流", "低水位河流", "河床"]
	for i in ids.size():
		var packed: PackedScene = load("res://assets/models/terrain/%s.tscn" % ids[i])
		var block: MeshInstance3D = packed.instantiate()
		assert(block.mesh.get_surface_count() == 6)
		for face in range(6): assert(block.mesh.surface_get_arrays(face)[Mesh.ARRAY_VERTEX].size() == 6)
		assert(block.mesh.surface_get_material(5).albedo_color == Color.BLACK)
		block.position = Vector3((i % 4 - (1.5 if i < 4 else 1.0)) * 2.8, 0, (i / 4 - 0.5) * 4.3)
		block.rotation.y = PI * 0.25
		add_child(block)
		var label := Label3D.new()
		label.text = names[i]
		label.font = UITheme.build().default_font
		label.font_size = 56
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = block.position + Vector3(0,-0.6,0.9)
		add_child(label)
	for frame in range(15): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/terrain-models-preview.png")
	print("MODELS CHECK OK: seven models, six closed faces, black bottoms, preview rendered")
	get_tree().quit()
