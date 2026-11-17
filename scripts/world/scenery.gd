extends Node3D
## Procedural 3D backdrop for a biome: the diorama plateau the 11x11 plot sits on,
## the landscape around it, ambient particles, lanterns and weather.
## HD pixel-art environment sprites, textured geometry and compatibility-friendly lighting.

const GROUND_Y: float = -2.6
const PLATEAU_HALF: float = 9.6

var biome: String = "forest"
var _rng := RandomNumberGenerator.new()
var _sway: Array = []          # [node, phase, amount]
var _flicker: Array = []       # [OmniLight3D, base_energy, phase]
var _pulse: Array = []         # [StandardMaterial3D, base, speed]
var _weather_nodes: Dictionary = {}
var _t: float = 0.0
var sun: DirectionalLight3D
var env: Environment
static var _atlas: Texture2D
static var _surface_textures: Dictionary = {}

func build(biome_id: String, seed_value: int) -> void:
	biome = biome_id
	_rng.seed = hash("scenery|%s|%d" % [biome, seed_value])
	_build_environment()
	_build_ground()
	_build_plateau()
	match biome:
		"forest": _forest()
		"desert": _desert()
		"volcano": _volcano()
		"snow": _snow()
	_lanterns()
	_paint_environment(self)
	_atmosphere()

func pal(key: String) -> Color:
	return Data.palette(biome, key)

# ------------------------------------------------------------------ environment
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = pal("sky_top")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pal("ambient")
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = pal("fog")
	env.fog_density = 1.0
	env.fog_depth_begin = 68.0
	env.fog_depth_end = 112.0
	env.fog_depth_curve = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.88
	env.adjustment_contrast = 1.1
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = pal("sun")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.62
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 80.0
	sun.rotation_degrees = Vector3(-52, -28, 0)
	add_child(sun)

func _build_ground() -> void:
	MeshKit.plane(self, Vector2(240, 240), Vector3(0, GROUND_Y, 0), pal("ground"))

func _build_plateau() -> void:
	var cliff: Color = pal("cliff")
	var top: Color = pal("ground").lerp(cliff, 0.35)
	var depth: float = -GROUND_Y
	# Stepped strata give the diorama block a cut-away, layered look.
	var bands: int = 4
	for i in range(bands):
		var h: float = depth / bands
		var grow: float = 0.08 * i + (0.12 if i % 2 == 1 else 0.0)
		var c: Color = cliff.darkened(0.06 * i) if i % 2 == 0 else cliff.lightened(0.07)
		MeshKit.box(self, Vector3(PLATEAU_HALF * 2 + grow, h, PLATEAU_HALF * 2 + grow), Vector3(0, -0.8 - h * (i + 0.5), 0), c)
	MeshKit.box(self, Vector3(PLATEAU_HALF * 2 + 0.3, 0.36, PLATEAU_HALF * 2 + 0.3), Vector3(0, -0.98, 0), top)
	# Rim stones
	for side in range(4):
		for k in range(9):
			var t: float = -PLATEAU_HALF + 1.0 + k * 2.2
			var p := Vector3(t, 0.0, PLATEAU_HALF + 0.05)
			if side == 1: p = Vector3(t, 0.0, -PLATEAU_HALF - 0.05)
			if side == 2: p = Vector3(PLATEAU_HALF + 0.05, 0.0, t)
			if side == 3: p = Vector3(-PLATEAU_HALF - 0.05, 0.0, t)
			if _rng.randf() < 0.55:
				MeshKit.ball(self, p + Vector3(0, -0.05, 0), Vector3(_rng.randf_range(0.5, 1.0), _rng.randf_range(0.25, 0.45), _rng.randf_range(0.5, 1.0)), cliff.lightened(0.12), 6, 3)

func _ring_pos(min_r: float, max_r: float) -> Vector3:
	var a: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(min_r, max_r)
	return Vector3(cos(a) * r, GROUND_Y, sin(a) * r)

func _max_height(p: Vector3) -> float:
	var d: float = maxf(absf(p.x), absf(p.z))
	return clampf((d - 11.0) * 0.7, 0.8, 16.0)

func _scatter(count: int, min_r: float, max_r: float, maker: Callable) -> void:
	for i in range(count):
		var p: Vector3 = _ring_pos(min_r, max_r)
		if maxf(absf(p.x), absf(p.z)) < PLATEAU_HALF + 1.4: continue
		maker.call(p, _max_height(p))

