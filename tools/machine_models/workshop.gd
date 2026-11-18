extends RefCounted
## Workshop machinery. All dimensions are in metres and all poses have the same ground pivot.

const IRON := "283447"
const PATINA := "427f79"
const TEAL := "316561"
const COPPER := "b77451"
const BRASS := "d49e63"
const GOLD := "f0c88a"
const SOIL := "363549"
const MOSS := "52796b"

static func build(id: String, k) -> void:
	match id:
		"spore_garden": _spore_garden(k)
		"vine_loom": _vine_loom(k)
		"bloom_press": _bloom_press(k)

# Many-sided metal tub with a rolled lip, seeded mycelium, fungal fruiting bodies, and a goose-neck watering line.
static func _spore_garden(k) -> void:
	var root: Node3D = k.root
	for x: float in [-0.49, 0.49]:
		for z: float in [-0.26, 0.26]:
			var ankle := Vector3(x, 0.24, z)
			var toe := Vector3(x * 1.19, 0.065, z * 1.38)
			k.rod(root, ankle, toe, 0.067, COPPER)
			k.ellipsoid(root, toe, Vector3(0.24, 0.13, 0.19), BRASS, 8, 4)
	var vessel: Node3D = k.group(root, Vector3(0, 0, 0))
	vessel.scale = Vector3(1.0, 1.0, 0.61)
	k.frustum(vessel, Vector3.UP * 0.32, 0.29, 0.74, 0.57, "6e4c52", 16)
	k.frustum(vessel, Vector3.UP * 0.51, 0.22, 0.78, 0.73, PATINA, 16)
	k.ring(vessel, Vector3.UP * 0.59, 0.772, 0.052, "d8ba8e", 18)
	k.frustum(vessel, Vector3.UP * 0.595, 0.025, 0.72, 0.70, SOIL, 16)
	k.ring(vessel, Vector3.UP * 0.405, 0.706, 0.027, "9b6652", 16)
	# Rivets and mineral runs follow the curved front and back of the tub.
	for i in 12:
		var a := TAU * i / 12.0
		k.ellipsoid(root, Vector3(0.758 * cos(a), 0.51, 0.467 * sin(a)), Vector3(0.057, 0.056, 0.048), BRASS, 7, 3)
	for i in 13:
		var a := float(i) * 2.39
		k.ellipsoid(root, Vector3(cos(a) * 0.63, 0.615, sin(a) * 0.34), Vector3(0.17, 0.085, 0.13), MOSS if i % 3 else "758853", 7, 4)
	for stick in [
		[Vector3(-0.38, 0.63, 0.06), 0.45, 0.26, "e88861", "974c65"],
		[Vector3(0.01, 0.63, -0.09), 0.70, 0.33, "e39c69", "9a506a"],
		[Vector3(0.39, 0.62, 0.02), 0.36, 0.22, "aa7092", "65577b"],
		[Vector3(0.03, 0.63, 0.23), 0.23, 0.15, "dfbe8c", "947575"],
		[Vector3(-0.48, 0.62, -0.16), 0.21, 0.13, "f4b978", "a76869"]
	]:
		_puffball(k, root, stick[0], stick[1], stick[2], stick[3], stick[4])
	for side: int in [-1, 1]:
		var p := Vector3(side * 0.53, 0.62, 0.11)
		k.leaf(root, p, p + Vector3(side * 0.28, 0.25, -0.11), 0.18, 0.08, "829c64", TEAL)
		k.leaf(root, p, p + Vector3(side * 0.18, 0.05, 0.19), 0.12, 0.08, "57907b", TEAL)
	var pipe := [Vector3(-0.56, 0.34, -0.29), Vector3(-0.63, 0.63, -0.30),
			Vector3(-0.63, 1.49, -0.30), Vector3(-0.56, 1.64, -0.30),
			Vector3(-0.40, 1.72, -0.30), Vector3(-0.22, 1.72, -0.30),
			Vector3(-0.13, 1.61, -0.22), Vector3(-0.13, 1.52, -0.20)]
	k.tube(root, pipe, 0.044, COPPER, 8)
	for y: float in [0.73, 1.28, 1.47]:
		k.frustum(root, Vector3(-0.63, y, -0.30), 0.064, 0.071, 0.071, BRASS, 8)
	k.frustum(root, Vector3(-0.13, 1.52, -0.20), 0.09, 0.054, 0.094, BRASS, 10)
	var drop: Node3D = k.group(root, Vector3(-0.13, 1.42, -0.20))
	k.ellipsoid(drop, Vector3.ZERO, Vector3(0.061, 0.090, 0.061), "!89d6d0", 7, 4)
	k.motion(drop, "slide", Vector3.DOWN, 0.055)

