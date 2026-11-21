extends Node3D
## Terrain, scenery, illumination and weather share the board's world coordinates.

const DistrictLand := preload("res://scripts/world/district_land.gd")
const DistrictProps := preload("res://scripts/world/district_props.gd")
const Crossing := preload("res://scripts/world/river_crossing.gd")
const Fence := preload("res://scripts/world/workspace_fence.gd")
const Grade := preload("res://assets/shaders/environment_grade.gdshader")
const Contour := preload("res://assets/shaders/relief_contour.gdshader")
const Column := preload("res://assets/shaders/sun_column.gdshader")

const LIGHT := {
	"forest": [Color("ffe1b4"), Color("889ec2"), Color("726a91"), Color("f5a6bd")],
	"desert": [Color("ffd4a2"), Color("af9bc8"), Color("b28eac"), Color("ffb1a1")],
	"volcano": [Color("ffab86"), Color("9696c4"), Color("875676"), Color("fd997e")],
	"snow": [Color("ffdfd5"), Color("93b7dc"), Color("a2a8d2"), Color("f4bed9")]
}
const CLEAR_SUN := 0.96
var biome := "forest"
var land := DistrictLand.new()
var env := Environment.new()
var sun := DirectionalLight3D.new()
var _weather_nodes: Dictionary = {}
var _weather_mix := Color.WHITE
var _target_tint := Color.WHITE
var _sun_target := 0.96

func build(biome_id: String, seed_value: int) -> void:
	biome = biome_id
	_build_lights()
	land.name = "Landscape"
	add_child(land)
	land.build(biome, seed_value)
	var props := DistrictProps.new()
	props.name = "WoodlandAndRock"
	add_child(props)
	props.build(biome, seed_value, land)
	var bridge := Crossing.new()
	bridge.name = "UpstreamCrossing"
	add_child(bridge)
	bridge.build(biome, land)
	var fence := Fence.new()
	fence.name = "WorkspaceFence"
	add_child(fence)
	fence.build(biome, land)
	_grazing_light()
	_atmosphere()
	_pixel_pass()

