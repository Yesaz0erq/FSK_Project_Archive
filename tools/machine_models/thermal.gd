extends RefCounted
## Orthographic sculpture masters for the four heat- and vapour-handling machines.
## Each root is grounded at y=0. Front-facing instruments read from the default board view.

const IRON := "263448"
const IRON_EDGE := "536c79"
const COPPER := "bc784b"
const BRASS := "d9a45c"
const GOLD := "f3ce85"
const PATINA := "347773"

static func build(id: String, k) -> void:
	var stand: Node3D = k.group(k.root, Vector3.ZERO)
	stand.rotation.y = 0.34
	match id:
		"seedpod_kiln": _kiln(k, stand)
		"gourd_kettle": _kettle(k, stand)
		"ember_lily": _lily(k, stand)
		"mist_fern": _fern(k, stand)

static func _radial(angle: float) -> Vector3:
	return Vector3(sin(angle), 0, cos(angle))

# Ring profile values are (radius, elevation). Alternate adjacent facets cast
# different hues, like distinct ceramic scales, gourd lobes or cast plates.
static func _body(k, parent: Node3D, profile: Array, colors: Array, sides: int, flute: float = 0.0, lean: float = 0.0) -> void:
	var vertices: Array = []
	var batches: Array = []
	for color in colors:
		batches.append([])
	for row: Vector2 in profile:
		for i in sides:
			var direction := _radial(TAU * i / sides)
			var r := row.x * (1.0 - flute * (i % 2))
			vertices.append(direction * r + Vector3(lean * row.y * row.y, row.y, 0))
	for j in range(profile.size() - 1):
		for i in sides:
			var left := j * sides + i
			var right := j * sides + (i + 1) % sides
			var index := i % colors.size()
			batches[index].append([left, right, right + sides, left + sides])
	for i in colors.size():
		k.mesh(parent, vertices, batches[i], colors[i])

# Solid arch profile with a recessed face, made from an extruded polygon fan.
static func _panel(k, parent: Node3D, rim: Array, depth: float, color: String) -> void:
	var verts := []
	var faces := []
	var front := []
	var back := []
	for v: Vector2 in rim:
		verts.append(Vector3(v.x, v.y, 0))
	for v: Vector2 in rim:
		verts.append(Vector3(v.x, v.y, depth))
	for i in rim.size():
		var next := (i + 1) % rim.size()
		faces.append([i, next, next + rim.size(), i + rim.size()])
		front.append(i + rim.size())
		back.append(rim.size() - 1 - i)
	faces.append(front)
	faces.append(back)
	k.mesh(parent, verts, faces, color)