static func _puffball(k, root: Node3D, p: Vector3, height: float, radius: float, light: String, dark: String) -> void:
	var shroom: Node3D = k.group(root, p)
	k.motion(shroom, "swing", Vector3.FORWARD, 0.038, p.x * 1.8)
	k.frustum(shroom, Vector3.UP * (height * 0.41), height * 0.82, radius * 0.28, radius * 0.44, "c7b09a", 9)
	k.frustum(shroom, Vector3.UP * (height * 0.70), 0.055, radius * 0.29, radius * 0.62, "e2c9a5", 9)
	# Pale gills separate the skin from the cap's shaded edge.
	k.frustum(shroom, Vector3.UP * (height * 0.825), radius * 0.23, radius * 0.91, radius * 0.53, "c0a5a6", 12)
	k.frustum(shroom, Vector3.UP * (height * 0.825 + radius * 0.18), radius * 0.24, radius, radius * 0.89, dark, 12)
	var top := height * 0.825 + radius * 0.31
	k.frustum(shroom, Vector3.UP * (top + radius * 0.28), radius * 0.56, radius * 0.55, radius, light, 12)
	k.frustum(shroom, Vector3.UP * (top + radius * 0.65), radius * 0.18, radius * 0.20, radius * 0.55, light, 12)
	for i in 5:
		var a := TAU * i / 5.0 + height
		k.ellipsoid(shroom, Vector3(radius * 0.68 * cos(a), top + radius * 0.40, radius * 0.68 * sin(a)), Vector3(radius * 0.32, radius * 0.12, radius * 0.32), "f4d8a2", 6, 3)

