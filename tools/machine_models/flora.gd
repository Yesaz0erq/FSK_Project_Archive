extends RefCounted
## Flora implements share a seedling's plum rootstock and brass cambium collars.
## The four seed spoons and gathering fronds correspond to their cardinal plots.
## The extractor feeds its canister through eight separate radial root intakes.

const ROOT := "554056"
const ROOT_LIT := "866058"
const BRONZE := "a67051"
const BRASS := "dbad68"
const PATINA := "396f6b"
const DEEP := "26384c"
const JADE := "538e74"
const LIME := "a6b76d"
const SEED := "!efc67d"
const ESSENCE := "!74cfb1"

static func build(id: String, k) -> void:
	match id:
		"propagator": _seed_head(k)
		"collector": _collecting_rosette(k)
		"extractor": _sap_pump(k)

static func _dir(index: int, count: int, offset := 0.0) -> Vector3:
	var theta := TAU * index / count + offset
	return Vector3(sin(theta), 0, cos(theta))

static func _root_fan(k, n: int, spread: float) -> void:
	for i in n:
		var r := _dir(i,n)
		var root_tip := r * spread + Vector3.UP * 0.049
		k.tube(k.root, [Vector3.UP*0.45, r*0.19+Vector3.UP*0.30, r*(spread*0.69)+Vector3.UP*0.16, root_tip], 0.076 if n>4 else 0.091, ROOT_LIT if i%2 else ROOT, 8)
		k.ellipsoid(k.root, root_tip, Vector3(0.16,0.097,0.15), PATINA, 8,4)
		k.leaf(k.root, r*0.17+Vector3.UP*0.20, r*(spread*0.92)+Vector3.UP*0.13, 0.18,0.115,JADE,PATINA)

static func _pod(k, parent: Node3D, origin: Vector3, size: float) -> void:
	# A split, pointed seed case reveals its pale kernel between two purple valves.
	var seed: Node3D = k.group(parent, origin)
	seed.scale = Vector3.ONE * size
	k.ellipsoid(seed,Vector3.UP*0.11,Vector3(0.16,0.27,0.16),SEED,9,5)
	k.leaf(seed,Vector3(0,-0.04,0),Vector3(0.12,0.27,0.035),0.14,0.065,"aa7273","794d65")
	k.leaf(seed,Vector3(0,-0.04,0),Vector3(-0.085,0.24,-0.075),0.15,0.052,"c08e6a","87595d")

static func _seed_head(k) -> void:
	_root_fan(k,4,0.65)
	k.frustum(k.root,Vector3.UP*0.27,0.26,0.22,0.32,PATINA,12)
	k.ring(k.root,Vector3.UP*0.33,0.26,0.035,BRASS)
	k.tube(k.root,[Vector3.UP*0.30,Vector3(-0.07,0.62,0),Vector3(0.055,1.05,-0.035),Vector3.UP*1.47],0.118,JADE,10)
	k.tube(k.root,[Vector3(0.12,0.29,-0.12),Vector3(0.13,0.62,-0.08),Vector3(0.18,1.00,-0.13),Vector3(0.1,1.40,-0.07)],0.032,BRASS,8)
	for i in 4:
		var r := _dir(i,4,0.40)
		var root := Vector3.UP * (0.51 + (i%2)*0.20)
		k.leaf(k.root,root,root+r*0.50 + Vector3.UP*0.25,0.26,0.16,JADE if i%2 else LIME,PATINA)
	k.frustum(k.root,Vector3.UP*1.29,0.20,0.22,0.17,DEEP,12)
	k.ring(k.root,Vector3.UP*1.34,0.215,0.034,BRASS)
	var head: Node3D = k.group(k.root,Vector3.UP * 1.44)
	k.motion(head,"spin",Vector3.UP,0.25)
	k.frustum(head,Vector3.ZERO,0.21,0.25,0.17,BRONZE,12)
	k.ring(head,Vector3.UP*0.08,0.23,0.036,BRASS,16)
	for i in 4:
		var r := _dir(i,4)
		var side := Vector3(r.z,0,-r.x)
		# Curving spoon arms fling seeds out as the turntable advances.
		var elbow := r*0.42 + Vector3.UP*0.08 + side*0.085
		var end := r*0.65 + side*0.15 + Vector3.UP*0.15
		k.tube(head,[r*0.10,elbow,end],0.046,PATINA,8)
		k.leaf(head,elbow-side*0.07,end+side*0.17+Vector3.UP*0.10,0.27,0.07,LIME,JADE)
		k.ellipsoid(head,end-side*0.02,Vector3(0.18,0.11,0.18),BRASS,8,3)
		_pod(k,head,end+Vector3.UP*0.05,0.83)
	# A seedhead opens in the center; its brass calyx keeps young seeds upright.
	for i in 6:
		var radial := _dir(i,6,0.15)
		var shoot := Vector3.UP * 1.56
		k.leaf(k.root,shoot,shoot+radial*0.24+Vector3.UP*0.52,0.18,0.12,LIME if i%2 else JADE,"587666")
		_pod(k,k.root,shoot+radial*0.12+Vector3.UP*0.235,0.90)
	_pod(k,k.root,Vector3.UP*2.00,0.92)

