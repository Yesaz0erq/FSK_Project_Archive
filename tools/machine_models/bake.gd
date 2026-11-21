extends Node
## Run with Godot's Compatibility renderer: --path . res://tools/machine_models/bake.tscn
## Optionally pass one or more machine IDs after -- to rebake a subset.
const Kit := preload("res://tools/machine_models/kit.gd")
const Layout := preload("res://scripts/world/machine_sprites.gd")
const ACTIVE_IDS := ["propagator", "collector", "extractor"]
const PHASE_IDS := ["phase1", "phase2_1", "phase2_2", "phase3_1", "phase3_2"]
const GROUPS := {
	"flora": ACTIVE_IDS,
	"flora_growth": PHASE_IDS,
	"botany": ["pitcher_still", "leafwing_turbine", "taproot_drill"],
	"thermal": ["seedpod_kiln", "gourd_kettle", "ember_lily", "mist_fern"],
	"workshop": ["spore_garden", "vine_loom", "bloom_press"],
}
const OUT := "res://assets/machines/baked/"
var viewport := SubViewport.new()
var camera := Camera3D.new()
var stage := Node3D.new()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	viewport.add_child(stage)
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Layout.WORLD_SIZE
	camera.near = 0.1
	camera.far = 18.0
	camera.current = true
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0,0,0,0)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	stage.add_child(key)
	key.position = Vector3(-3, 6, 4)
	key.look_at(Vector3.ZERO)
	key.light_color = Color("fff1ce")
	key.light_energy = 1.13
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 13.0
	key.shadow_bias = 0.035
	key.shadow_opacity = 0.58
	var rim := DirectionalLight3D.new()
	stage.add_child(rim)
	rim.position = Vector3(2, 3, -4)
	rim.look_at(Vector3.ZERO)
	rim.light_color = Color("b9b6fa")
	rim.light_energy = 0.52
	var ink_pass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	ink_pass.mesh = quad
	ink_pass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ink_pass.extra_cull_margin = 20.0
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://tools/machine_models/engraving.gdshader")
	ink.render_priority = 100
	ink_pass.material_override = ink
	stage.add_child(ink_pass)
	var wanted := OS.get_cmdline_user_args()
	if wanted.is_empty():
		wanted.append_array(PackedStringArray(ACTIVE_IDS))
		wanted.append_array(PackedStringArray(PHASE_IDS))
	var all_ids: Array = []
	for ids: Array in GROUPS.values(): all_ids.append_array(ids)
	for id: String in wanted:
		if not all_ids.has(id):
			push_error("Unknown machine: " + id)
			get_tree().quit(1)
			return
	for model_group: String in GROUPS:
		for id: String in GROUPS[model_group]:
			if not wanted.has(id): continue
			if id in ACTIVE_IDS or id in PHASE_IDS:
				# Use the exact painted, articulated volume seen on a playable parcel.
				var model: Node3D = load("res://assets/models/flora/%s.scn" % id).instantiate()
				stage.add_child(model)
				var captured: bool = await _bake_growth(id) if id in PHASE_IDS else await _bake(id, model)
				model.free()
				if not captured:
					get_tree().quit(1)
					return
				continue
			var source: Script = load("res://tools/machine_models/%s.gd" % model_group)
			if not source or not source.can_instantiate():
				push_error("Cannot load 3D model source for " + id)
				get_tree().quit(1)
				return
			var kit := Kit.new()
			stage.add_child(kit.root)
			source.build(id, kit)
			var ok: bool = await _bake_growth(id) if model_group == "flora_growth" else await _bake(id, kit)
			if not ok:
				get_tree().quit(1)
				return
			kit.root.free()
	get_tree().quit()

func _angle(row: int) -> void:
	_orbit(Layout.FIRST_YAW + 360.0 * row / Layout.DIRECTIONS, Layout.PITCH)

func _orbit(azimuth: float, elevation: float) -> void:
	var yaw := deg_to_rad(azimuth)
	var pitch := deg_to_rad(elevation)
	var focus := Vector3.UP * Layout.FOCUS_HEIGHT
	camera.position = focus + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)) * 6.5
	camera.look_at(focus)

func _grab() -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	return pixels

func _bake(id: String, kit: Object) -> bool:
	var cell := Layout.CAPTURE_SIZE
	var crop_frame := Rect2i((Vector2i(cell, cell) - Layout.FRAME) / 2, Layout.FRAME)
	var atlas := Image.create(Layout.FRAME.x * Layout.POSES, Layout.FRAME.y * Layout.DIRECTIONS, false, Image.FORMAT_RGBA8)
	viewport.size = Vector2i(cell, cell)
	for row in Layout.DIRECTIONS:
		_angle(row)
		for frame in Layout.POSES:
			kit.pose(float(frame) / Layout.POSES)
			var pixels := await _grab()
			var bounds := pixels.get_used_rect()
			if not crop_frame.grow(-1).encloses(bounds) or bounds.size.x < 16:
				push_error("%s row %d frame %d outside bake area: %s" % [id, row, frame, bounds])
				return false
			atlas.blit_rect(pixels, crop_frame, Vector2i(frame, row) * Layout.FRAME)
	if atlas.save_png(OUT + id + ".png") != OK: return false
	# Capture the silhouette observed from the same sun as scenery.gd. Its
	# projection can then be laid on a receiving plane, independently of the player camera.
	_orbit(-32.0, 43.0)
	var shadow := Image.create(Layout.FRAME.x * Layout.POSES, Layout.FRAME.y, false, Image.FORMAT_RGBA8)
	for frame in Layout.POSES:
		kit.pose(float(frame) / Layout.POSES)
		var light_view := await _grab()
		if not crop_frame.grow(-1).encloses(light_view.get_used_rect()):
			push_error("Sun projection clips " + id)
			return false
		shadow.blit_rect(light_view, crop_frame, Vector2i(Layout.FRAME.x * frame, 0))
	# Tint at runtime. White RGB avoids colored fringes in small mip levels.
	for y in shadow.get_height():
		for x in shadow.get_width():
			var coverage := shadow.get_pixel(x, y).a
			shadow.set_pixel(x, y, Color(1, 1, 1, coverage))
	if shadow.save_png(OUT + id + "_shadow.png") != OK: return false
	viewport.size = Vector2i(352, 352)
	_angle(0)
	kit.pose(0.0)
	var portrait := await _grab()
	var crop := portrait.get_used_rect().grow(6).intersection(Rect2i(Vector2i.ZERO, portrait.get_size()))
	if portrait.get_region(crop).save_png(OUT + id + "_portrait.png") != OK: return false
	print("BAKED ", id, " ", atlas.get_size(), " portrait ", crop.size)
	return true

func _bake_growth(id: String) -> bool:
	const DIRECTORY := "res://assets/growth/baked/"
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK: return false
	var size := Layout.CAPTURE_SIZE
	viewport.size = Vector2i(size, size)
	var crop := Rect2i((viewport.size - Layout.FRAME) / 2, Layout.FRAME)
	var strip := Image.create(Layout.FRAME.x, Layout.FRAME.y * Layout.DIRECTIONS, false, Image.FORMAT_RGBA8)
	for row in Layout.DIRECTIONS:
		_angle(row)
		var frame := await _grab()
		if not crop.grow(-1).encloses(frame.get_used_rect()) or frame.get_used_rect().size.x < 12:
			push_error("Invalid growth silhouette: %s facing %d" % [id, row])
			return false
		strip.blit_rect(frame, crop, Vector2i(0, row * Layout.FRAME.y))
	print("BAKED GROWTH ", id)
	return strip.save_png(DIRECTORY + id + ".png") == OK
