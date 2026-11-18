extends RefCounted
## Three botanical instruments, modeled at the scale of a single parcel.
## All transforms are local to the mechanism so every viewing direction is bakeable.

const IRON := "29374a"
const IRON_EDGE := "516477"
const VERDIGRIS := "3b7f79"
const BRASS := "c78e50"
const GOLD := "f6c577"
const COPPER := "a56047"
const MOSS := "538558"

static func build(id: String, k) -> void:
	match id:
		"pitcher_still": _pitcher(k)
		"leafwing_turbine": _turbine(k)
		"taproot_drill": _drill(k)

# A hollow Nepenthes mouth. The inner wall is a separate dark, recessed surface.
# Radius, height, x drift and z drift follow the swollen and crooked pitcher body.
static func _cup_point(section: Vector4, azimuth: float, tilt: float) -> Vector3:
	var radius := section.x * (1.0 + 0.035 * cos(3.0 * azimuth + section.y * 1.8))
	return Vector3(section.z + radius * cos(azimuth), section.y - tilt * sin(azimuth),
			section.w + radius * 0.88 * sin(azimuth))

static func _cup_skin(k, owner: Node3D, rings: Array[Vector4], tilts: Array[float], colors: Array, flecked: bool = false) -> void:
	var segments := 18
	var vertices: Array = []
	var faces_by_color := {}
	for row in rings.size():
		for j in segments:
			vertices.append(_cup_point(rings[row], TAU * j / segments, tilts[row]))
	for row in rings.size() - 1:
		for j in segments:
			var dye: String = colors[row]
			if flecked and row in [2, 3, 4, 5]:
				var mottles := [2, 5, 11, 13, 16]
				if j in mottles and (j + row) % 3 != 0:
					dye = ["53866a", "87634e", "a45b59", "c26769"][row - 2]
			if not faces_by_color.has(dye): faces_by_color[dye] = []
			var a := row * segments + j
			var b := row * segments + (j + 1) % segments
			faces_by_color[dye].append([a, a + segments, b + segments, b])
	for dye: String in faces_by_color:
		k.mesh(owner, vertices, faces_by_color[dye], dye)

