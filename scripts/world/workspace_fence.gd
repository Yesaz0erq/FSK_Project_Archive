extends MeshInstance3D
## One opaque mesh for the rails, posts and fittings around the planting area.

const TILE := 1.6
const FIELD_EDGE := TILE * Land.GRID * 0.5
const RAIL_EDGE := FIELD_EDGE + 0.34
const PROFILE := [
	Vector2(-0.67,-1), Vector2(0.67,-1), Vector2(1,-0.67), Vector2(1,0.67),
	Vector2(0.67,1), Vector2(-0.67,1), Vector2(-1,0.67), Vector2(-1,-0.67)
]
# Post, rail, metalwork and cap respectively.
const PALETTES := {
	"forest": ["604a44", "ac835b", "668f85", "d3ae75"],
	"desert": ["a77169", "c4a07b", "487a7d", "eac794"],
	"volcano": ["4b4256", "7d6975", "aa7962", "c68b68"],
	"snow": ["676570", "978789", "58788b", "d6e6e3"],
}
var _biome: String
var _land: Node3D
var _openings: Array
var _posts := {}
var _surface: SurfaceTool
var _wood: Color
var _rail: Color
var _band: Color
var _cap: Color

func build(biome: String, terrain: Node3D) -> void:
	_biome = biome
	_land = terrain
	_openings = Land.river_mouths[biome]
	var colors: Array = PALETTES[biome]
	_wood = Color(colors[0])
	_rail = Color(colors[1])
	_band = Color(colors[2])
	_cap = Color(colors[3])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	material_override = mat
	_remesh()
	_land.margin_rebuilt.connect(_remesh)

func _remesh() -> void:
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_posts.clear()
	for edge in 4:
		var first := 0
		for col in range(Land.GRID+1):
			if col < Land.GRID and not _is_outlet(edge, col): continue
			if col > first: _run(edge, first, col)
			first = col+1
	_surface.index()
	mesh = _surface.commit()
	_surface = null

func _is_outlet(edge: int, col: int) -> bool:
	for mouth: Dictionary in _openings:
		if mouth.edge == edge and col >= int(mouth.first) and col <= int(mouth.last): return true
	return false

func _run(edge: int, first: int, limit: int) -> void:
	# The end post sits on dry ground even when the whole riverbed is exposed.
	var left := -RAIL_EDGE if first == 0 else -FIELD_EDGE + first*TILE + 0.24
	var right := RAIL_EDGE if limit == Land.GRID else -FIELD_EDGE + limit*TILE - 0.24
	var count := ceili((right-left)/3.25)
	var prev := Vector3.ZERO
	for i in range(count+1):
		var t := lerpf(left, right, float(i)/count)
		var side := -RAIL_EDGE if edge in [0,2] else RAIL_EDGE
		var p := Vector3(side, 0, t) if edge < 2 else Vector3(t, 0, side)
		p.y = _land.height_at(p.x,p.z)
		var end := i == 0 or i == count
		var key := Vector2i(roundi(p.x*100),roundi(p.z*100))
		if not _posts.has(key):
			_post(p, end)
			_posts[key] = true
		if i > 0: _span(prev, p, (first+i+edge)%3)
		prev = p

func _post(p: Vector3, end: bool) -> void:
	var radius := 0.145 if end else 0.105
	var h := 0.71 if end else 0.61
	match _biome:
		"desert", "volcano":
			_prism(p, -0.19, 0.14, radius*1.34, radius*1.17, _wood.darkened(0.15))
			_prism(p, 0.14, h-0.11, radius*1.13, radius*0.85, _wood)
		_:
			_prism(p, -0.17, h-0.11, radius*1.06, radius*0.90, _wood)
	_prism(p, h-0.11, h-0.047, radius*1.03, radius*1.03, _band)
	_prism(p, h-0.047, h, radius*1.15, radius*0.88, _cap)
	if end:
		_prism(p, h, h+0.077, radius*0.80, radius*0.48, _cap.lightened(0.06))

func _span(a: Vector3, b: Vector3, variant: int) -> void:
	var pigment := _rail.darkened(variant*0.036)
	if _biome == "desert":
		# Stiff woven straps hang between the cut-stone stanchions.
		for height: float in [0.27, 0.49]:
			var middle := a.lerp(b,0.5) + Vector3.UP*(height-0.085)
			_beam(a+Vector3.UP*height,middle,0.052,0.066,pigment)
			_beam(middle,b+Vector3.UP*height,0.052,0.066,pigment)
		return
	_beam(a+Vector3.UP*0.24,b+Vector3.UP*0.24,0.085,0.088,pigment.darkened(0.15))
	_beam(a+Vector3.UP*0.49,b+Vector3.UP*0.49,0.105,0.115,pigment)
	if _biome == "snow":
		_beam(a+Vector3.UP*0.555,b+Vector3.UP*0.555,0.112,0.025,_cap)
	elif _biome == "volcano" and variant == 0:
		_beam(a+Vector3.UP*0.265,a.lerp(b,0.38)+Vector3.UP*0.47,0.065,0.068,_band)

func _prism(p: Vector3, bottom: float, top: float, r0: float, r1: float, color: Color) -> void:
	var base := p+Vector3.UP*bottom
	var tip := p+Vector3.UP*top
	for i in PROFILE.size():
		var a := Vector3(PROFILE[i].x,0,PROFILE[i].y)
		var b := Vector3(PROFILE[(i+1)%8].x,0,PROFILE[(i+1)%8].y)
		_quad(base+a*r0,base+b*r0,tip+b*r1,tip+a*r1,color)
		_triangle(tip,tip+a*r1,tip+b*r1,Vector3.UP,color)
		_triangle(base,base+b*r0,base+a*r0,Vector3.DOWN,color)

func _beam(a: Vector3, b: Vector3, width: float, height: float, color: Color) -> void:
	var along := (b-a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var top := side.cross(along)*height*0.5
	side *= width*0.5
	_quad(a-side+top,b-side+top,b+side+top,a+side+top,color)
	_quad(a+side-top,b+side-top,b-side-top,a-side-top,color)
	_quad(a-side-top,b-side-top,b-side+top,a-side+top,color)
	_quad(a+side+top,b+side+top,b+side-top,a+side-top,color)
	# End grain is embedded in the post, so the rails need no end faces.

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	_triangle(a,b,c,normal,color)
	_triangle(a,c,d,normal,color)

func _triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	_surface.set_normal(normal)
	_surface.set_color(color)
	_surface.add_vertex(a)
	_surface.add_vertex(b)
	_surface.add_vertex(c)