static func _kiln(k, root: Node3D) -> void:
	# A splayed refractory kiln with an exposed ash shelf and a petal cowl.
	for a: float in [0.68, 2.44, 3.88, 5.62]:
		var foot := _radial(a) * 0.51
		var block: Node3D = k.box(root, foot + Vector3.UP * 0.11, Vector3(0.30, 0.22, 0.36), IRON)
		block.rotation.y = a
	k.frustum(root, Vector3(0,0.24,0), 0.18, 0.70, 0.61, "445260", 10)
	k.ring(root, Vector3(0,0.31,0), 0.67, 0.035, COPPER, 12)
	_body(k, root, [Vector2(0.59,0.30), Vector2(0.73,0.54), Vector2(0.69,1.00), Vector2(0.56,1.29), Vector2(0.35,1.47), Vector2(0.26,1.51)], ["b56549","a75a46","c78358","925048","b87250","ca865d"], 18, 0.044)
	for i in 8:
		var dir := _radial(TAU * (i + 0.48) / 8)
		# The fuel mouth interrupts the pod fluting on the front face.
		if dir.z > 0.78: continue
		var scale_node: Node3D = k.group(root, Vector3.ZERO)
		scale_node.rotation.y = atan2(dir.x, dir.z)
		k.mesh(scale_node, [Vector3(0,1.47,0.31),Vector3(-0.12,1.29,0.55),Vector3(0,1.16,0.687),Vector3(0.12,1.29,0.55),Vector3(0,0.52,0.745)], [[0,1,2],[0,2,3],[1,4,2],[2,4,3]], "d69462" if i % 3 != 1 else "a15b51")
		k.ellipsoid(root, dir * 0.55 + Vector3.UP * 1.30, Vector3(0.077,0.08,0.077), BRASS, 7, 4)
	# The portal projects from the belly; deep iron jambs cast a shadow on the hot slats.
	var mouth: Node3D = k.group(root, Vector3(0,0.42,0.55))
	_panel(k, mouth, [Vector2(-0.38,0),Vector2(0.38,0),Vector2(0.38,0.40),Vector2(0.27,0.56),Vector2(0,0.65),Vector2(-0.27,0.56),Vector2(-0.38,0.40)], 0.15, "414650")
	var recess: Node3D = k.group(mouth, Vector3(0,0.055,0.151))
	_panel(k, recess, [Vector2(-0.28,0),Vector2(0.28,0),Vector2(0.28,0.32),Vector2(0.17,0.45),Vector2(0,0.50),Vector2(-0.17,0.45),Vector2(-0.28,0.32)], 0.02, "482f3b")
	var fire: Node3D = k.group(recess, Vector3(0.0,0.04,0.028))
	k.motion(fire, "slide", Vector3.UP, 0.024, 0.16)
	var h := [0.19,0.26,0.34,0.21,0.27]
	for i in 5:
		var x := -0.192 + i * 0.096
		k.mesh(fire, [Vector3(x-0.068,0,0),Vector3(x+0.066,0,0),Vector3(x+0.045,h[i]*0.53,0.02),Vector3(x-0.028,h[i],0.0),Vector3(x-0.04,h[i]*0.45,0.026)], [[0,1,2,4],[4,2,3]], "!ff9c42" if i % 2 == 0 else "!ffc961")
	for i in 3:
		k.box(mouth, Vector3(0,0.15 + i * 0.118,0.216), Vector3(0.54,0.039,0.038), "543d40")
	for side: float in [-1.0,1.0]:
		k.ellipsoid(mouth, Vector3(side*0.323,0.14,0.177), Vector3.ONE * 0.063, GOLD, 8,4)
	k.box(root, Vector3(0,0.397,0.64), Vector3(0.81,0.083,0.38), COPPER)
	# An iron neck and five upturned dry sepals guard a black flue.
	k.frustum(root, Vector3(0,1.54,0),0.22,0.235,0.29,IRON,10)
	k.ring(root,Vector3(0,1.50,0),0.25,0.047,BRASS,12)
	k.frustum(root,Vector3(0,1.685,0),0.22,0.185,0.15,"704d4d",9)
	k.ring(root,Vector3(0,1.80,0),0.185,0.04,COPPER,10)
	k.frustum(root,Vector3(0,1.802,0),0.008,0.145,0.145,"2c2837",10)
	for i in 5:
		var a := TAU*i/5.0
		var bud: Node3D = k.group(root, _radial(a) * 0.22 + Vector3.UP * 1.49)
		bud.rotation.y = a
		# The five hinged sepals regulate the kiln draft around the flue.
		k.motion(bud, "swing", Vector3.RIGHT, 0.14, 0.0)
		k.leaf(bud,Vector3.ZERO,Vector3(0,0.59,0.23),0.19,0.035,"aa693f","683f41")
		k.rod(bud,Vector3(0,0.03,0.014),Vector3(0,0.50,0.19),0.018,BRASS,6)
	k.tube(root, [Vector3(-0.57,0.60,0.18),Vector3(-0.76,0.61,0.24),Vector3(-0.76,1.17,0.22),Vector3(-0.49,1.27,0.13)], 0.048, PATINA,8)