static func _pitcher(k) -> void:
	var body: Node3D = k.group(k.root, Vector3(-0.13, 0, -0.02))
	for j in 3:
		var phi := deg_to_rad(20.0 + 120.0 * j)
		var ray := Vector3(cos(phi), 0, sin(phi))
		var foot := ray * 0.49 + Vector3.UP * 0.075
		var ankle := ray * 0.44 + Vector3.UP * 0.15
		var knee := ray * 0.39 + Vector3.UP * 0.49
		var grip := ray * 0.355 + Vector3.UP * 0.80
		k.ellipsoid(body, foot, Vector3(0.27, 0.15, 0.22), IRON_EDGE, 8, 4)
		k.tube(body, [ankle, knee, grip], 0.065, COPPER, 7)
		k.ellipsoid(body, knee, Vector3.ONE * 0.145, BRASS, 8, 4)
	k.frustum(body, Vector3(0, 0.28, 0), 0.11, 0.35, 0.24, VERDIGRIS)
	k.ring(body, Vector3(0, 0.34, 0), 0.32, 0.025, GOLD)
	k.leaf(body, Vector3(-0.04, 0.39, 0), Vector3(-0.60, 0.26, 0.20), 0.24, 0.13, "518d68", "23545a")
	k.leaf(body, Vector3(0, 0.37, -0.04), Vector3(0.31, 0.32, -0.53), 0.30, 0.19, "6da267", "315557")
	var outer: Array[Vector4] = [
		Vector4(0.12,0.34,0,0), Vector4(0.30,0.43,0,0.01), Vector4(0.38,0.70,0.012,0.02),
		Vector4(0.34,1.02,0.035,0.02), Vector4(0.27,1.28,0.018,0.035),
		Vector4(0.29,1.46,-0.025,0.052), Vector4(0.385,1.59,-0.045,0.08),
		Vector4(0.367,1.66,-0.045,0.08), Vector4(0.277,1.61,-0.045,0.08)]
	var tilt: Array[float] = [0.0,0.0,0.01,0.025,0.052,0.095,0.13,0.13,0.112]
	_cup_skin(k,body,outer,tilt,["2c595a","366d63","569174","7c9565","a88261","b26462","e38a78","ce646f"],true)
	var inner: Array[Vector4] = [outer[-1],Vector4(0.24,1.47,-0.04,0.065),Vector4(0.13,1.35,0.0,0.052),Vector4(0.002,1.33,0.0,0.052)]
	var inner_tilt: Array[float] = [0.112,0.07,0.028,0.0]
	_cup_skin(k,body,inner,inner_tilt,["834a62","3f3b52","233c50"])
	# Pale ridges on the fleshy lip and the winged seam of the pitcher.
	for j in 12:
		var phi := j * TAU / 12.0
		k.rod(body,_cup_point(outer[7],phi,tilt[7]),_cup_point(outer[8],phi,tilt[8]),0.016,"f6b58d",5)
	for direction: float in [-1.0,1.0]:
		var phi := PI * 0.5 + direction * 0.38
		var seam: Array = []
		for row in range(2,7):
			seam.append(_cup_point(outer[row], phi, tilt[row]))
		k.tube(body,seam,0.022,"c49572",5)
	k.ring(body, Vector3(0.012,0.70,0.02), 0.369, 0.043, BRASS)
	k.ring(body, Vector3(0.012,0.65,0.02), 0.355, 0.020, IRON)
	# Arched rain hood, hinged behind the lip. A vein and highlight make its dorsal side legible.
	var hinge := Vector3(-0.05,1.68,-0.19)
	var hood: Node3D = k.group(body, hinge)
	k.tube(hood,[Vector3.ZERO,Vector3(-0.02,0.23,-0.10),Vector3(-0.09,0.39,-0.11)],0.045,"718b5d",7)
	k.leaf(hood,Vector3(-0.09,0.39,-0.11),Vector3(-0.19,0.42,0.37),0.42,0.105,"829c67","bf6f64")
	k.tube(hood,[Vector3(-0.09,0.41,-0.10),Vector3(-0.14,0.50,0.12),Vector3(-0.19,0.435,0.34)],0.014,"c3ba77",5)
	k.motion(hood,"swing",Vector3.RIGHT,0.065)
	# A short brass tap discharges into an open blue-glazed drip bowl.
	var spout := Vector3(0.58,0.69,0.24)
	k.tube(body,[Vector3(0.26,0.75,0.10),Vector3(0.36,0.75,0.20),Vector3(0.58,0.75,0.24),spout],0.05,BRASS)
	k.rod(body,Vector3(0.39,0.76,0.20),Vector3(0.39,0.89,0.20),0.032,COPPER)
	k.box(body,Vector3(0.39,0.90,0.20),Vector3(0.18,0.035,0.055),GOLD)
	var bowl := Vector3(0.58,0.18,0.24)
	k.frustum(body,bowl,0.23,0.205,0.12,"477f83",10)
	k.ring(body,bowl+Vector3.UP*0.12,0.191,0.026,BRASS,12)
	k.frustum(body,bowl+Vector3.UP*0.108,0.012,0.169,0.167,"43999c",12)
	var drop: Node3D = k.ellipsoid(body,spout-Vector3.UP*0.19,Vector3(0.07,0.115,0.07),"!9bded8",8,5)
	k.motion(drop,"slide",Vector3.UP,0.135)

