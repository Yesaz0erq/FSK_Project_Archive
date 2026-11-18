extends RefCounted
## Geometry and mechanical joints used by the offline orthographic sprite bake.
const PAINT := preload("res://tools/machine_models/enamel.gdshader")
var root := Node3D.new()
var _paints: Dictionary = {}
var _joints: Array[Dictionary] = []

func group(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	return pivot

func _paint(code: String) -> ShaderMaterial:
	if not _paints.has(code):
		var luminous := code.begins_with("!")
		var pigment := Color(code.trim_prefix("!"))
		var mat := ShaderMaterial.new()
		mat.shader = PAINT
		mat.set_shader_parameter("pigment", pigment)
		mat.set_shader_parameter("luminous", luminous)
		_paints[code] = mat
	return _paints[code]

func _part(parent: Node3D, shape: Mesh, pos: Vector3, code: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.material_override = _paint(code)
	part.position = pos
	parent.add_child(part)
	return part

func box(parent: Node3D, pos: Vector3, size: Vector3, code: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _part(parent, shape, pos, code)

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, code: String, segments := 12, rings := 6) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = segments
	shape.rings = rings
	var part := _part(parent, shape, pos, code)
	part.scale = size
	return part

func frustum(parent: Node3D, pos: Vector3, height: float, top_radius: float, bottom_radius: float, code: String, segments := 12) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.height = height
	shape.top_radius = top_radius
	shape.bottom_radius = bottom_radius
	shape.radial_segments = segments
	shape.rings = 0
	return _part(parent, shape, pos, code)

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, code: String, segments := 8) -> MeshInstance3D:
	var axis := (b - a).normalized()
	var pole := frustum(parent, (a + b) * 0.5, maxf(a.distance_to(b), 0.0001), radius, radius, code, segments)
	if axis.length_squared() > 0.0:
		pole.quaternion = Quaternion(Vector3.UP, axis)
	return pole

func tube(parent: Node3D, points: Array, radius: float, code: String, segments := 8) -> Node3D:
	var pipe := group(parent, Vector3.ZERO)
	for i in range(1, points.size()):
		rod(pipe, points[i - 1], points[i], radius, code, segments)
		if i < points.size() - 1:
			ellipsoid(pipe, points[i], Vector3.ONE * radius * 2.0, code, segments, 3)
	return pipe

func ring(parent: Node3D, pos: Vector3, radius: float, tube_radius: float, code: String, segments := 18) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = maxf(0.001, radius - tube_radius)
	shape.outer_radius = radius + tube_radius
	shape.rings = segments
	shape.ring_segments = 6
	return _part(parent, shape, pos, code)

func mesh(parent: Node3D, verts: Array, faces: Array, code: String) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in faces:
		for i in range(1, face.size() - 1):
			var a: Vector3 = verts[face[0]]
			var b: Vector3 = verts[face[i]]
			var c: Vector3 = verts[face[i + 1]]
			var n := (b - a).cross(c - a).normalized()
			if n.is_zero_approx(): continue
			# Godot front faces wind clockwise when observed from the outside.
			for vertex: Vector3 in [a, c, b]:
				surface.set_normal(n)
				surface.add_vertex(vertex)
	return _part(parent, surface.commit(), Vector3.ZERO, code)

func leaf(parent: Node3D, base: Vector3, tip: Vector3, width: float, arch: float, code: String, underside: String) -> Node3D:
	var blade := group(parent, base)
	var length := tip - base
	var across := length.cross(Vector3.UP).normalized()
	if across.is_zero_approx(): across = Vector3.RIGHT
	var verts: Array[Vector3] = []
	var left: Array = []
	var right: Array = []
	# Paired facets and a raised midrib retain a distinct illuminated and shaded half.
	for i in 7:
		var t := i / 6.0
		var curve := sin(t * PI)
		var center := length * t + Vector3.UP * (curve * arch)
		var radius := maxf(0.001, pow(curve, 0.84) * width * 0.5)
		verts.append(center - across * radius)
		verts.append(center + Vector3.UP * (radius * 0.31))
		verts.append(center + across * radius)
		if i > 0:
			var j := i * 3
			left.append([j-3,j-2,j+1,j])
			right.append([j-2,j-1,j+2,j+1])
	mesh(blade, verts, left, code)
	mesh(blade, verts, right, underside)
	return blade

func motion(node: Node3D, kind: String, axis: Vector3, amount: float, offset := 0.0) -> void:
	_joints.append({"node":node, "rest":node.transform, "kind":kind, "axis":axis.normalized(), "amount":amount, "offset":offset})

func pose(cycle: float) -> void:
	for joint in _joints:
		var node: Node3D = joint.node
		var rest: Transform3D = joint.rest
		var angle := TAU * (cycle + float(joint.offset))
		var axis: Vector3 = joint.axis
		var amount: float = joint.amount
		if joint.kind == "slide":
			rest.origin += axis * (sin(angle) * amount)
		else:
			var turn := angle * amount if joint.kind == "spin" else sin(angle) * amount
			rest.basis = rest.basis * Basis(axis, turn)
		node.transform = rest
