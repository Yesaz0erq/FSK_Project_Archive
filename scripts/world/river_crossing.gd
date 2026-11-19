extends Node3D
## A small footbridge just upstream of the play area. Bank positions and
## approach elevations come from the same terrain that carries the river.

var _surface := SurfaceTool.new()
var _lamp_position := Vector3.ZERO

func build(biome: String, land: Node3D) -> void:
	var z_center: float = land.crossing_z
	rotation.y = land.rotation.y
	var banks: Vector2 = land.river_span_at(z_center)
	if banks.y <= banks.x: return
	var left := banks.x - 0.80
	var right := banks.y + 0.80
	var foot_l: float = land.height_in_river_frame(left, z_center)
	var foot_r: float = land.height_in_river_frame(right, z_center)
	var rim := maxf(foot_l, foot_r) + 0.47
	var colors: Array = {
		"forest": ["805a44", "c09867", "456165", "8ab1a1"],
		"desert": ["985c57", "e1a67e", "794f62", "eac094"],
		"volcano": ["54455a", "9f7977", "454151", "c99170"],
		"snow": ["846b65", "cab7a1", "576d80", "deedeb"]
	}[biome]
	var wood := Color(colors[0])
	var sun_face := Color(colors[1])
	var stone := Color(colors[2])
	var cap := Color(colors[3])
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var masonry := biome in ["desert", "volcano"]
	for x: float in [left, right]:
		var bottom: float = land.height_in_river_frame(x, z_center) - 0.52
		_box(Vector3(x, (bottom + rim) * 0.5, z_center), Vector3(0.72, rim - bottom, 1.42), stone)
		_box(Vector3(x, rim, z_center), Vector3(0.86, 0.16, 1.53), cap)
	for z: float in [z_center-0.46, z_center+0.46]:
		if masonry:
			# Voussoirs describe an open arch above the channel.
			for i in 12:
				var t0 := float(i) / 12.0
				var t1 := float(i+1) / 12.0
				var p0 := Vector3(lerpf(left, right, t0), rim - 0.84 + 0.91 * sin(t0*PI), z)
				var p1 := Vector3(lerpf(left, right, t1), rim - 0.84 + 0.91 * sin(t1*PI), z)
				_rail(p0.lerp(p1, -0.02), p0.lerp(p1, 1.02), 0.30, 0.40, wood.lerp(cap, (i%3)*0.13))
		else:
			_rail(Vector3(left, rim-0.03, z), Vector3(right, rim-0.03, z), 0.17, 0.22, wood.darkened(0.21))
			for end_x: float in [left, right]:
				var direction := signf((left+right)*0.5-end_x)
				_rail(Vector3(end_x, rim-0.68, z), Vector3(end_x + direction*(right-left)*0.24, rim-0.04, z), 0.15, 0.18, wood)
	var count := maxi(4, ceili((right-left)/(0.44 if masonry else 0.27)))
	var width := (right-left)/count
	for i in count:
		var t := (i+0.5)/count
		var y := rim + 0.13 + (0.12 if masonry else 0.035)*sin(t*PI)
		var col := wood.lerp(sun_face, [0.22, 0.64, 0.34, 0.46, 0.58][i%5])
		_box(Vector3(left + t*(right-left), y, z_center), Vector3(width-0.012, 0.13, 1.20), col)
	var rail_z := z_center-0.54
	for i in 4:
		var t := i / 3.0
		var x := lerpf(left,right,t)
		_box(Vector3(x, rim+0.51, rail_z), Vector3(0.12, 0.80, 0.12), wood.darkened(0.22))
		_box(Vector3(x, rim+0.91, rail_z), Vector3(0.17,0.08,0.17), cap)
		if i < 3:
			var next_x := lerpf(left,right,(i+1)/3.0)
			var mid := Vector3((x+next_x)*0.5, rim+0.68, rail_z)
			_rail(Vector3(x,rim+0.82,rail_z),mid,0.05,0.06, sun_face)
			_rail(mid,Vector3(next_x,rim+0.82,rail_z),0.05,0.06,sun_face)
	_lamp_position = Vector3(right, rim+1.23, z_center+0.49)
	_box(_lamp_position - Vector3.UP*0.57, Vector3(0.14,1.16,0.14), stone)
	_box(_lamp_position - Vector3.UP*0.02, Vector3(0.33,0.10,0.33), cap)
	_box(_lamp_position + Vector3.UP*0.36, Vector3(0.40,0.10,0.40), stone)
	for dx: float in [-0.12,0.12]:
		for dz: float in [-0.12,0.12]:
			_box(_lamp_position + Vector3(dx,0.17,dz), Vector3(0.036,0.32,0.036), wood)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Span"
	mesh_node.mesh = _surface.commit()
	mesh_node.material_override = material
	add_child(mesh_node)
	MeshKit.box(self, Vector3(0.19,0.27,0.19), _lamp_position+Vector3.UP*0.17, Color("ffc778"), 2.0, false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffbb78")
	lamp.light_energy = 1.4
	lamp.omni_range = 4.4
	lamp.position = _lamp_position
	add_child(lamp)

func _box(center: Vector3, size: Vector3, color: Color, basis3: Basis = Basis.IDENTITY) -> void:
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var half := size*0.5
	for axis in 3:
		var cross_axis := (axis+1)%3
		var up_axis := (axis+2)%3
		for side: float in [-1.0,1.0]:
			var normal: Vector3 = axes[axis]*side
			var face: Vector3 = normal*half[axis]
			var u: Vector3 = axes[cross_axis]*half[cross_axis]*side
			var v: Vector3 = axes[up_axis]*half[up_axis]
			for vertex: Vector3 in [face-u-v, face-u+v, face+u+v, face-u-v, face+u+v, face+u-v]:
				_surface.set_normal(basis3*normal)
				_surface.set_color(color)
				_surface.add_vertex(center + basis3*vertex)

func _rail(a: Vector3, b: Vector3, breadth: float, depth: float, pigment: Color) -> void:
	var along := (b-a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	_box((a+b)*0.5, Vector3(a.distance_to(b), depth, breadth), pigment, Basis(along, side.cross(along), side))