# The four scimitar-shaped blades are cambered solid leaves with a midrib.
# They lie in a vertical rotor plane so the blades remain readable on the board.
static func _blade(k, rotor: Node3D, idx: int) -> void:
	var blade: Node3D = k.group(rotor, Vector3.ZERO)
	blade.rotation.z = idx * PI * 0.5 + 0.27
	var sections := [
		Vector4(0.01,0.105,0.018,0.05), Vector4(-0.012,0.24,0.036,0.105),
		Vector4(-0.085,0.40,0.075,0.165), Vector4(-0.135,0.55,0.093,0.138),
		Vector4(-0.20,0.67,0.072,0.078), Vector4(-0.267,0.76,0.042,0.007)]
	var verts: Array = []
	var ribs: Array = []
	for row: Vector4 in sections:
		verts.append(Vector3(row.x-row.w,row.y-0.03,row.z-0.022))
		var spine := Vector3(row.x,row.y,row.z+0.045)
		verts.append(spine)
		verts.append(Vector3(row.x+row.w,row.y-0.045,row.z-0.024))
		verts.append(Vector3(row.x,row.y-0.01,row.z-0.055))
		ribs.append(spine)
	var dyes := ["6fa777", "388679", "376e63", "2d585a"]
	for side in 4:
		var faces: Array = []
		for i in sections.size() - 1:
			var v := 4 * i
			var across := (side + 1) % 4
			faces.append([v+side,v+across,v+4+across,v+4+side])
		k.mesh(blade,verts,faces,dyes[side])
	k.tube(blade,ribs,0.012,"bec889",5)
	for i in [2,3]:
		k.rod(blade,verts[4*i+1],verts[4*(i+1)+2],0.008,"83ac83",5)
	var cuff: Node3D = k.box(blade,Vector3(0,0.17,0.067),Vector3(0.127,0.069,0.066),BRASS)
	cuff.rotation.z = 0.12

static func _turbine(k) -> void:
	var tower: Node3D = k.group(k.root, Vector3.ZERO)
	tower.rotation.y = 0.38
	# Splayed root feet, banded bamboo and two rear stays.
	for j in 3:
		var phi := TAU * j / 3.0 + 0.18
		var ray := Vector3(cos(phi),0,sin(phi))
		k.tube(tower,[ray*0.44+Vector3.UP*0.065,ray*0.27+Vector3.UP*0.15,Vector3(0,0.47,-0.025)],0.071,"6f7856",7)
		var foot: Node3D = k.ellipsoid(tower,ray*0.42+Vector3.UP*0.06,Vector3(0.30,0.12,0.17),IRON_EDGE,8,4)
		foot.rotation.y = -phi
	k.frustum(tower,Vector3(0,0.17,0),0.27,0.22,0.28,IRON,8)
	k.ring(tower,Vector3(0,0.28,0),0.215,0.031,GOLD,12)
	k.rod(tower,Vector3(0,0.25,-0.04),Vector3(0.04,1.48,-0.025),0.118,"78966c",9)
	for y: float in [0.42,0.79,1.13,1.4]:
		k.ring(tower,Vector3(0.024*y,y,-0.035),0.122,0.027,"a49d62",12)
	for d: float in [-1.0,1.0]:
		k.rod(tower,Vector3(0.33*d,0.10,-0.16),Vector3(0.02,0.82,-0.04),0.035,VERDIGRIS,7)
	k.leaf(tower,Vector3(0.01,0.58,0),Vector3(0.53,0.54,-0.17),0.18,0.08,"799856","315b5b")
	k.leaf(tower,Vector3(0.01,0.55,-0.01),Vector3(-0.42,0.43,0.15),0.155,0.095,"518865","315b5b")
	# Tin-can dynamo, longitudinal ribs and two copper straps. Local z is its drive axis.
	k.rod(tower,Vector3(0,1.45,-0.43),Vector3(0,1.45,0.19),0.209,VERDIGRIS,14)
	for z: float in [-0.41,-0.30,0.06,0.17]:
		k.rod(tower,Vector3(0,1.45,z-0.022),Vector3(0,1.45,z+0.022),0.222,BRASS,14)
	for j in 7:
		var phi := TAU * j / 7.0
		var side := Vector3(0.204*cos(phi),1.45+0.204*sin(phi),0)
		k.rod(tower,side+Vector3(0,0,-0.28),side+Vector3(0,0,0.04),0.016,IRON_EDGE,6)
	k.rod(tower,Vector3(0,1.44,-0.41),Vector3(0,1.54,-0.75),0.045,IRON)
	var vane := [Vector3(0,1.55,-0.43),Vector3(0,1.76,-0.66),Vector3(0,1.81,-0.84),Vector3(0,1.46,-0.76)]
	k.mesh(tower,vane,[[0,1,2,3]],"6ba497")
	var rotor: Node3D = k.group(tower,Vector3(0,1.45,0.22))
	for i in 4:
		_blade(k,rotor,i)
	k.rod(rotor,Vector3(0,0,-0.066),Vector3(0,0,0.105),0.171,"8e633f",12)
	k.rod(rotor,Vector3(0,0,0.103),Vector3(0,0,0.143),0.14,GOLD,12)
	k.ellipsoid(rotor,Vector3(0,0,0.152),Vector3(0.16,0.16,0.09),"!76cabb",10,5)
	# Identical blades repeat every quarter turn; eight samples then advance 11.25 degrees each.
	k.motion(rotor,"spin",Vector3.BACK,0.25)

