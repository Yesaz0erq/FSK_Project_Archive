extends Node3D
## Procedural 3D backdrop for a biome: the diorama plateau the 11x11 plot sits on,
## the landscape around it, ambient particles, lanterns and weather.
## Everything is low-poly and built from MeshKit primitives.

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
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = pal("fog")
	env.fog_density = 1.0
	env.fog_depth_begin = 52.0
	env.fog_depth_end = 95.0
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
	sun.light_energy = 0.9
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
func _conifer(p: Vector3, max_h: float, col: Color, snow_cap: bool = false) -> void:
	var h: float = minf(_rng.randf_range(3.0, 6.5), max_h)
	var n := Node3D.new()
	n.position = p
	add_child(n)
	MeshKit.cyl(n, Vector3(0, h * 0.12, 0), 0.12, 0.18, h * 0.24, Color("4a3424"), 5)
	for i in range(3):
		var y: float = h * (0.28 + i * 0.22)
		var r: float = h * (0.30 - i * 0.07)
		MeshKit.cyl(n, Vector3(0, y, 0), 0.02, r, h * 0.34, col.lightened(i * 0.05), 6)
		if snow_cap: MeshKit.cyl(n, Vector3(0, y + h * 0.1, 0), 0.02, r * 0.55, h * 0.16, Color("e8f0f4"), 6)
	_sway_add(n, 0.025)

func _round_tree(p: Vector3, max_h: float, col: Color) -> void:
	var h: float = minf(_rng.randf_range(2.4, 4.6), max_h)
	var n := Node3D.new()
	n.position = p
	add_child(n)
	MeshKit.cyl(n, Vector3(0, h * 0.3, 0), 0.12, 0.2, h * 0.6, Color("4e3826"), 5)
	MeshKit.ball(n, Vector3(0, h * 0.72, 0), Vector3(h * 0.55, h * 0.48, h * 0.55), col, 7, 4)
	MeshKit.ball(n, Vector3(h * 0.18, h * 0.86, 0.1), Vector3(h * 0.32, h * 0.3, h * 0.32), col.lightened(0.08), 6, 3)
	_sway_add(n, 0.03)

func _rock(p: Vector3, s: float, col: Color) -> void:
	MeshKit.ball(self, p + Vector3(0, s * 0.25, 0), Vector3(s, s * _rng.randf_range(0.45, 0.8), s * _rng.randf_range(0.7, 1.1)), col, 6, 3)

func _forest() -> void:
	var dark := Color("2f4a37")
	var mid := Color("46694a")
	_scatter(70, 12.0, 34.0, func(p: Vector3, mh: float) -> void:
		var roll: float = _rng.randf()
		if roll < 0.5: _conifer(p, mh, dark if _rng.randf() < 0.5 else mid)
		elif roll < 0.8: _round_tree(p, mh, Color("5e7f45").lerp(Color("7c8f3e"), _rng.randf()))
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
		var h: float = minf(_rng.randf_range(1.0, 2.4), mh)
		var n := Node3D.new()
		n.position = p
		add_child(n)
		var c := Color("6f8a4a")
		MeshKit.cyl(n, Vector3(0, h * 0.5, 0), 0.16, 0.2, h, c, 6)
		MeshKit.cyl(n, Vector3(0.28, h * 0.55, 0), 0.09, 0.1, h * 0.35, c.lightened(0.05), 5)
		MeshKit.cyl(n, Vector3(-0.26, h * 0.42, 0), 0.08, 0.1, h * 0.3, c.lightened(0.05), 5)
		MeshKit.ball(n, Vector3(0, h + 0.05, 0), Vector3(0.22, 0.18, 0.22), Color("e49aa8"), 5, 3)
		_sway_add(n, 0.01))
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
			MeshKit.cyl(self, p + Vector3(0, h * 0.5, 0), 0.05, _rng.randf_range(0.5, 1.1), h, Color("241e24"), 4).rotation.y = _rng.randf() * TAU
		elif roll < 0.85: _rock(p, _rng.randf_range(0.8, 2.0), rock.lightened(0.08))
		else:
			# dead tree
			var h2: float = minf(_rng.randf_range(1.6, 3.0), mh)
			MeshKit.cyl(self, p + Vector3(0, h2 * 0.5, 0), 0.06, 0.16, h2, Color("1e1816"), 4)
			MeshKit.cyl(self, p + Vector3(0.3, h2 * 0.75, 0), 0.03, 0.06, h2 * 0.5, Color("1e1816"), 4).rotation.z = -0.8)
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
	MeshKit.plane(self, Vector2(10, 7), Vector3(15, GROUND_Y + 0.03, 6), Color("a8cede"), 0.2)
	MeshKit.particles(self, Vector3(0, 8, 0), Color("ffffff"), 120, Vector3(22, 1, 22), Vector3(0.3, -1.2, 0.2), 0.14, 9.0)

func _lanterns() -> void:
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := Vector3(corner.x * (PLATEAU_HALF + 0.9), GROUND_Y, corner.y * (PLATEAU_HALF + 0.9))
		MeshKit.cyl(self, p + Vector3(0, 1.9, 0), 0.09, 0.13, 3.8, Color("4a3424"), 5)
		MeshKit.box(self, Vector3(0.7, 0.08, 0.08), p + Vector3(0, 3.7, 0), Color("4a3424"))
		var lamp: MeshInstance3D = MeshKit.ball(self, p + Vector3(0.3, 3.4, 0), Vector3(0.36, 0.44, 0.36), Color("ffcf6b"), 6, 4, 2.4)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := OmniLight3D.new()
		l.light_color = Color("ffc070")
		l.omni_range = 7.5
		l.light_energy = 1.1
		l.position = p + Vector3(0.3, 3.2, 0)
		add_child(l)
		_flicker.append([l, 1.1, _rng.randf() * TAU])

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
		"heatwave": sun.light_energy = 1.4
		"ash_fall": _weather("ash", Color("9a9090"), 160, Vector3(0.2, -1.0, 0.1), 0.18, 7.0)
		"eruption": _weather("embers", Color("ff7a3c"), 140, Vector3(0, 3.0, 0), 0.16, 3.0, 2.5, -1.0)
		"blizzard": _weather("blizzard", Color("ffffff"), 300, Vector3(5.0, -2.5, 1.0), 0.16, 3.0)
		"clear_thaw": sun.light_energy = 1.35

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