func _build_lights() -> void:
	var palette: Array = LIGHT[biome]
	_sun_target = CLEAR_SUN
	var world := WorldEnvironment.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Data.palette(biome, "sky_top")
	atmosphere.sky_horizon_color = palette[3]
	atmosphere.ground_horizon_color = palette[2]
	atmosphere.ground_bottom_color = Data.palette(biome, "ground")
	atmosphere.sun_angle_max = 9.0
	atmosphere.sky_curve = 0.17
	var sky := Sky.new()
	sky.sky_material = atmosphere
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = palette[1]
	env.ambient_light_energy = 0.49
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = palette[2]
	env.fog_light_energy = 0.94
	# The camera sits 60 units from its focus. Start the distance haze
	# beyond the far bank of the planting area in the default framing.
	env.fog_depth_begin = 75.0
	env.fog_depth_end = 130.0
	env.fog_depth_curve = 0.85
	env.fog_aerial_perspective = 0.28
	env.fog_sky_affect = 0.40
	world.environment = env
	add_child(world)
	sun.name = "Sun"
	sun.light_color = palette[0]
	sun.light_energy = _sun_target
	sun.rotation_degrees = Vector3(-41, -43, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.65
	sun.directional_shadow_max_distance = 104.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyBounce"
	fill.light_color = Data.palette(biome, "ambient")
	fill.light_energy = 0.19
	fill.rotation_degrees = Vector3(-28, 139, 0)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

func _grazing_light() -> void:
	# Break the directional wash into a cool channel and a warm opening.
	# Both lamps illuminate actual surfaces, including moving machine parts.
	var colors: Dictionary = {
		"forest": [Color("80f6db"),Color("ffb580")],
		"desert": [Color("94ced3"),Color("ffb687")],
		"volcano": [Color("acafe3"),Color("ff8055")],
		"snow": [Color("a4edff"),Color("ffd1d9")]
	}
	# Anchor the cold reflection and the amber clearing to the actual mouths.
	var mouth_focus: Array[Vector3] = []
	for sign_z: float in [-1., 1.]:
		var z := sign_z * (land.EDGE + 1.3)
		var banks := land.river_span_at(z)
		mouth_focus.append(land.to_global(Vector3((banks.x + banks.y) * .5, 0, z)))
	for i in 2:
		var pool := SpotLight3D.new()
		pool.name = "RiverLight" if i == 0 else "BankLight"
		var focus: Vector3 = mouth_focus[i] * (0.76 if i == 0 else 0.88)
		pool.position = focus + (Vector3(1.5,6.7,0.8) if i == 0 else Vector3(-3.3,8.2,-3.5))
		add_child(pool)
		pool.look_at(focus,Vector3.UP)
		pool.spot_range = 18.0
		pool.spot_angle = 36.0 if i == 0 else 41.0
		pool.spot_attenuation = 0.8
		pool.spot_angle_attenuation = 1.5
		pool.light_color = colors[biome][i]
		pool.light_energy = 1.65 if i == 0 else 2.08

func _atmosphere() -> void:
	# Finite shafts are world volumes; both ends remain fixed as the camera turns.
	if biome in ["forest","snow"]:
		var light_vector := sun.global_basis.z
		var ray := CylinderMesh.new()
		ray.height = 2.0
		ray.top_radius = 1.0
		ray.bottom_radius = 1.0
		ray.radial_segments = 16
		ray.rings = 0
		var banks := land.river_span_at(land.crossing_z)
		var bridge := land.to_global(Vector3(banks.x,0,land.crossing_z))
		var clearing := Vector2(bridge.x,bridge.z)
		for position_xz: Vector2 in [clearing, clearing + Vector2(1.9,0.6), -clearing * .83]:
			var shaft := MeshInstance3D.new()
			var ink := ShaderMaterial.new()
			ink.shader = Column
			ink.set_shader_parameter("radiance", Color(1.0, 0.82, 0.54, 0.119) if biome == "forest" else Color(0.80,0.92,1.0,0.093))
			ink.set_shader_parameter("seed", position_xz.x)
			shaft.mesh = ray
			shaft.material_override = ink
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ground := Vector3(position_xz.x,land.height_at(position_xz.x,position_xz.y),position_xz.y)
			var side := light_vector.cross(Vector3.BACK).normalized()
			shaft.transform = Transform3D(Basis(side*1.0,light_vector*6.4,side.cross(light_vector)*1.2),ground+light_vector*6.0)
			add_child(shaft)
	match biome:
		"forest": MeshKit.particles(self, Vector3(0, 1.3, 0), Color("f8d778"), 54, Vector3(11, 1.8, 11), Vector3(0.04, 0.18, -0.09), 0.1, 6.0, 1.0)
		"desert": MeshKit.particles(self, Vector3(0, 1, 0), Color("e7b586"), 48, Vector3(13, 1, 13), Vector3(1.2, 0.1, 0.35), 0.085, 4.2)
		"volcano": MeshKit.particles(self, Vector3(0, 0, 0), Color("ff9245"), 54, Vector3(13, 1, 13), Vector3(0.1, 0.75, 0), 0.11, 5.0, 1.0)
		"snow": MeshKit.particles(self, Vector3(0, 5, 0), Color("e4f7ff"), 95, Vector3(14, 1, 14), Vector3(0.22, -0.78, 0.17), 0.10, 8.5)

func _pixel_pass() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	var outline := MeshInstance3D.new()
	outline.name = "ReliefContours"
	outline.mesh = quad
	outline.custom_aabb = AABB(Vector3(-140,-60,-140),Vector3(280,180,280))
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var contour := ShaderMaterial.new()
	contour.shader = Contour
	contour.render_priority = -120
	var weather_seed := hash([Land.world_seed, biome, "cloud cover"])
	contour.set_shader_parameter("cloud_phase", Vector2(weather_seed & 255, (weather_seed >> 8) & 255) * .13)
	contour.set_shader_parameter("shade_tint", LIGHT[biome][1].darkened(.76))
	contour.set_shader_parameter("cloud_opacity", .25 if biome in ["forest", "volcano"] else .18)
	outline.material_override = contour
	add_child(outline)
	var layer := CanvasLayer.new()
	layer.name = "WorldPixelGrade"
	layer.layer = 1
	add_child(layer)
	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = Grade
	material.set_shader_parameter("highlight_color", LIGHT[biome][0])
	material.set_shader_parameter("shadow_color", Data.palette(biome,"fog"))
	overlay.material = material
	layer.add_child(overlay)

func set_weather(effect_id: String) -> void:
	for key: String in _weather_nodes: _weather_nodes[key].emitting = false
	_target_tint = Color.WHITE
	_sun_target = CLEAR_SUN
	match effect_id:
		"rain":
			_target_tint = Color("c0cce0")
			_sun_target = 0.60
			_weather("rain", Color("abc8df"), 220, Vector3(0.3, -8.0, 0.2), 0.07, 1.6)
		"firefly_swarm": _weather("fireflies", Color("e6ec79"), 75, Vector3(0, 0.3, 0), 0.16, 5.0, 1.7, 1.0)
		"sandstorm":
			_target_tint = Color("f6cbaa")
			_weather("sand", Color("f4be86"), 220, Vector3(6.0, 0.2, 1.5), 0.17, 3.0)
		"heatwave": _sun_target = 1.06
		"ash_fall":
			_target_tint = Color("d9ccdc")
			_weather("ash", Color("b7a0ad"), 150, Vector3(0.2, -1.0, 0.1), 0.13, 7.0)
		"eruption":
			_target_tint = Color("ffc4b5")
			_weather("embers", Color("ff8845"), 115, Vector3(0.3, 2.0, 0), 0.14, 3.2, 1.4, 0.5)
		"blizzard":
			_target_tint = Color("c8d9ef")
			_weather("blizzard", Color("f0f5ff"), 270, Vector3(4.0, -2.5, 1.0), 0.14, 3.5)
		"clear_thaw": _sun_target = 1.00

func _weather(key: String, color: Color, amount: int, velocity: Vector3, size: float, life: float, emission := 0.0, height := 6.0) -> void:
	if not _weather_nodes.has(key):
		_weather_nodes[key] = MeshKit.particles(self, Vector3(-velocity.x * 0.5, height, -velocity.z * 0.5), color, amount, Vector3(14, 1.5, 14), velocity, size, life, emission)
	_weather_nodes[key].emitting = true

func _process(delta: float) -> void:
	var smoothing := 1.0 - exp(-delta * 1.8)
	if not _weather_mix.is_equal_approx(_target_tint):
		_weather_mix = _weather_mix.lerp(_target_tint, smoothing)
		env.fog_light_color = LIGHT[biome][2] * _weather_mix
		env.ambient_light_color = LIGHT[biome][1] * _weather_mix
	sun.light_energy = lerpf(sun.light_energy, _sun_target, smoothing)