# A helical cutting fin wraps the tapered, crooked root rather than a straight screw.
# The exterior copper bevel and the shadowed underside have separate materials.
static func _root_center(t: float) -> Vector3:
	return Vector3(0.065*sin(t*4.2),0.075+t*0.99,0.048*cos(t*5.0))

static func _auger(k, chuck: Node3D) -> void:
	var spine: Array = []
	var surface: Array = []
	var bevel: Array = []
	var back: Array = []
	const STEPS := 48
	for i in STEPS + 1:
		var t := float(i) / STEPS
		var c := _root_center(t)
		var radius := 0.034 + 0.126 * t
		var angle := (t * 1.85 - 0.1) * TAU
		var dir := Vector3(cos(angle),0,sin(angle))
		var rim := c + dir * (radius + sin(t*PI*0.80) * 0.105 + t*0.048)
		surface.append(c + dir*radius + Vector3.UP * 0.049)
		surface.append(rim + Vector3.UP*(0.012+0.022*t))
		bevel.append(rim + Vector3.UP*(0.012+0.022*t))
		bevel.append(rim - Vector3.UP*0.018)
		back.append(rim - Vector3.UP*0.018)
		back.append(c + dir*radius - Vector3.UP*0.01)
		if i % 8 == 0: spine.append(c)
	var faces: Array = []
	for i in STEPS:
		var a := i * 2
		faces.append([a,a+2,a+3,a+1])
	k.mesh(chuck,surface,faces,"b28b60")
	k.mesh(chuck,bevel,faces,"e1af76")
	k.mesh(chuck,back,faces,"675551")
	for i in spine.size()-1:
		var a: Vector3 = spine[i]
		var b: Vector3 = spine[i+1]
		k.rod(chuck,a,b,0.057 + 0.017*i,"696151",9)
		k.ellipsoid(chuck,b,Vector3.ONE*(0.115+0.034*i),"79614b",9,4)