static func _kettle(k, root: Node3D) -> void:
	# Two gourd lobes grow into one vessel; an iron cradle holds it above geothermal shoes.
	var vessel: Node3D = k.group(root, Vector3(-0.06,0,0))
	for i in 3:
		var dir := _radial(i*TAU/3.0+0.12)
		var toe := dir*0.60 + Vector3.UP*0.08
		k.ellipsoid(root,toe,Vector3(0.29,0.15,0.29),IRON,9,4)
		k.rod(root,toe,dir*0.41+Vector3.UP*0.48,0.088,IRON_EDGE,8)
	_body(k,vessel,[Vector2(0.25,0.24),Vector2(0.48,0.32),Vector2(0.64,0.54),Vector2(0.67,0.81),Vector2(0.59,1.04),Vector2(0.38,1.25),Vector2(0.25,1.38),Vector2(0.33,1.48),Vector2(0.35,1.62),Vector2(0.25,1.77),Vector2(0.13,1.81)],["bd9149","c7a457","b48142","cea65a","b8904c","a77b49"],18,0.07,-0.042)
	for belt: Vector2 in [Vector2(0.45,0.57),Vector2(0.88,0.65)]:
		k.frustum(vessel,Vector3(-0.025,belt.x,0),0.083,belt.y,belt.y,IRON,18)
		k.ring(vessel,Vector3(-0.025,belt.x+0.043,0),belt.y,0.019,"bd985f",18)
		for a: float in [0.20,1.54,2.82,4.12,5.33]:
			k.ellipsoid(vessel,_radial(a)*belt.y+Vector3(-0.025,belt.x,0),Vector3.ONE*0.065,BRASS,8,4)
	k.frustum(vessel,Vector3(-0.085,1.39,0),0.08,0.265,0.28,IRON_EDGE,14)
	k.ring(vessel,Vector3(-0.138,1.81,0),0.13,0.04,BRASS,12)
	# Bent reed whistle: a flared hollow bell and couplings show the steam path.
	var reed := [Vector3(-0.20,1.80,0),Vector3(-0.24,1.98,0),Vector3(-0.47,2.05,0.02),Vector3(-0.61,1.98,0.09)]
	k.tube(root,reed,0.071,"669b77",9)
	var bell: Node3D = k.group(root,reed[3])
	var tangent: Vector3 = (reed[3]-reed[2]).normalized()
	bell.quaternion = Quaternion(Vector3.UP, tangent)
	k.frustum(bell,Vector3(0,0.08,0),0.16,0.145,0.069,BRASS,10)
	k.frustum(bell,Vector3(0,0.163,0),0.01,0.117,0.117,IRON,10)
	k.ring(bell,Vector3(0,0.168,0),0.137,0.017,GOLD,12)
	# Feedwater sight glass and a flyball regulator.
	var pipe := [Vector3(0.40,0.58,-0.14),Vector3(0.68,0.60,-0.14),Vector3(0.68,1.26,-0.14),Vector3(0.33,1.42,-0.10)]
	k.tube(root,pipe,0.069,PATINA,9)
	k.frustum(root,Vector3(0.68,0.95,-0.14),0.39,0.052,0.052,"!70babb",8)
	for y: float in [0.72,1.18]:
		k.ring(root,Vector3(0.68,y,-0.14),0.073,0.019,BRASS,10)
	k.rod(root,Vector3(0.67,1.15,-0.14),Vector3(0.67,1.56,-0.14),0.043,BRASS,9)
	var governor: Node3D = k.group(root,Vector3(0.66,1.53,-0.14))
	# The identical weights repeat after half a turn, including at the loop edge.
	k.motion(governor,"spin",Vector3.UP,0.5)
	for sign_value: float in [-1,1]:
		var weight := Vector3(sign_value*0.17,-0.095,0)
		k.rod(governor,Vector3.ZERO,weight,0.026,IRON_EDGE,7)
		k.ellipsoid(governor,weight,Vector3.ONE*0.105,GOLD,9,5)
	var dial: Node3D = k.group(root,Vector3(-0.04,1.09,0.52))
	dial.rotation.x = deg_to_rad(66)
	k.frustum(dial,Vector3.ZERO,0.068,0.176,0.168,IRON,12)
	k.frustum(dial,Vector3.UP*0.045,0.018,0.142,0.142,"a9d0ba",12)
	k.ring(dial,Vector3.UP*0.049,0.155,0.025,BRASS,14)
	var needle: Node3D = k.group(dial,Vector3.UP*0.067)
	k.rod(needle,Vector3.ZERO, Vector3(0.069,0,0.073),0.014,"7e4144",6)
	k.motion(needle,"swing",Vector3.UP,0.42)
	k.leaf(vessel,Vector3(-0.13,1.77,-0.09),Vector3(0.37,1.91,-0.27),0.22,0.11,"589273","305f65")

