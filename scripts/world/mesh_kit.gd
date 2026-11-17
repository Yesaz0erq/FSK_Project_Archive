class_name MeshKit
extends RefCounted
## Tiny low-poly building kit shared by the scenery and the plot grid.
## Materials and meshes are cached so repeated props share GPU resources.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

static func mat(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%s" % [color.to_html(), emission, unshaded]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic_specular = 0.2
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m

static func _mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key): _meshes[key] = maker.call()
	return _meshes[key]

static func add(parent: Node, mesh: Mesh, pos: Vector3, color: Color, emission: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(color, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, emission: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var key: String = "box%s" % size
	var m: Mesh = _mesh(key, func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)
	return add(parent, m, pos, color, emission, shadows)

static func cyl(parent: Node, pos: Vector3, top: float, bottom: float, height: float, color: Color, segments: int = 7, emission: float = 0.0) -> MeshInstance3D:
	var key: String = "cyl%.2f|%.2f|%.2f|%d" % [top, bottom, height, segments]
	var m: Mesh = _mesh(key, func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = segments
		c.rings = 1
		return c)
	return add(parent, m, pos, color, emission)

static func ball(parent: Node, pos: Vector3, scale_v: Vector3, color: Color, segments: int = 7, rings: int = 4, emission: float = 0.0) -> MeshInstance3D:
	var key: String = "ball%d|%d" % [segments, rings]
	var m: Mesh = _mesh(key, func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = segments
		s.rings = rings
		return s)
	var mi: MeshInstance3D = add(parent, m, pos, color, emission)
	mi.scale = scale_v
	return mi

static func plane(parent: Node, size: Vector2, pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var key: String = "plane%s" % size
	var m: Mesh = _mesh(key, func() -> Mesh:
		var p := PlaneMesh.new()
		p.size = size
		return p)
	var mi: MeshInstance3D = add(parent, m, pos, color, emission, false)
	return mi

static func particles(parent: Node, pos: Vector3, color: Color, amount: int, extents: Vector3, velocity: Vector3, size: float, lifetime: float, emission: float = 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	if emission > 0.0:
		m.albedo_color = Color(1.0 + emission, 1.0 + emission, 1.0 + emission)
	q.material = m
	p.mesh = q
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = velocity.normalized() if velocity.length() > 0.001 else Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = velocity.length() * 0.6
	p.initial_velocity_max = velocity.length() * 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(color, 0.0))
	grad.set_color(1, Color(color, 0.0))
	grad.add_point(0.2, color)
	grad.add_point(0.75, color)
	p.color_ramp = grad
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	parent.add_child(p)
	return p

static var _dot: Texture2D
static func _soft_dot() -> Texture2D:
	if _dot != null: return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	_dot = t
	return t