static func _drill(k) -> void:
	var chassis: Node3D = k.group(k.root,Vector3.ZERO)
	# Two massive rear struts and a shorter low brace leave an open bay for the bit.
	for j in 3:
		var phi := deg_to_rad(83.0 + 120*j)
		var ray := Vector3(cos(phi),0,sin(phi))
		var foot := ray * 0.58 + Vector3.UP * 0.08
		var shoe: Node3D = k.box(chassis,foot,Vector3(0.36,0.14,0.26),IRON)
		shoe.rotation.y = -phi
		var knee := ray * 0.48 + Vector3.UP * 0.36
		var shoulder := ray * 0.34 + Vector3.UP * 1.00
		k.tube(chassis,[foot+Vector3.UP*0.07,knee,shoulder],0.071,"68766e",8)
		k.ellipsoid(chassis,knee,Vector3.ONE*0.17,COPPER,8,4)
		k.ellipsoid(chassis,shoulder,Vector3.ONE*0.18,BRASS,8,4)
		k.rod(chassis,foot+Vector3.UP*0.15,ray*0.33+Vector3.UP*0.60,0.032,IRON_EDGE)
	var chuck: Node3D = k.group(chassis,Vector3.ZERO)
	_auger(k,chuck)
	k.motion(chuck,"spin",Vector3.UP,-1.0)
	# Broad oxidised drive collar. Teeth are tucked between the turned brass lips.
	k.frustum(chassis,Vector3(0,0.995,0),0.18,0.31,0.25,IRON,14)
	k.frustum(chassis,Vector3(0,1.14,0),0.23,0.395,0.335,BRASS,14)
	k.ring(chassis,Vector3(0,1.045,0),0.33,0.038,"e8b269",16)
	k.ring(chassis,Vector3(0,1.250,0),0.387,0.041,GOLD,16)
	for i in 9:
		var phi := TAU*i/9.0
		var rail: Node3D = k.box(chassis,Vector3(0.36*cos(phi),1.15,0.36*sin(phi)),Vector3(0.072,0.12,0.06),IRON_EDGE)
		rail.rotation.y = -phi
		k.ellipsoid(chassis,Vector3(0.389*cos(phi),1.17,0.389*sin(phi)),Vector3.ONE*0.047,"e9b672",7,4)
	# Main taproot crown and bark buttresses connect to an overhanging extraction elbow.
	k.ellipsoid(chassis,Vector3(-0.045,1.40,-0.018),Vector3(0.64,0.52,0.58),"846850",12,6)
	k.ellipsoid(chassis,Vector3(-0.095,1.61,0.005),Vector3(0.42,0.38,0.37),"9a7551",10,5)
	for i in 7:
		var phi := TAU*i/7.0+0.2
		var ray := Vector3(cos(phi),0,sin(phi))
		k.tube(chassis,[Vector3(-0.11,1.77,-0.01)+ray*0.056,Vector3(-0.065,1.60,0.0)+ray*0.18,
			Vector3(-0.03,1.46,-0.015)+ray*0.28,Vector3(0,1.29,0)+ray*0.26],0.045,"718568" if i%3==0 else "aa825b",6)
	# Forked woody stem with two living leaves.
	k.tube(chassis,[Vector3(-0.10,1.68,0.0),Vector3(-0.17,1.85,-0.05),Vector3(-0.08,2.02,-0.10)],0.071,"735f52",7)
	k.tube(chassis,[Vector3(-0.15,1.84,-0.05),Vector3(-0.29,1.92,0.06),Vector3(-0.34,1.94,0.16)],0.046,"806d53",7)
	k.leaf(chassis,Vector3(-0.08,2.0,-0.10),Vector3(0.26,1.99,-0.17),0.18,0.12,"769c60","355d52")
	k.leaf(chassis,Vector3(-0.31,1.94,0.13),Vector3(-0.60,1.80,0.20),0.19,0.09,"4e8c65","335b58")
	# Side unit: a flanged flywheel and a downward-angled ore outlet.
	k.tube(chassis,[Vector3(0.26,1.37,-0.02),Vector3(0.43,1.42,-0.04),Vector3(0.53,1.37,-0.02),
		Vector3(0.57,1.18,0.14),Vector3(0.59,1.15,0.21)],0.088,VERDIGRIS,9)
	k.rod(chassis,Vector3(0.55,1.20,0.12),Vector3(0.605,1.135,0.24),0.12,BRASS,9)
	k.rod(chassis,Vector3(-0.23,1.43,0.04),Vector3(-0.42,1.47,0.10),0.098,COPPER,10)
	var wheel: Node3D = k.group(chassis,Vector3(-0.40,1.47,0.08))
	wheel.rotation.z = -1.13
	k.ring(wheel,Vector3.ZERO,0.21,0.047,BRASS,12)
	k.frustum(wheel,Vector3.ZERO,0.13,0.082,0.082,VERDIGRIS,12)
	for i in 3:
		var phi := TAU*i/3.0
		k.rod(wheel,Vector3.ZERO,Vector3(0.20*cos(phi),0,0.20*sin(phi)),0.025,BRASS,6)
	k.motion(wheel,"spin",Vector3.UP,1.0/3.0)