func _sway_add(n: Node3D, amount: float) -> void:
	_sway.append([n, _rng.randf() * TAU, amount])

# ------------------------------------------------------------------ biomes
func _conifer(p: Vector3, max_h: float, _col: Color, snow_cap: bool = false) -> void:
	_prop(3 if snow_cap else 0, p, minf(_rng.randf_range(4.5, 7.0), max_h))

func _round_tree(p: Vector3, max_h: float, _col: Color) -> void:
	_prop(4, p, minf(_rng.randf_range(3.6, 5.6), max_h))

func _rock(p: Vector3, size: float, col: Color) -> void:
	if biome == "snow": _prop(7, p, size * 1.5)
	elif biome == "volcano": _prop(2, p, size * 1.8)
	elif biome == "desert": _prop(5, p, size * 1.5)
	else:
		var rock: MeshInstance3D = MeshKit.ball(self, p + Vector3(0, size * 0.25, 0), Vector3(size, size * 0.6, size), col, 6, 3)
		rock.rotation.y = _rng.randf() * TAU

func _forest() -> void:
	var dark := Color("17364a")
	var mid := Color("31545c")
	_scatter(70, 12.0, 34.0, func(p: Vector3, mh: float) -> void:
		var roll: float = _rng.randf()
		if roll < 0.5: _conifer(p, mh, dark if _rng.randf() < 0.5 else mid)
		elif roll < 0.8: _round_tree(p, mh, Color("406458").lerp(Color("60714f"), _rng.randf()))
		elif roll < 0.9: _rock(p, _rng.randf_range(0.6, 1.4), Color("5d6058"))
		else:
			# giant mushroom
			var h: float = minf(_rng.randf_range(1.2, 2.6), mh)
			MeshKit.cyl(self, p + Vector3(0, h * 0.5, 0), 0.14, 0.2, h, Color("e8dcc0"), 6)
			MeshKit.ball(self, p + Vector3(0, h, 0), Vector3(h * 0.9, h * 0.38, h * 0.9), Color("b8604a"), 7, 3))
	# A winding stream
	var water := Color("2f4f55")
	for i in range(30):
		var a: float = -1.2 + i * 0.06
		var r: float = 15.5 + sin(i * 0.35) * 1.4
		var seg: MeshInstance3D = MeshKit.box(self, Vector3(1.4, 0.04, 2.4), Vector3(cos(a) * r, GROUND_Y + 0.02, sin(a) * r), water, 0.0, false)
		seg.rotation.y = -a
		seg.material_override = _water_material()
	MeshKit.particles(self, Vector3(0, 1.6, 0), Color("e6f07a"), 40, Vector3(12, 1.6, 12), Vector3(0, 0.15, 0), 0.16, 6.0, 1.5)

func _desert() -> void:
	var sand := pal("ground")
	_scatter(24, 13.0, 36.0, func(p: Vector3, mh: float) -> void:
		var h: float = minf(_rng.randf_range(1.2, 3.0), mh)
		MeshKit.ball(self, p, Vector3(_rng.randf_range(6, 11), h * 2.0, _rng.randf_range(4, 8)), sand.lightened(_rng.randf_range(0.0, 0.12)), 8, 4))
	_scatter(10, 18.0, 36.0, func(p: Vector3, mh: float) -> void:
		var h: float = minf(_rng.randf_range(3.5, 8.0), mh)
		var r: float = _rng.randf_range(2.0, 4.0)
		var bands: int = 3
		for i in range(bands):
			var c: Color = Color("b0704a").lerp(Color("d9a070"), float(i) / bands)
			MeshKit.cyl(self, p + Vector3(0, h * (i + 0.5) / bands, 0), r * (1.0 - i * 0.08), r * (1.05 - i * 0.08), h / bands, c, 6))
	_scatter(26, 11.5, 30.0, func(p: Vector3, mh: float) -> void:
		_prop(1, p, minf(_rng.randf_range(2.0, 3.5), mh)))
	# Ancient arch
	var arch := Vector3(-17, GROUND_Y, -13)
	for side in [-1.6, 1.6]:
		MeshKit.cyl(self, arch + Vector3(side, 2.2, 0), 0.6, 0.8, 4.4, Color("b07a52"), 6)
	MeshKit.box(self, Vector3(5.0, 0.9, 1.4), arch + Vector3(0, 4.7, 0), Color("c08860"))
	MeshKit.particles(self, Vector3(0, 0.5, 0), Color("e8c890"), 50, Vector3(16, 1.2, 16), Vector3(1.2, 0.05, 0.3), 0.22, 5.0)