static func _petal(k, parent: Node3D, length: float, wide: float, outer: bool) -> void:
	var shoulder := length * 0.48
	var y := 0.32 if outer else 0.46
	var verts := [Vector3.ZERO, Vector3(-wide*0.66,0.07,length*0.23),Vector3(wide*0.66,0.07,length*0.23),
		Vector3(-wide,0.12,shoulder),Vector3(wide,0.12,shoulder),Vector3(0,0.035,shoulder),
		Vector3(-wide*0.68,y*0.7,length*0.80),Vector3(wide*0.68,y*0.7,length*0.80),
		Vector3(0,y*0.48,length*0.76),Vector3(0,y,length),Vector3(0,0.015,length*0.45)]
	k.mesh(parent,verts,[[0,1,5],[1,3,5],[3,6,8,5],[6,9,8]],"fb8956" if outer else "ffc265")
	k.mesh(parent,verts,[[0,5,2],[5,4,2],[5,8,7,4],[8,9,7]],"d76552" if outer else "f9a052")
	k.mesh(parent,verts,[[0,2,10,1],[1,10,6,3],[2,4,7,10],[6,10,9],[10,7,9]],"99495a" if outer else "c9674e")

static func _lily(k, root: Node3D) -> void:
	# A plant held in a standing lantern. Spaced cage struts frame the cup.
	k.frustum(root,Vector3.UP*0.10,0.17,0.36,0.46,"394857",9)
	k.ring(root,Vector3.UP*0.17,0.33,0.043,BRASS,12)
	for i in 6:
		var d := _radial(TAU*i/6.0+0.3)
		k.leaf(root,Vector3.UP*0.21,d*(0.62 if i%2==0 else 0.48)+Vector3.UP*(0.17 if i%2==0 else 0.29),0.22,0.22,"3e907b" if i%2==0 else "598f70","284f5b")
	k.tube(root,[Vector3(0,0.18,0),Vector3(-0.13,0.57,0.04),Vector3(-0.07,0.87,-0.03),Vector3(0,1.18,0)],0.11,PATINA,9)
	k.leaf(root,Vector3(-0.08,0.65,0),Vector3(-0.54,0.94,0.06),0.19,0.11,"7faf7c","346369")
	k.frustum(root,Vector3.UP*1.11,0.20,0.40,0.17,IRON_EDGE,12)
	k.ring(root,Vector3.UP*1.21,0.46,0.045,BRASS,16)
	for i in 7:
		var petal: Node3D = k.group(root,Vector3.UP*1.25)
		petal.rotation.y = TAU * i / 7.0 + 0.2
		_petal(k,petal,0.67,0.193,true)
		k.motion(petal,"swing",Vector3.RIGHT,0.068,0.10 * sin(float(i)))
	for i in 5:
		var inner: Node3D = k.group(root,Vector3.UP*1.31)
		inner.rotation.y = TAU*i/5.0 + 0.47
		_petal(k,inner,0.41,0.139,false)
		k.motion(inner,"swing",Vector3.RIGHT,0.080,0.22)
	var heart: Node3D = k.group(root,Vector3.UP*1.51)
	k.ellipsoid(heart,Vector3.ZERO,Vector3(0.22,0.32,0.22),"!ffcd69",9,5)
	k.motion(heart,"slide",Vector3.UP,0.056,0.13)
	for i in 4:
		var d := _radial(PI*0.26+i*TAU/4.0)
		# Filigree arches meet at a pierced crown, leaving open windows to see the flower.
		k.tube(root,[d*0.38+Vector3.UP*1.15,d*0.66+Vector3.UP*1.36,d*0.68+Vector3.UP*1.66,d*0.43+Vector3.UP*1.93,d*0.12+Vector3.UP*2.05],0.033,"bd965f",7)
		k.ellipsoid(root,d*0.66+Vector3.UP*1.36,Vector3.ONE*0.093,IRON_EDGE,8,4)
	k.ring(root,Vector3.UP*2.06,0.129,0.035,GOLD,12)
	k.frustum(root,Vector3.UP*2.14,0.14,0.052,0.112,PATINA,9)
	var loop: Node3D = k.ring(root,Vector3.UP*2.25,0.10,0.022,BRASS,12)
	loop.rotation.x = PI*0.5