static func _collecting_rosette(k) -> void:
	_root_fan(k,4,0.67)
	k.frustum(k.root,Vector3.UP*0.30,0.32,0.43,0.30,DEEP,12)
	k.ring(k.root,Vector3.UP*0.45,0.415,0.045,BRASS)
	for i in 4:
		var r := _dir(i,4,PI/4.0)
		k.rod(k.root,r*0.29+Vector3.UP*0.44,r*0.27+Vector3.UP*0.88,0.058,BRONZE,8)
	k.frustum(k.root,Vector3.UP*0.75,0.60,0.31,0.23,PATINA,12)
	k.frustum(k.root,Vector3.UP*1.04,0.18,0.47,0.29,JADE,12)
	k.ring(k.root,Vector3.UP*1.10,0.447,0.032,BRASS)
	# An open shell, modeled as a fan of five cross-sections with an inset vein.
	for i in 4:
		var shell: Node3D = k.group(k.root,Vector3.UP*1.10)
		shell.rotation.y = TAU*i/4.0
		k.motion(shell,"swing",Vector3.RIGHT,0.060,0.0)
		var verts: Array = []
		var left: Array = []
		var right: Array = []
		var keel: Array[Vector3] = []
		for s: Vector3 in [Vector3(0.13,0.00,0.075),Vector3(0.27,0.08,0.24),Vector3(0.47,0.21,0.33),Vector3(0.66,0.43,0.24),Vector3(0.77,0.62,0.11),Vector3(0.80,0.73,0.008)]:
			var center := Vector3(0,s.y,s.x)
			verts.append(center + Vector3(-s.z,s.z*0.48,0))
			verts.append(center)
			verts.append(center + Vector3(s.z,s.z*0.48,0))
			keel.append(center+Vector3.UP*0.025)
			if verts.size()>3:
				var n := verts.size()-3
				left.append([n-3,n,n+1,n-2])
				right.append([n-2,n+1,n+2,n-1])
		k.mesh(shell,verts,left,"4c9690")
		k.mesh(shell,verts,right,"2a686c")
		k.tube(shell,keel,0.015,BRASS,6)
		for side: float in [-1.0,1.0]:
			k.tube(shell,[Vector3(side*0.10,0.042,0.18),Vector3(side*0.27,0.29,0.47),Vector3(side*0.16,0.46,0.65),Vector3(0,0.735,0.80)],0.022,"9abe92",7)
		var dew: Node3D = k.ellipsoid(shell,Vector3(0,0.36,0.54),Vector3(0.085,0.095,0.085),ESSENCE,9,5)
		k.motion(dew,"slide",Vector3(0,0.7,0.7),0.10)
	k.frustum(k.root,Vector3.UP*1.16,0.15,0.21,0.27,"574757",12)
	k.ring(k.root,Vector3.UP*1.25,0.19,0.034,BRASS,12)
	var pearl: Node3D = k.group(k.root,Vector3.UP*1.50)
	k.motion(pearl,"slide",Vector3.UP,0.085)
	k.ellipsoid(pearl,Vector3.ZERO,Vector3(0.29,0.36,0.29),"!99d888",10,5)
	k.ring(pearl,Vector3.UP*0.014,0.174,0.016,BRASS,12)

