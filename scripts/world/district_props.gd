extends Node3D
## Volumetric specimens. Each sculpt is built once, then instanced throughout
## a district with its roots on the same height field as the playable plots.

const SPECIMEN_MATERIAL := preload("res://assets/shaders/district_specimen.gdshader")
const PLOT_EDGE := 8.8
const SPECIES := {
	"forest": ["elder", "bough", "fern", "bells"],
	"desert": ["arch", "hoodoo", "agave", "salt"],
	"volcano": ["organ", "chimney", "cinder", "sulfur"],
	"snow": ["fir", "ice_spire", "juniper", "frost"],
}
static var _models: Dictionary = {}
static var _material: ShaderMaterial
var _st: SurfaceTool
var _sculpt := RandomNumberGenerator.new()
var _locations := RandomNumberGenerator.new()

func build(biome: String, seed_value: int, terrain: Node3D) -> void:
	var species: Array = SPECIES[biome]
	var batches := {}
	_locations.seed = hash("district flora:%s:%d" % [biome, seed_value])
	var cover := FastNoiseLite.new()
	cover.seed = _locations.randi()
	cover.frequency = 0.081
	cover.fractal_octaves = 2
	# Widely spaced mature specimens with coppices, stone gardens and low
	# groundcover rooted in the clearings nearer the camera.
	for z in range(-11, 12):
		for x in range(-11, 12):
			var p := Vector2(x, z) * 4.3 + Vector2(_locations.randf_range(-1.85, 1.85), _locations.randf_range(-1.85, 1.85))
			var clearance := maxf(absf(p.x), absf(p.y)) - PLOT_EDGE
			if clearance < 0.70: continue
			var patch := cover.get_noise_2dv(p)
			if _locations.randf() > clampf(0.66 + patch * 0.70, 0.22, 0.93): continue
			var small := clearance < 3.8 or _locations.randf() < 0.22 - patch * 0.24
			var kind: String = species[_locations.randi_range(2, 3) if small else (1 if _locations.randf() < 0.30 else 0)]
			if biome == "desert" and not small:
				var erosion := _locations.randf()
				kind = "arch" if erosion < 0.085 else ("hoodoo" if erosion < 0.42 else "yardang")
			_place(batches, terrain, kind, p, _locations.randf_range(0.70, 1.35))
			if clearance < 16.0 or patch > 0.2:
				for j in _locations.randi_range(1, 3):
					var q := p + Vector2.from_angle(_locations.randf() * TAU) * _locations.randf_range(1.1, 2.8)
					_place(batches, terrain, species[_locations.randi_range(2, 3)], q, _locations.randf_range(0.57, 1.17))
	# Smaller tufts follow the fringe with a jittered spacing; patch noise
	# leaves openings at every angle instead of enclosing the board in a hedge.
	for z in range(-7, 8):
		for x in range(-7, 8):
			var q := Vector2(x, z) * 1.95 + Vector2(_locations.randf_range(-0.73, 0.73), _locations.randf_range(-0.73, 0.73))
			var edge := maxf(absf(q.x), absf(q.y)) - PLOT_EDGE
			if edge < 0.65 or edge > 4.7: continue
			if _locations.randf() > 0.48 + cover.get_noise_2dv(q) * 0.68: continue
			_place(batches, terrain, species[_locations.randi_range(2, 3)], q, _locations.randf_range(0.52, 0.95))
	for key: String in batches:
		var transforms: Array = batches[key]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _models[key]
		batch.instance_count = transforms.size()
		for i in transforms.size(): batch.set_instance_transform(i, transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = key
		node.multimesh = batch
		add_child(node)

func _place(batches: Dictionary, terrain: Node3D, kind: String, p: Vector2, size: float) -> void:
	var clearance := maxf(absf(p.x), absf(p.y)) - PLOT_EDGE
	if clearance < 0.62 or terrain.is_water_at(p.x, p.y): return
	if absf(p.y + 14.0) < 1.75 and absf(p.x) < 7.5: return
	var y: float = terrain.height_at(p.x, p.y)
	var key := "%s_%d" % [kind, _locations.randi_range(0, 2)]
	if not _models.has(key): _models[key] = _model(kind, key)
	var bounds: AABB = _models[key].get_aabb()
	var extent := maxf(bounds.size.x, bounds.size.z) * 0.57
	# A 33-degree orthographic sightline must still clear the nearest plot
	# when a specimen is between the camera and the board.
	size = minf(size, (clearance - 0.18) / maxf(0.2, extent))
	size = minf(size, (clearance * 0.57 + 0.48 - maxf(0.0, y)) / maxf(0.2, bounds.end.y + extent * 0.43))
	if size < 0.28: return
	var basis := Basis(Vector3.UP, _locations.randf() * TAU).scaled(Vector3.ONE * size)
	if not batches.has(key): batches[key] = []
	batches[key].append(Transform3D(basis, Vector3(p.x, y - 0.05 * size, p.y)))

func _model(kind: String, key: String) -> ArrayMesh:
	_sculpt.seed = hash("district sculpture/" + key)
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"elder": _elder()
		"bough": _bough()
		"fern": _fern()
		"bells": _bells()
		"arch": _arch()
		"hoodoo": _hoodoo()
		"yardang": _yardang()
		"agave": _agave()
		"salt": _salt()
		"organ": _organ()
		"chimney": _chimney()
		"cinder": _cinder()
		"sulfur": _sulfur()
		"fir": _fir()
		"ice_spire": _ice_spire()
		"juniper": _juniper()
		"frost": _frost()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SPECIMEN_MATERIAL
	_st.set_material(_material)
	_st.index()
	return _st.commit()

# The triangular facets have independent normals and share a pigment within
# each cut. Godot treats clockwise vertices as front-facing.
func _face(a: Vector3, b: Vector3, c: Vector3, color: Color, tissue: float, sway: float) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.00000008: return
	normal = normal.normalized()
	for vertex: Vector3 in [a, b, c]:
		_st.set_normal(normal)
		_st.set_color(color)
		_st.set_uv2(Vector2(tissue, sway))
		_st.add_vertex(vertex)

func _rim(phase: float, n: int, rough: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in n:
		var a := phase + TAU * i / n + _sculpt.randf_range(-0.18, 0.18) * TAU / n
		points.append(Vector2(cos(a), sin(a)) * _sculpt.randf_range(1.0 - rough, 1.0 + rough))
	return points

func _v(ring: PackedVector2Array, i: int, point: Vector3, radius: Vector2, axis: Basis) -> Vector3:
	var p := ring[i] * radius
	return point + axis * Vector3(p.x, 0, p.y)

# A closed, tapered solid between arbitrary joints. Curved trunks, roots and
# crystal bodies follow axes in 3D; the same cross-section is reused along
# adjacent strata to keep layered rock flush.
func _band(a: Vector3, b: Vector3, lower: Vector2, upper: Vector2, ring: PackedVector2Array, axis: Basis, base: Color, cap: Color, tissue := 0.0, sway := 0.0, lid := true) -> void:
	for k in ring.size():
		var j := (k + 1) % ring.size()
		var p := _v(ring, k, a, lower, axis)
		var q := _v(ring, j, a, lower, axis)
		var r := _v(ring, j, b, upper, axis)
		var s := _v(ring, k, b, upper, axis)
		var color := base.darkened(_sculpt.randf_range(0.0, 0.105))
		_face(p, q, r, color, tissue, sway)
		_face(p, r, s, color, tissue, sway)
		_face(a, q, p, base.darkened(0.17), tissue, sway)
		if lid: _face(b, s, r, cap.darkened(_sculpt.randf_range(0.0, 0.06)), tissue, sway)

func _stick(a: Vector3, b: Vector3, r1: float, r2: float, color: Color, n := 6, tissue := 0.0, sway := 0.0) -> void:
	var axis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_band(a, b, Vector2.ONE * r1, Vector2.ONE * r2, _rim(_sculpt.randf() * TAU, n, 0.05), axis, color, color.lightened(0.10), tissue, sway)

func _radial(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)

func _leaf(start: Vector3, angle: float, reach: float, rise: float, width: float, color: Color, curl := 0.2) -> void:
	var along := _radial(angle, 1.0, 0)
	var across := along.cross(Vector3.UP) * width
	var shoulder := start + along * reach * 0.48 + Vector3.UP * rise * 0.80
	var tip := start + along * reach + Vector3.UP * (rise - curl)
	var keel := shoulder + Vector3.UP * width * 0.78
	var back := shoulder - Vector3.UP * width * 0.16
	var l := shoulder - across
	var r := shoulder + across
	for data: Array in [[start, keel, l], [keel, tip, l], [start, r, keel], [keel, r, tip], [start, l, back], [back, l, tip], [start, back, r], [back, tip, r]]:
		var a: Vector3 = data[0]
		var b: Vector3 = data[1]
		var c: Vector3 = data[2]
		var mid := (a + b + c) / 3.0 - shoulder
		var face_color := color if mid.dot(across) < 0.0 else color.darkened(0.18)
		_face(a, c, b, face_color, 1.0, 0.75)

func _crown(center: Vector3, radius: float, height: float, base: Color, top: Color) -> void:
	var ring := _rim(_sculpt.randf() * TAU, 9, 0.22)
	var r := Vector2(radius, radius * _sculpt.randf_range(0.76, 1.08))
	var crown := center + Vector3(0.04, height * 0.34, 0.06)
	_band(center - Vector3.UP * height * 0.50, center, r * 0.34, r, ring, Basis.IDENTITY, base.darkened(0.20), base, 1, 0.45, false)
	_band(center, crown, r, r * 0.70, ring, Basis.IDENTITY, base, top, 1, 0.65, false)
	_band(crown, center + Vector3.UP * height * 0.56, r * 0.70, r * 0.22, ring, Basis.IDENTITY, top.darkened(0.08), top, 1, 0.68)

func _elder() -> void:
	var bark := Color("65504f")
	var elbow := Vector3(0.21, 2.2, -0.14)
	var fork := Vector3(-0.18, 3.75, 0.26)
	_stick(Vector3.DOWN * 0.26, elbow, 0.64, 0.42, bark, 8)
	_stick(elbow, fork, 0.44, 0.28, bark, 7)
	for i in 6:
		var angle := i * TAU / 6.0 + _sculpt.randf_range(-0.25, 0.25)
		_stick(_radial(angle, 1.45, -0.13), _radial(angle, 0.27, 0.85), 0.13, 0.33, bark.darkened(0.12))
		var anchor := _radial(angle + 0.18, 0.48, 1.72)
		var foot := _radial(angle, 1.23, -0.10)
		_stick(foot, anchor, 0.086, 0.052, Color("718368"), 5)
	var jade := Color("287672").lerp(Color("608860"), _sculpt.randf() * 0.72)
	for i in 6:
		var a := i * TAU / 6.0 + _sculpt.randf_range(-0.25, 0.25)
		var perch := fork + _radial(a, _sculpt.randf_range(1.35, 2.25), _sculpt.randf_range(-0.36, 0.68))
		var tip := perch + _radial(a + 0.25, 0.58, _sculpt.randf_range(0.56, 1.03))
		_stick(fork - Vector3.UP * 0.65, perch, 0.28, 0.17, bark)
		_stick(perch, tip, 0.18, 0.08, bark)
		_crown(tip, _sculpt.randf_range(1.12, 1.76), 1.36, jade, Color("809c63"))
		_crown(tip + _radial(a + 0.8, 0.86, -0.33), 0.86, 0.94, jade.darkened(0.10), Color("70a56e"))
		for j in 4:
			var side := a - 0.8 + j * 0.47
			var vine := tip + _radial(side, 1.02, -0.16)
			var droop := vine - Vector3(0.11, _sculpt.randf_range(0.57, 1.16), -0.08)
			_stick(droop, vine, 0.022, 0.064, Color("738855"), 4, 1, 0.65)
			_leaf(vine.lerp(droop, 0.62), side + 0.7, 0.22, -0.14, 0.076, Color("79a278"), 0.09)
			_leaf(vine, side, 0.46, -0.11, 0.15, jade.lightened(0.12), 0.21)
		if i % 2 == 0:
			var forklet := perch + _radial(a + 0.56, 0.67, -0.17)
			_stick(perch, forklet, 0.093, 0.045, bark)
			for j in 3:
				var cap := forklet + _radial(j * 2.1, 0.17, -0.08)
				_crown(cap, 0.15, 0.18, Color("9e789d"), Color("d6acbf"))
	_crown(fork + Vector3.UP * 1.45, 1.94, 1.52, jade, Color("b3ba70"))

func _bough() -> void:
	var bark := Color("6d5551")
	var foot := Vector3(-1.5, 0.08, -0.24)
	var knee := Vector3(0.16, 0.49, 0.22)
	_stick(foot, knee, 0.51, 0.41, bark, 8)
	_stick(knee, Vector3(1.65, 0.25, 0.42), 0.40, 0.20, bark)
	_stick(knee, Vector3(0.68, 1.23, 0.11), 0.17, 0.08, bark)
	for i in 5:
		var p := foot.lerp(knee, i / 5.0) + Vector3(0, 0.38, 0.12)
		_crown(p, 0.41, 0.25, Color("43735c"), Color("a4b563"))
	_bells(knee + Vector3(0.18, -0.35, -0.24))

func _fern() -> void:
	for k in 3:
		var p := _radial(k * 2.1, 0.22, 0.0)
		for j in 7:
			var a := j * TAU / 7.0 + k * 0.86
			var reach := _sculpt.randf_range(0.48, 0.89)
			_leaf(p, a, reach, reach * 0.77, 0.065, Color("3f9681").lerp(Color("98b97b"), j / 9.0))
			for n in 3:
				var at := p + _radial(a, reach * (n + 1) * 0.16, reach * (n + 1) * 0.19)
				_leaf(at, a - 0.64, 0.24 - n * 0.04, 0.10, 0.052, Color("7eaa71"), 0.08)
				_leaf(at, a + 0.64, 0.24 - n * 0.04, 0.10, 0.052, Color("548f73"), 0.08)

func _bells(base := Vector3.ZERO) -> void:
	for i in 6:
		var angle := _sculpt.randf() * TAU
		var p := base + _radial(angle, _sculpt.randf_range(0.04, 0.59), 0)
		var q := p + _radial(angle, 0.08, _sculpt.randf_range(0.18, 0.59))
		_stick(p, q, 0.031, 0.025, Color("85b3a3"), 4)
		var rad := _sculpt.randf_range(0.10, 0.23)
		var ring := _rim(0.21, 7, 0.15)
		_band(q, q + Vector3.UP * 0.04, Vector2.ONE * rad * 0.63, Vector2.ONE * rad, ring, Basis.IDENTITY, Color("5cb7ad"), Color("86e7cc"), 2)
		_band(q + Vector3.UP * 0.04, q + Vector3.UP * (rad + 0.03), Vector2.ONE * rad, Vector2.ONE * 0.018, ring, Basis.IDENTITY, Color("63c9bd"), Color("e4f7bf"), 2)

func _sandstone(center: Vector3, width: Vector2, height: float, breadth: Array, tones: Array, drift: Vector2) -> void:
	var ring := _rim(_sculpt.randf() * TAU, 9, 0.15)
	var previous := center
	for i in range(1, breadth.size()):
		var f := float(i) / (breadth.size() - 1)
		var top := center + Vector3(drift.x * f, f * height, drift.y * f)
		var color: Color = tones[(i - 1) % tones.size()]
		_band(previous, top, width * float(breadth[i - 1]), width * float(breadth[i]), ring, Basis.IDENTITY, color, color.lightened(0.16))
		previous = top

func _hoodoo() -> void:
	var faces := [Color("8c6375"), Color("b27c79"), Color("d69c88"), Color("926675"), Color("cb9a86"), Color("e8bd99")]
	_sandstone(Vector3(0, -0.2, 0), Vector2(1.05, 0.78), 4.55, [1.10, 0.76, 0.62, 0.67, 0.53, 1.01, 0.82], faces, Vector2(-0.27, 0.16))
	_sandstone(Vector3(0.99, -0.15, 0.33), Vector2(0.69, 0.56), 2.82, [1.1, 0.68, 0.58, 0.53, 1.0, 0.72], faces, Vector2(0.09, -0.15))

func _yardang() -> void:
	# Low elongated ridges predominate. Taller pillars and hollow arches
	# stand out against this irregular field of wind-worn sandstone.
	var faces := [Color("a07279"), Color("cb8e7f"), Color("d6ab8e"), Color("e7c19e")]
	for i in 3:
		var h := _sculpt.randf_range(0.78, 1.55) * (1.0 - i * 0.15)
		var foot := Vector3(i * 0.43, -0.16, i * 0.60)
		var width := Vector2(_sculpt.randf_range(1.2, 1.85) - i * 0.17, 0.45)
		_sandstone(foot, width, h, [1.0, 0.88, 0.71, 0.73, 0.42], faces, Vector2(-0.68, -0.16))

func _arch() -> void:
	# Two windcut buttresses and a striated lintel enclose a true opening.
	var tones := [Color("81586f"), Color("b97b7d"), Color("d89a83"), Color("ae747b"), Color("d5a089"), Color("e6bc93")]
	var y := _sculpt.randf_range(2.5, 3.1)
	_sandstone(Vector3(-1.66, -0.22, 0), Vector2(1.35, 0.82), y + 0.6, [1.20, 0.74, 0.69, 0.64, 0.74, 0.83], tones, Vector2(0.35, 0))
	_sandstone(Vector3(1.59, -0.22, 0.1), Vector2(1.06, 0.91), y + 0.61, [1.14, 0.89, 0.72, 0.66, 0.69, 0.74], tones, Vector2(-0.30, -0.05))
	_sandstone(Vector3(-0.15, y + 0.03, 0), Vector2(2.32, 0.80), 0.78, [0.71, 1.0, 0.89, 0.71], [tones[2], tones[3], tones[5]], Vector2(-0.26, -0.08))
	_sandstone(Vector3(-1.84, -0.19, 0.80), Vector2(1.0, 0.87), 1.0, [1.0, 0.87, 0.63], tones, Vector2(0.2, 0))

func _agave() -> void:
	for j in 3:
		for k in 8 - j:
			var a := (k + j * 0.47) * TAU / (8 - j)
			var reach := (0.90 - 0.22 * j) * _sculpt.randf_range(0.82, 1.14)
			var color := Color("699b91").lerp(Color("aec391"), j * 0.29)
			_leaf(Vector3.UP * j * 0.052, a, reach, 0.37 + j * 0.20, 0.138 - j * 0.027, color, 0.13)
	var sprig := Vector3(0.05, 1.17, -0.08)
	_stick(Vector3.ZERO, sprig, 0.042, 0.026, Color("927e66"), 4)
	for j in 6:
		var bud := sprig * (0.73 + j * 0.044)
		_stick(bud, bud + _radial(j * 2.39, 0.12, 0.082), 0.048, 0.015, Color("f2bf78"), 5)

func _salt() -> void:
	for i in 6:
		var p := _radial(_sculpt.randf() * TAU, _sculpt.randf_range(0.05, 0.57), -0.09)
		var h := _sculpt.randf_range(0.14, 0.43)
		_sandstone(p, Vector2(h * 0.81, h), h, [0.94, 0.88, 0.63], [Color("a594a2"), Color("e1c6c4")], Vector2(0.06, -0.03))

func _basalt(point: Vector3, radius: float, h: float, top: Color, hot := false) -> void:
	var ring := _rim(0.19, 6, 0.07)
	var base := point - Vector3.UP * 0.17
	var middle := point + Vector3(0.075, h * 0.62, -0.02)
	var neck := middle + Vector3(0, 0.055 + 0.023 * h, 0)
	_band(base, middle, Vector2.ONE * radius * 1.09, Vector2.ONE * radius, ring, Basis.IDENTITY, Color("3f354b"), top)
	var seam := Color("fa8847") if hot else Color("635366")
	_band(middle, neck, Vector2.ONE * radius, Vector2.ONE * radius * 0.97, ring, Basis.IDENTITY, seam, seam, 2.0 if hot else 0.0)
	_band(neck, point + Vector3(0.14, h, -0.06), Vector2.ONE * radius * 0.97, Vector2.ONE * radius * 0.87, ring, Basis.IDENTITY, Color("554763"), top)

func _organ() -> void:
	for k in 9:
		var a := k * TAU / 9.0
		var p := _radial(a, 0.94, 0)
		var h := 2.5 + 1.5 * cos(a + 0.75) + _sculpt.randf_range(-0.35, 0.45)
		_basalt(p, 0.48, h, Color("927a97"), k % 4 == 0)
	_basalt(Vector3(0, 0, -0.1), 0.72, 4.50, Color("92819b"), true)
	_basalt(Vector3(0.26, 0, 1.55), 0.42, 1.17, Color("917e93"))

func _chimney() -> void:
	var ring := _rim(0.21, 8, 0.18)
	var r := Vector2(1.30, 1.15)
	var middle := Vector3(-0.24, 1.75, 0.05)
	var top := Vector3(-0.35, 2.62, 0.09)
	_band(Vector3.DOWN * 0.26, middle, r * 1.12, r * 0.69, ring, Basis.IDENTITY, Color("553b50"), Color("b26867"), 0, 0, false)
	_band(middle, top, r * 0.69, r * 0.80, ring, Basis.IDENTITY, Color("765064"), Color("9a6468"), 0, 0, false)
	# Rim and recessed incandescent core are built into the caldera itself.
	for k in ring.size():
		var j := (k + 1) % ring.size()
		var lip := _v(ring, k, top, r * 0.8, Basis.IDENTITY)
		var far_lip := _v(ring, j, top, r * 0.8, Basis.IDENTITY)
		var rim := _v(ring, k, top + Vector3.UP * 0.06, r * 0.66, Basis.IDENTITY)
		var far_rim := _v(ring, j, top + Vector3.UP * 0.06, r * 0.66, Basis.IDENTITY)
		var pit := _v(ring, k, top - Vector3.UP * 0.29, r * 0.57, Basis.IDENTITY)
		var far_pit := _v(ring, j, top - Vector3.UP * 0.29, r * 0.57, Basis.IDENTITY)
		_face(lip, far_lip, far_rim, Color("b67574"), 0, 0)
		_face(lip, far_rim, rim, Color("bb7f76"), 0, 0)
		_face(rim, far_rim, far_pit, Color("e47754"), 2, 0)
		_face(rim, far_pit, pit, Color("ba5854"), 2, 0)
		_face(top - Vector3.UP * 0.34, pit, far_pit, Color("ffae56"), 2, 0)

func _crystal(point: Vector3, h: float, radius: float, lean: Vector3, base: Color, lit: Color, tissue := 0.0) -> void:
	var axis := Basis(Quaternion(Vector3.UP, (Vector3.UP * h + lean).normalized()))
	var ring := _rim(0.19, 5, 0.12)
	var bottom := point - Vector3.UP * 0.12
	var shoulder := point + axis * Vector3.UP * h * 0.72
	var tip := point + axis * Vector3(h * 0.032, h, h * 0.028)
	_band(bottom, shoulder, Vector2.ONE * radius * 0.73, Vector2.ONE * radius, ring, axis, base, lit, tissue, 0, false)
	_band(shoulder, tip, Vector2.ONE * radius, Vector2.ONE * radius * 0.028, ring, axis, lit, lit, tissue)

func _cinder() -> void:
	for k in 5:
		var p := _radial(k * 2.4, sqrt(float(k)) * 0.24, 0)
		var h := _sculpt.randf_range(0.24, 0.84)
		_crystal(p, h, h * 0.29, p * 0.67, Color("684451"), Color("eb8260"), 2 if k == 1 else 0)

func _sulfur() -> void:
	for k in 6:
		var p := _radial(k * 2.4, sqrt(float(k)) * 0.24, 0)
		_basalt(p, _sculpt.randf_range(0.19, 0.39), _sculpt.randf_range(0.19, 0.51), Color("ae9869"), k == 1)

func _fir() -> void:
	var h := _sculpt.randf_range(4.5, 6.6)
	var r := h * _sculpt.randf_range(0.17, 0.24)
	var bark := Color("6b5c67")
	_stick(Vector3.DOWN * 0.21, Vector3.UP * h * 0.91, r * 0.18, 0.035, bark, 8)
	for tier in 6:
		var height := 0.9 + (h - 1.05) * tier / 6.0
		var width := r * (1.0 - tier * 0.131)
		var ring := _rim(tier * 0.82, 9, 0.21)
		var layers := [Color("224954"), Color("33636a"), Color("5b8691"), Color("bbd0dd"), Color("dfedec")]
		for k in ring.size():
			var j := (k + 1) % ring.size()
			var spine := _v(ring, k, Vector3.UP * (height + 0.12), Vector2.ONE * width * 0.30, Basis.IDENTITY)
			var apex := Vector3(0.04, height + width * 0.83, -0.02)
			var tip := _v(ring, k, Vector3.UP * (height - 0.18 + _sculpt.randf_range(-0.07, 0.05)), Vector2.ONE * width, Basis.IDENTITY)
			var next := _v(ring, j, Vector3.UP * height, Vector2.ONE * width * 0.81, Basis.IDENTITY)
			var tip_next := tip.lerp(next, 0.36) - Vector3.UP * 0.09
			var cut := tip.lerp(apex, _sculpt.randf_range(0.22, 0.42))
			var cut_next := next.lerp(apex, _sculpt.randf_range(0.25, 0.49))
			_face(spine, tip_next, tip, layers[0], 1, 0.47)
			_face(spine, next, tip_next, layers[0], 1, 0.47)
			_face(tip, tip_next, cut, layers[1], 1, 0.52)
			_face(tip_next, next, cut_next, layers[2], 1, 0.52)
			_face(tip_next, cut_next, cut, layers[1], 1, 0.52)
			_face(cut, cut_next, apex, layers[3] if k % 3 == 0 else layers[4], 1, 0.59)
	_crystal(Vector3.UP * h * 0.90, h * 0.105, 0.10, Vector3.ZERO, Color("86a6ae"), Color("d8edeb"))

func _ice_spire() -> void:
	for k in 7:
		var p := _radial(k * 2.4, sqrt(float(k)) * 0.39, 0)
		var h := 4.25 / (1.0 + 0.24 * k) * _sculpt.randf_range(0.87, 1.15)
		_crystal(p, h, 0.24 + h * 0.086, p * 0.75, Color("4b99ad"), Color("b9e4ec"))

func _juniper() -> void:
	for k in 6:
		var p := _radial(k * 2.4, sqrt(float(k)) * 0.19, 0.15)
		_crown(p, _sculpt.randf_range(0.25, 0.49), _sculpt.randf_range(0.26, 0.47), Color("527977"), Color("cad8da"))

func _frost() -> void:
	for k in 7:
		var p := _radial(k * 2.4, sqrt(float(k)) * 0.16, 0)
		var h := _sculpt.randf_range(0.20, 0.71)
		_crystal(p, h, 0.09 + h * 0.13, p * 0.55, Color("77b7c7"), Color("d3f2f4"))