static func _frond(k, root: Node3D, angle: float, reach: float, rise: float, hue: String, phase: float) -> void:
	var branch: Node3D = k.group(root,Vector3(0,0.98,-0.025))
	branch.rotation.y = angle
	var spine: Array = []
	for i in 8:
		var u := i/7.0
		spine.append(Vector3(0, rise*(1.73*u-0.73*u*u) + 0.13*sin(u*PI),reach*pow(u,1.32)))
	k.tube(branch,spine,0.028,"81b68b",7)
	for i in range(1,7):
		var t := float(i)/7.0
		var span := 0.079 + sin(t*PI)*0.174
		for side: float in [-1,1]:
			var start: Vector3 = spine[i]
			var end := start + Vector3(signf(side)*span,0.042+0.12*(1.0-t),0.085+0.13*t)
			k.leaf(branch,start,end,(0.105+sin(t*PI)*0.037),0.038,hue,"285766")
	k.leaf(branch,spine[6],spine[7]+Vector3(0,0.018,0.065),0.143,0.025,"8eb895","386f71")
	k.motion(branch,"swing",Vector3.RIGHT,0.055,phase)

static func _fern(k, root: Node3D) -> void:
	# Suspended accordion lungs, with a ceramic water cistern and two different nozzle sizes.
	for d: Vector3 in [Vector3(-0.42,0,0.26), Vector3(0.42,0,0.26),Vector3(0,0,-0.43)]:
		k.ellipsoid(root,d+Vector3.UP*0.073,Vector3(0.22,0.15,0.22),IRON,8,4)
	k.frustum(root,Vector3(0,0.30,0),0.37,0.49,0.39,"467c83",10)
	k.ring(root,Vector3.UP*0.19,0.42,0.036,IRON_EDGE,10)
	k.ring(root,Vector3.UP*0.48,0.49,0.04,BRASS,12)
	for i in 5:
		var height := 0.5 + i*0.084
		var fold: Node3D = k.group(root,Vector3.UP*height)
		k.frustum(fold,Vector3.UP*0.025,0.049,0.365,0.424,"66768a",12)
		k.frustum(fold,Vector3.UP*0.061,0.047,0.424,0.365,"354956",12)
		k.motion(fold,"slide",Vector3.UP,0.012 * i)
	var lid: Node3D = k.group(root,Vector3.UP*0.94)
	k.frustum(lid,Vector3.ZERO,0.09,0.38,0.45,"578e83",12)
	k.ring(lid,Vector3.UP*0.035,0.389,0.028,BRASS,12)
	k.motion(lid,"slide",Vector3.UP,0.052)
	for i in 3:
		var direction := _radial(2.75 + TAU*i/3.0)
		k.rod(root,direction*0.46+Vector3.UP*0.46,direction*0.40+Vector3.UP*1.01,0.027,BRASS,7)
	_frond(k,root,0.11,0.56,0.57,"4c9780",0.00)
	_frond(k,root,1.52,0.59,0.82,"6eb18a",0.16)
	_frond(k,root,2.63,0.44,1.20,"6aa58b",0.28)
	_frond(k,root,4.22,0.63,0.96,"6fae86",0.46)
	_frond(k,root,5.28,0.58,0.62,"498c78",0.09)
	var tendril: Node3D = k.group(root,Vector3(-0.04,0.97,0))
	var coil := [Vector3.ZERO,Vector3(-0.10,0.50,0.03),Vector3(-0.08,0.85,0),Vector3(-0.14,1.03,-0.09),Vector3(-0.27,1.10,-0.09),Vector3(-0.36,1.02,-0.05),Vector3(-0.33,0.92,-0.02),Vector3(-0.25,0.93,-0.02)]
	k.tube(tendril,coil,0.036,"96bf8e",7)
	k.motion(tendril,"swing",Vector3.FORWARD,0.037,0.15)
	for side: float in [-1,1]:
		var start := Vector3(side*0.35,0.41,0.14)
		var mid := Vector3(side*0.59,0.55,0.22)
		var end := Vector3(side*0.66,0.73 if side>0 else 0.63,0.31)
		k.tube(root,[start,mid,end],0.07,PATINA,8)
		var jet: Node3D = k.group(root,end)
		jet.quaternion = Quaternion(Vector3.UP,(end-mid).normalized())
		k.frustum(jet,Vector3.UP*0.034,0.09,0.12,0.067,IRON_EDGE,9)
		k.ring(jet,Vector3.UP*0.083,0.104,0.022,BRASS,10)
		k.frustum(jet,Vector3.UP*0.086,0.005,0.072,0.069,"!80c9cd",8)
