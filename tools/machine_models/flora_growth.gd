extends RefCounted
## The first split establishes a seed-bearing or a reinforced body. The latter
## differentiates an open collecting cup or a jointed root and sap reservoir.

const JADE := "548d72"
const DARK_LEAF := "285458"
const MIDRIB := "b6bf72"
const SEED := "f2bd73"

static func _rad(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))

static func _crown(k, parent: Node3D, origin: Vector3, reach: float, rise: float, width: float, n: int, color: String, angle := 0.0) -> void:
	for i in n:
		var dir := _rad(TAU * i / n + angle)
		k.leaf(parent, origin, origin + dir * reach + Vector3.UP * rise, width, reach * 0.37, color if i % 2 == 0 else JADE, DARK_LEAF)

static func build(id: String, k) -> void:
	var parent: Node3D = k.root
	var first := id == "phase1"
	var spread := 0.21 if first else 0.32
	for i in 4:
		var dir := _rad(TAU * i / 4.0 + 0.28)
		k.tube(parent, [Vector3.UP * 0.14, dir * spread * 0.66 + Vector3.UP * 0.09, dir * spread + Vector3.UP * 0.035], 0.041, "92634e", 7)
	k.ellipsoid(parent, Vector3.UP * 0.16, Vector3(0.32,0.27,0.31), "795067", 10, 4)
	_crown(k, parent, Vector3.UP * 0.25, spread * 1.43, -0.02, 0.16 if first else 0.25, 4, "74a56a", 0.23)
	if first:
		k.tube(parent, [Vector3.UP * 0.2,Vector3(-0.038,0.36,0.02), Vector3(0.055,0.53,0)],0.048,"649364",8)
		k.ellipsoid(parent, Vector3(0.055,0.51,0),Vector3(0.18,0.28,0.16),"!efc374",9,4)
		k.leaf(parent,Vector3(0,0.37,0),Vector3(-0.12,0.61,-0.04),0.13,0.07,JADE,DARK_LEAF)
		return
	var shoot := Vector3(0.04,0.65,0.02)
	k.tube(parent, [Vector3.UP * 0.18, Vector3(-0.075,0.43,0), shoot],0.071, JADE,8)
	if id == "phase2_1":
		_crown(k,parent,shoot - Vector3.UP * 0.09,0.32,0.24,0.18,3,"a7ba73",0.65)
		for i in 3:
			var p := shoot + _rad(i*TAU/3.0) * 0.111
			k.ellipsoid(parent,p + Vector3.UP*0.12,Vector3(0.16,0.27,0.17), SEED if i==0 else "cf9067",9,4)
	elif id == "phase2_2":
		for i in 2:
			var dir := _rad(0.45 + PI * i)
			k.tube(parent,[shoot - Vector3.UP*0.13, shoot + dir*0.15, shoot + dir*0.22 + Vector3.UP*0.15],0.045,"779d75",7)
			k.leaf(parent,shoot + dir * 0.15, shoot + dir * 0.38 + Vector3.UP * 0.32,0.22,0.09,JADE,DARK_LEAF)
		k.ellipsoid(parent,shoot,Vector3(0.22,0.32,0.24),"69b19c",9,4)
	elif id == "phase3_1":
		k.frustum(parent,Vector3(0.04,0.74,0.02),0.26,0.23,0.1,"427a70",10)
		k.ellipsoid(parent,Vector3(0.04,0.87,0.02),Vector3(0.25,0.11,0.25),"!ebc58a",9,4)
		_crown(k,parent,Vector3(0.04,0.78,0.02),0.46,0.30,0.25,5,"78b599",0.38)
		k.ring(parent,Vector3(0.04,0.79,0.02),0.19,0.028,"bd9365",10)
	else:
		k.frustum(parent,Vector3(0.0,0.40,0),0.39,0.16,0.20,"826173",10)
		k.ring(parent,Vector3.UP * 0.54,0.17,0.032,"bf915c",10)
		for i in 3:
			var dir := _rad(i*TAU/3.0+0.25)
			k.tube(parent,[shoot,shoot+dir*0.21+Vector3.UP*0.25,shoot+dir*0.32+Vector3.UP*0.56],0.043,"628f81",7)
			k.leaf(parent,shoot+dir*0.12,shoot+dir*0.36+Vector3.UP*0.57,0.17,0.06,"8ea080","574966")
		k.ellipsoid(parent,shoot+Vector3.UP*0.22,Vector3(0.25,0.35,0.25),"!c7878e",9,4)