static func _sap_pump(k) -> void:
	_root_fan(k,8,0.77)
	# All eight intake roots visibly enter separate ports in the lower pumping manifold.
	k.frustum(k.root,Vector3.UP*0.28,0.20,0.46,0.35,DEEP,16)
	for i in 8:
		var r := _dir(i,8)
		k.tube(k.root,[r*0.75+Vector3.UP*0.09,r*0.55+Vector3.UP*0.23,r*0.43+Vector3.UP*0.40],0.047,PATINA if i%2 else BRONZE,8)
		k.ellipsoid(k.root,r*0.42+Vector3.UP*0.40,Vector3.ONE*0.12,BRASS,9,4)
	k.frustum(k.root,Vector3.UP*0.46,0.21,0.41,0.46,"664c62",12)
	k.ring(k.root,Vector3.UP*0.52,0.408,0.032,BRASS)
	var tank := Vector3(-0.14,0,-0.08)
	var vessel: Node3D = k.group(k.root,tank)
	k.ellipsoid(vessel,Vector3.UP*0.66,Vector3(0.73,0.36,0.73),PATINA,12,5)
	k.frustum(vessel,Vector3.UP*1.08,0.81,0.34,0.34,"39656b",12)
	var charge: Node3D = k.group(vessel,Vector3.UP*0.96)
	k.motion(charge,"slide",Vector3.UP,0.055,0.125)
	k.frustum(charge,Vector3.ZERO,0.54,0.347,0.349,"58af9c",12)
	k.ring(charge,Vector3.UP*0.26,0.346,0.015,ESSENCE,12)
	k.ellipsoid(vessel,Vector3.UP*1.47,Vector3(0.71,0.32,0.71),"8b7765",12,4)
	for y in [0.71,1.42]:
		k.ring(vessel,Vector3.UP*y,0.345,0.042,BRASS,16)
	for i in 4:
		var r := _dir(i,4)
		k.rod(vessel,r*0.35+Vector3.UP*0.73,r*0.35+Vector3.UP*1.41,0.029,BRONZE,8)
	k.frustum(vessel,Vector3.UP*1.61,0.16,0.118,0.16,PATINA,10)
	k.tube(k.root,[tank+Vector3.UP*1.64,Vector3(-0.09,1.92,-0.16),Vector3(0.20,2.02,-0.17),Vector3(0.45,1.90,-0.11),Vector3(0.47,1.48,-0.06)],0.061,BRASS,8)
	var pump := Vector3(0.43,0,-0.04)
	k.frustum(k.root,pump+Vector3.UP*0.68,0.54,0.144,0.119,DEEP,10)
	var piston: Node3D = k.group(k.root,pump+Vector3.UP*0.88)
	k.motion(piston,"slide",Vector3.UP,0.080)
	k.frustum(piston,Vector3.UP*0.17,0.44,0.078,0.078,"99b0aa",10)
	k.ring(piston,Vector3.UP*0.30,0.113,0.027,BRASS,10)
	k.frustum(k.root,pump+Vector3.UP*1.39,0.23,0.127,0.13,PATINA,10)
	# Mechanical dial with a working needle on the tank shoulder.
	var dial: Node3D = k.group(k.root,Vector3(0.0,1.48,0.255))
	dial.rotation.y = 0.34
	var housing: Node3D = k.frustum(dial,Vector3.ZERO,0.09,0.165,0.165,BRASS,14)
	housing.rotation.x=PI*0.5
	var face: Node3D = k.frustum(dial,Vector3(0,0,0.054),0.015,0.135,0.135,"b7c8ac",14)
	face.rotation.x=PI*0.5
	var needle: Node3D = k.group(dial,Vector3(0,0,0.071))
	k.motion(needle,"swing",Vector3.BACK,0.32,0.15)
	k.rod(needle,Vector3.ZERO,Vector3(-0.052,0.083,0.0),0.012,ROOT,6)
	for i in 3:
		var r := _dir(i,3,0.15)
		k.leaf(k.root,Vector3.UP*0.52+r*0.26,Vector3.UP*0.78+r*0.53,0.18,0.13,JADE,PATINA)