func _volcano() -> void:
	var rock := Color("2e2729")
	# The big cone sits far behind the default view.
	var cone := Vector3(-24, GROUND_Y, -24)
	MeshKit.cyl(self, cone + Vector3(0, 7.0, 0), 4.5, 15.0, 14.0, Color("3a2e2e"), 9)
	MeshKit.cyl(self, cone + Vector3(0, 14.2, 0), 3.6, 4.6, 0.6, Color("4a3434"), 9)
	var crater: MeshInstance3D = MeshKit.ball(self, cone + Vector3(0, 14.4, 0), Vector3(6.4, 0.6, 6.4), Color("ff7a3c"), 9, 3, 2.5)
	_pulse_add(crater, 2.5, 1.3)
	MeshKit.particles(self, cone + Vector3(0, 16, 0), Color("7a6a68"), 30, Vector3(1.5, 0.5, 1.5), Vector3(0.4, 1.8, 0.2), 2.2, 8.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff7a3c")
	glow.omni_range = 26.0
	glow.light_energy = 2.0
	glow.position = cone + Vector3(0, 16, 0)
	add_child(glow)
	_flicker.append([glow, 2.0, 0.0])
	_scatter(40, 12.0, 34.0, func(p: Vector3, mh: float) -> void:
		var roll: float = _rng.randf()
		if roll < 0.55:
			var h: float = minf(_rng.randf_range(1.5, 5.0), mh)
			_prop(2, p, h * 1.4)
		elif roll < 0.85: _rock(p, _rng.randf_range(0.8, 2.0), rock.lightened(0.08))
		else:
			_prop(6, p, minf(_rng.randf_range(2.0, 3.6), mh)))
	# Lava rivers
	for river in range(3):
		var a0: float = _rng.randf() * TAU
		var r0: float = 12.5
		for i in range(12):
			var a: float = a0 + sin(i * 0.6 + river) * 0.25
			var r: float = r0 + i * 1.6
			var seg: MeshInstance3D = MeshKit.box(self, Vector3(1.9, 0.08, 0.7), Vector3(cos(a) * r, GROUND_Y + 0.03, sin(a) * r), Color("ff6a2a"), 2.2, false)
			seg.rotation.y = -a + PI * 0.5
			if i == 0: _pulse_add(seg, 2.2, 0.9)
	MeshKit.particles(self, Vector3(0, -1.0, 0), Color("ff9a4a"), 45, Vector3(18, 0.5, 18), Vector3(0.1, 0.8, 0.0), 0.14, 5.0, 2.0)

func _snow() -> void:
	_scatter(14, 20.0, 38.0, func(p: Vector3, mh: float) -> void:
		var h: float = minf(_rng.randf_range(7.0, 15.0), mh)
		var r: float = h * _rng.randf_range(0.55, 0.8)
		MeshKit.cyl(self, p + Vector3(0, h * 0.5, 0), 0.05, r, h, Color("56636e").lerp(Color("6e7c88"), _rng.randf()), 6).rotation.y = _rng.randf() * TAU
		MeshKit.cyl(self, p + Vector3(0, h * 0.82, 0), 0.04, r * 0.36, h * 0.36, Color("eef4f8"), 6))
	_scatter(55, 12.0, 30.0, func(p: Vector3, mh: float) -> void:
		var roll: float = _rng.randf()
		if roll < 0.65: _conifer(p, mh, Color("2f4a44"), true)
		elif roll < 0.85:
			var h: float = minf(_rng.randf_range(0.8, 2.4), mh)
			MeshKit.cyl(self, p + Vector3(0, h * 0.5, 0), 0.04, _rng.randf_range(0.25, 0.5), h, Color("a8d8ec"), 4, 0.25).rotation.z = _rng.randf_range(-0.3, 0.3)
		else: _rock(p, _rng.randf_range(0.6, 1.6), Color("dfe8ee")))
	var lake: MeshInstance3D = MeshKit.plane(self, Vector2(10, 7), Vector3(15, GROUND_Y + 0.03, 6), Color("a8cede"), 0.2)
	lake.material_override = _water_material()
	MeshKit.particles(self, Vector3(0, 8, 0), Color("ffffff"), 120, Vector3(22, 1, 22), Vector3(0.3, -1.2, 0.2), 0.14, 9.0)

func _lanterns() -> void:
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var p := Vector3(corner.x * (PLATEAU_HALF + 0.7), GROUND_Y, corner.y * (PLATEAU_HALF + 0.7))
		MeshKit.box(self, Vector3(0.18,3.1,0.18), p+Vector3(0,1.55,0), Color("243244"))
		MeshKit.box(self, Vector3(0.64,0.1,0.52), p+Vector3(0,3.28,0), Color("344359"))
		MeshKit.box(self, Vector3(0.54,0.1,0.48), p+Vector3(0,2.55,0), Color("1c2439"))
		var lamp: MeshInstance3D = MeshKit.box(self, Vector3(0.34,0.62,0.30), p+Vector3(0,2.92,0), Color("ff9e48"), 0.85)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for x: float in [-0.22,0.22]:
			for z: float in [-0.20,0.20]: MeshKit.box(self, Vector3(0.055,0.72,0.055), p+Vector3(x,2.92,z), Color("29364b"))
		var light := OmniLight3D.new()
		light.position = p+Vector3(0,3.0,0)
		light.light_color = Color("ffc087")
		light.light_energy = 2.2
		light.omni_range = 9.0
		add_child(light)
		_flicker.append([light,2.2,_rng.randf()*TAU])
		_glow(p+Vector3(0,2.94,0),Vector2(2.4,2.4),Color(1.0,0.52,0.22,0.30),false)
		_glow(p+Vector3(0,0.06,0),Vector2(5.5,5.5),Color(1.0,0.44,0.16,0.12),false,true)

func _pulse_add(mi: MeshInstance3D, base: float, speed: float) -> void:
	var m: StandardMaterial3D = mi.material_override.duplicate()
	mi.material_override = m
	_pulse.append([m, base, speed])

# ------------------------------------------------------------------ weather
func set_weather(effect_id: String) -> void:
	for k: String in _weather_nodes: _weather_nodes[k].emitting = false
	if sun != null: sun.light_energy = 0.9
	match effect_id:
		"rain": _weather("rain", Color("9fc0d8"), 220, Vector3(0.2, -9.0, 0.1), 0.08, 1.4)
		"firefly_swarm": _weather("fireflies", Color("f0f07a"), 80, Vector3(0, 0.3, 0), 0.2, 5.0, 2.0, 2.0)
		"sandstorm": _weather("sand", Color("d9a86a"), 260, Vector3(6.0, 0.2, 1.5), 0.3, 3.0)
		"heatwave": sun.light_energy = 0.9
		"ash_fall": _weather("ash", Color("9a9090"), 160, Vector3(0.2, -1.0, 0.1), 0.18, 7.0)
		"eruption": _weather("embers", Color("ff7a3c"), 140, Vector3(0, 3.0, 0), 0.16, 3.0, 2.5, -1.0)
		"blizzard": _weather("blizzard", Color("ffffff"), 300, Vector3(5.0, -2.5, 1.0), 0.16, 3.0)
		"clear_thaw": sun.light_energy = 0.85

func _weather(key: String, color: Color, amount: int, vel: Vector3, size: float, life: float, emission: float = 0.0, height: float = 8.0) -> void:
	if not _weather_nodes.has(key):
		var y: float = height if height >= 0.0 else 0.5
		_weather_nodes[key] = MeshKit.particles(self, Vector3(-vel.x * 0.5, y, -vel.z * 0.5), color, amount, Vector3(16, 1.5, 16), vel, size, life, emission)
	_weather_nodes[key].emitting = true

# ------------------------------------------------------------------ animation
func _process(delta: float) -> void:
	_t += delta
	for s: Array in _sway:
		var n: Node3D = s[0]
		n.rotation.z = sin(_t * 0.9 + float(s[1])) * float(s[2])
		n.rotation.x = cos(_t * 0.7 + float(s[1])) * float(s[2]) * 0.6
	for f: Array in _flicker:
		var l: OmniLight3D = f[0]
		l.light_energy = float(f[1]) * (0.88 + 0.12 * sin(_t * 7.0 + float(f[2])) * sin(_t * 3.1 + float(f[2]) * 2.0))
	for p: Array in _pulse:
		var m: StandardMaterial3D = p[0]
		m.emission_energy_multiplier = float(p[1]) * (0.75 + 0.25 * sin(_t * float(p[2])))

func _prop(index: int, pos: Vector3, height: float) -> void:
	if _atlas == null: _atlas = load("res://assets/environment/props_hd.png")
	var regions: Array[Rect2] = [Rect2(0,0,320,625),Rect2(340,170,265,430),Rect2(620,75,320,525),Rect2(940,0,340,630),Rect2(0,680,375,500),Rect2(330,760,315,425),Rect2(645,710,295,475),Rect2(935,750,345,440)]
	var region: Rect2 = regions[index]
	var ratio: Vector2 = Vector2(_atlas.get_size()) / 1280.0
	region.position *= ratio
	region.size *= ratio
	var tex := AtlasTexture.new()
	tex.atlas = _atlas
	tex.region = region
	tex.filter_clip = true
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = height / region.size.y
	sprite.offset.y = region.size.y * 0.5
	sprite.position = pos
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.shaded = false
	sprite.modulate = Color(0.82,0.88,0.98)
	add_child(sprite)
	var shadow: MeshInstance3D = MeshKit.plane(self, Vector2(height*0.7,height*0.45),pos+Vector3(0,0.04,0),Color(0.015,0.025,0.05,0.48))
	shadow.material_override = shadow.material_override.duplicate()
	shadow.material_override.albedo_texture = MeshKit._soft_dot()

func _surface_texture() -> Texture2D:
	if _surface_textures.has(biome): return _surface_textures[biome]
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome+"pixel-surface")
	for y in range(128):
		for x in range(128):
			var n: float = 0.83 + sin(float(x) * TAU / 32.0) * sin(float(y) * TAU / 64.0) * 0.10 + rng.randf_range(-0.025,0.025)
			if rng.randf() < 0.02: n *= 0.88
			var col := Color(n*0.84,n*0.91,n,1)
			if biome == "forest" and sin(float(x)*0.1)*cos(float(y)*0.12) > 0.72: col = Color(n*0.72,n*0.85,n*0.78)
			image.set_pixel(x,y,col)
	var texture := ImageTexture.create_from_image(image)
	_surface_textures[biome] = texture
	return texture