# Tensioned warp runs over two offset rollers; the movable shuttle lies in the open shed.
static func _vine_loom(k) -> void:
	var root: Node3D = k.root
	var wood := "6f4e50"
	var leaf := "83b09a"
	for side: int in [-1, 1]:
		var x := side * 0.61
		k.box(root, Vector3(x, 0.10, 0.02), Vector3(0.25, 0.20, 1.04), wood)
		k.box(root, Vector3(x, 0.12, 0.47), Vector3(0.27, 0.21, 0.11), BRASS)
		k.tube(root, [Vector3(x, 0.17, 0.38), Vector3(x, 0.78, 0.23), Vector3(x, 1.54, -0.18), Vector3(x, 1.83, -0.22)], 0.083, wood)
		k.rod(root, Vector3(x, 0.17, -0.47), Vector3(x, 1.36, -0.14), 0.073, "4c4650")
		k.rod(root, Vector3(x, 0.57, 0.31), Vector3(x, 0.59, -0.38), 0.045, BRASS)
		k.ellipsoid(root, Vector3(x, 1.78, -0.20), Vector3(0.21, 0.22, 0.21), BRASS, 10, 5)
		# Living vine winds up the side posts and bridges into the structural arch.
		k.tube(root, [Vector3(x + 0.04,0.24,0.36), Vector3(x - 0.09,0.56,0.34),
				Vector3(x - 0.03,0.82,0.15), Vector3(x + 0.08,1.01,0.022),
				Vector3(x + 0.035,1.32,-0.04), Vector3(x - 0.07,1.54,-0.19)], 0.036, PATINA)
		for j in 3:
			var y := 0.83 + j * 0.31
			var z := 0.18 - j * 0.17
			k.leaf(root, Vector3(x, y, z), Vector3(x + side * (0.19 - j * 0.025), y + 0.25, z - 0.07), 0.15, 0.055, leaf, TEAL)
	k.box(root, Vector3(0, 0.26, -0.30), Vector3(1.25, 0.13, 0.12), IRON)
	k.rod(root, Vector3(-0.71,1.66,-0.19), Vector3(0.71,1.66,-0.19), 0.077, BRASS, 12)
	k.rod(root, Vector3(-0.69,0.61,0.37), Vector3(0.69,0.61,0.37), 0.108, "735860", 12)
	k.rod(root, Vector3(-0.51,0.61,0.37), Vector3(0.51,0.61,0.37), 0.113, "5b8b81", 12)
	var colors := ["619889","b99672","76bfa6","57928c"]
	for i in 13:
		var x := -0.468 + 0.078 * i
		var front := Vector3(x, 0.67, 0.425)
		var end := Vector3(x, 1.69, -0.125)
		k.rod(root, front, end, 0.014, colors[i % 4], 5)
	# Each diamond motif is woven into the sloping lower cloth rather than printed on a housing.
	var corners := [Vector3(-0.49, 0.68, 0.44), Vector3(0.49, 0.68, 0.44), Vector3(0.49, 0.99, 0.281), Vector3(-0.49, 0.99, 0.281)]
	k.mesh(root, corners, [[0, 1, 2, 3]], TEAL)
	for i in 5:
		var x := -0.38 + i * 0.19
		k.mesh(root, [Vector3(x, 0.71, 0.433), Vector3(x+0.085,0.82,0.38), Vector3(x,0.936,0.32), Vector3(x-0.085,0.82,0.38)], [[0,1,2,3]], "cca571" if i % 2 == 0 else "87bfaa")
	k.rod(root, Vector3(-0.62,1.33,0.065), Vector3(0.62,1.33,0.065), 0.024, "c59171")
	var shuttle: Node3D = k.group(root, Vector3(0, 1.11, 0.28))
	k.ellipsoid(shuttle, Vector3.ZERO, Vector3(0.41,0.115,0.15), "d99873", 8, 4)
	k.box(shuttle, Vector3(0,0.018,0.012), Vector3(0.20,0.10,0.14), IRON)
	k.rod(shuttle, Vector3(-0.077,0.044,0.012), Vector3(0.077,0.044,0.012), 0.055, "!89d3bc", 8)
	k.motion(shuttle, "slide", Vector3.RIGHT, 0.30)
	var wheel: Node3D = k.group(root, Vector3(0.73, 0.61, 0.37))
	var hoop: Node3D = k.ring(wheel, Vector3.ZERO, 0.207, 0.034, BRASS, 15)
	hoop.rotation.z = PI * 0.5
	for i in 5:
		var a := TAU * i / 5.0
		k.rod(wheel, Vector3.ZERO, Vector3(0,cos(a),sin(a)) * 0.205, 0.026, COPPER)
	k.ellipsoid(root, wheel.position, Vector3(0.13,0.10,0.10), GOLD, 8, 4)
	# Five identical spokes repeat after one fifth of a revolution.
	k.motion(wheel, "spin", Vector3.RIGHT, 0.2)
	# Paired spring buds finish the forked profile above the loom.
	for side: int in [-1, 1]:
		var low := Vector3(side * 0.61, 1.78, -0.20)
		var high := Vector3(side * 0.45, 1.96, -0.19)
		k.rod(root, low, high, 0.044, TEAL)
		k.leaf(root, high, high + Vector3(-side * 0.22,0.10,0.06), 0.14, 0.07, leaf, PATINA)