func _paint_environment(root: Node) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var current: StandardMaterial3D = child.material_override
			if current.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not current.emission_enabled:
				var material: StandardMaterial3D = current.duplicate()
				material.albedo_texture = _surface_texture()
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				var bounds: Vector3 = child.mesh.get_aabb().size
				var repeats: float = maxf(maxf(bounds.x,bounds.y),bounds.z) * 0.18
				material.uv1_scale = Vector3(repeats,repeats,1)
				material.roughness = 0.92
				child.material_override = material
		_paint_environment(child)

func _water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/environment_water.gdshader")
	material.set_shader_parameter("deep_color",Color("10283e") if biome != "snow" else Color("243a58"))
	material.set_shader_parameter("reflection_color",Color("b270a5") if biome != "snow" else Color("899dcc"))
	return material

func _glow(pos: Vector3, size: Vector2, color: Color, beam: bool, horizontal: bool = false) -> void:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	node.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/environment_glow.gdshader")
	material.set_shader_parameter("glow_color",color)
	material.set_shader_parameter("beam",beam)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	node.rotation = Vector3(-PI*0.5,0,0) if horizontal else Vector3(-0.45,PI*0.25,0)
	add_child(node)

func _atmosphere() -> void:
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("bd8bb8") if biome != "volcano" else Color("ca756c")
	rim.light_energy = 0.20
	rim.rotation_degrees = Vector3(-18,145,0)
	add_child(rim)
	for i in range(4):
		var p := Vector3(-14+i*8,7.0,-15)
		_glow(p,Vector2(3.4,15.0),Color(0.38,0.60,0.82,0.11),true)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = load("res://assets/shaders/environment_grade.gdshader")
	rect.material = grade
	layer.add_child(rect)