# The flower's petals cup a flywheel. Its crown drives the ram into the separate die.
static func _bloom_press(k) -> void:
	var root: Node3D = k.root
	k.frustum(root, Vector3.UP * 0.10, 0.20, 0.62, 0.68, IRON, 8)
	k.frustum(root, Vector3.UP * 0.255, 0.15, 0.595, 0.64, "776375", 8)
	k.frustum(root, Vector3.UP * 0.36, 0.085, 0.55, 0.60, BRASS, 8)
	k.frustum(root, Vector3(0,0.41,0.05), 0.12, 0.42, 0.49, "3e4658", 10)
	k.frustum(root, Vector3(0,0.50,0.10), 0.10, 0.22, 0.28, COPPER, 10)
	k.ring(root, Vector3(0,0.55,0.10), 0.215, 0.027, GOLD, 12)
	k.ellipsoid(root, Vector3(0,0.585,0.10), Vector3(0.24,0.13,0.22), "!ed8d9d", 8, 4)
	for side: int in [-1, 1]:
		var column_x := 0.49 * side
		var column := [Vector3(column_x * 0.87,0.36,-0.15), Vector3(column_x*1.12,0.59,-0.16),
			Vector3(column_x*1.11,1.10,-0.18), Vector3(column_x*0.93,1.31,-0.17), Vector3(column_x*0.42,1.47,-0.08)]
		k.tube(root, column, 0.114, "64546a", 8)
		k.rod(root, Vector3(column_x*1.22,0.60,-0.12), Vector3(column_x*1.21,1.075,-0.14), 0.038, BRASS)
		k.frustum(root, Vector3(column_x*1.12,0.63,-0.16), 0.083, 0.124, 0.124, COPPER, 8)
		k.ellipsoid(root, Vector3(column_x*0.93,1.31,-0.16), Vector3(0.24,0.24,0.22), "ad7a61", 10, 4)
		k.ellipsoid(root, Vector3(column_x*0.93,1.31,-0.056), Vector3(0.115,0.115,0.053), GOLD, 8, 4)
		k.leaf(root, Vector3(column_x*0.87,0.49,-0.13), Vector3(column_x*1.58,0.79,-0.25), 0.20, 0.11, "577e80", IRON)
	k.box(root, Vector3(0,1.47,-0.06), Vector3(0.61,0.23,0.42), "705f71")
	k.frustum(root, Vector3(0,1.35,0.06), 0.20, 0.23, 0.17, BRASS, 10)
	# Rear belts and leaf springs keep the press profile recognizable from the opposite side.
	for x: float in [-0.29, 0.29]:
		k.tube(root, [Vector3(x,0.32,-0.43),Vector3(x,0.57,-0.48),Vector3(x,1.07,-0.42),Vector3(x*0.65,1.45,-0.18)], 0.048, TEAL)
	var ram: Node3D = k.group(root, Vector3(0,1.14,0.08))
	k.frustum(ram, Vector3.UP*0.085, 0.46, 0.128, 0.128, "d5b194", 10)
	for i in 3:
		k.ring(ram, Vector3.UP*(0.04 + i*0.09), 0.122, 0.019, "8c7881", 10)
	k.frustum(ram, Vector3.DOWN*0.155, 0.11, 0.17, 0.245, "88596b", 10)
	k.frustum(ram, Vector3.DOWN*0.239, 0.073, 0.241, 0.188, "e3ab83", 10)
	k.motion(ram, "slide", Vector3.DOWN, 0.205)
	# Alternating shell colours follow the opening of a seven-petalled mechanical magnolia.
	var crown: Node3D = k.group(root, Vector3(0,1.54,-0.07))
	crown.rotation.x = deg_to_rad(14.0)
	k.frustum(crown, Vector3.UP*0.026, 0.16, 0.31, 0.21, TEAL, 12)
	for i in 7:
		var a := TAU * i/7.0 + 0.18
		var d := Vector3(cos(a),0,sin(a))
		var row: Node3D = k.group(crown,d*0.14)
		var tangent := Vector3(-sin(a),0,cos(a))
		var length := 0.50 if i % 2 == 0 else 0.43
		var h := 0.43 if i % 2 == 0 else 0.51
		var outer := d*length + Vector3.UP*h
		var ridge := d*0.26 + Vector3.UP*(h*0.39)
		var back := d*0.29 + Vector3.UP*(h*0.23)
		var flank := d*0.31 + Vector3.UP*(h*0.48)
		var verts := [Vector3.ZERO, ridge, outer, flank+tangent*0.174, flank-tangent*0.174, back]
		k.mesh(row, verts, [[0,3,1],[1,3,2]], "dd879d" if i%2 == 0 else "cf89aa")
		k.mesh(row, verts, [[1,4,0],[2,4,1]], "f2b4ac" if i%2 == 0 else "e9a4b7")
		k.mesh(row, verts, [[5,3,0],[5,2,3],[5,4,2],[5,0,4]], "945f83")
		k.tube(row,[d*0.043+Vector3.UP*0.03,ridge+Vector3.UP*0.015,outer],0.013,"eec5a0",6)
		k.ellipsoid(row,d*0.067+Vector3.UP*0.05,Vector3.ONE*0.090,BRASS,7,3)
		k.motion(row,"swing",tangent,0.075,float(i) * 0.04)
	k.frustum(crown,Vector3.UP*0.17,0.18,0.17,0.21,BRASS,10)
	k.ellipsoid(crown,Vector3.UP*0.29,Vector3(0.29,0.34,0.29),"!dc8ba1",8,5)
	k.ring(crown,Vector3.UP*0.29,0.15,0.020,GOLD,12)
	k.ellipsoid(crown,Vector3.UP*0.412,Vector3(0.125,0.11,0.125),"!f9dab1",8,4)
