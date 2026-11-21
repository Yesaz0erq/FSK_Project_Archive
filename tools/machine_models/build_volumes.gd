extends SceneTree
## Run with Godot --headless --path . --script res://tools/machine_models/build_volumes.gd.
## Collapse decorative parts into indexed meshes while retaining every animated
## pivot and its hierarchy. The same source geometry drives the codex turntable.
const Kit := preload("res://tools/machine_models/kit.gd")
const Flora := preload("res://tools/machine_models/flora.gd")
const Growth := preload("res://tools/machine_models/flora_growth.gd")
const Runtime := preload("res://scripts/world/flora_model.gd")
const OUT := "res://assets/models/flora/"

var _scene: Node3D
var _surfaces: Dictionary = {}
var _pivots: Dictionary = {}
# Source sculpt pigments name the subparts; their final albedo is painted on
# the atlas. Keep this lookup explicit so a new part needs an art decision.
const FINISHES := [
	"398669 429373 74a56a aabf58 8ea080",
	"2c5063 574966",
	"dc6e59 dd6659 df6c59 d97e51 ef8f53 f09358 93375b 92365a a74757 9c364a",
	"f9c65e ffca6a ffcf73",
	"88526a 92634e",
	"422d52 795067 826173",
	"ecae5e bd9365 bf915c df9c59",
	"a25a47 8b7765",
	"369e99 427a70 56b5aa 60bfb0 97cda2 a1d59d",
	"256673 25665f",
	"36a7a0 39656b 65bcaa 67c5c4",
	"85f1d6 a3ecc3",
	"272e4e 574757 664c62",
	"649364 779d75 628f81",
	"99b0aa", "b7c8ac"
]
const SHEEN := [0.05,0.04,0.055,0.11,0.015,0.012,0.26,0.20,0.095,0.07,0.18,0.15,0.05,0.04,0.25,0.05]
var _swatches: Dictionary = {}

func _initialize() -> void:
	for swatch in FINISHES.size():
		for code in FINISHES[swatch].split(" "): _swatches[code] = swatch
	DirAccess.make_dir_recursive_absolute(OUT)
	for id: String in ["propagator", "collector", "extractor", "phase1", "phase2_1", "phase2_2", "phase3_1", "phase3_2"]:
		if not _build(id):
			quit(1)
			return
	quit()

func _build(id: String) -> bool:
	var kit := Kit.new()
	if id.begins_with("phase"): Growth.build(id, kit)
	else: Flora.build(id, kit)
	_scene = Runtime.new()
	_scene.name = id
	for joint in kit._joints: _pivots[joint.node] = joint
	_collect(kit.root, _scene, Transform3D.IDENTITY)
	for pivot: Node3D in _surfaces:
		var triangles: SurfaceTool = _surfaces[pivot]
		triangles.index()
		triangles.set_material(Runtime.PAINT)
		var geometry := MeshInstance3D.new()
		geometry.name = "Enamel"
		geometry.mesh = triangles.commit()
		pivot.add_child(geometry)
		geometry.owner = _scene
	var packed := PackedScene.new()
	var ok := packed.pack(_scene) == OK and ResourceSaver.save(packed, OUT + id + ".scn", ResourceSaver.FLAG_COMPRESS) == OK
	print("Volume ", id, ", rigid meshes ", _surfaces.size())
	_scene.free()
	kit.root.free()
	_pivots.clear()
	_surfaces.clear()
	return ok

func _collect(source: Node3D, pivot: Node3D, relative: Transform3D) -> void:
	var xf := relative * source.transform
	if _pivots.has(source):
		var joint: Dictionary = _pivots[source]
		var child := Node3D.new()
		child.name = "Pivot"
		child.transform = xf
		pivot.add_child(child, true)
		child.owner = _scene
		child.set_meta("motion", joint.kind)
		for key: String in ["axis", "amount", "offset"]: child.set_meta(key, joint[key])
		pivot = child
		xf = Transform3D.IDENTITY
	if source is MeshInstance3D:
		if not _surfaces.has(pivot):
			var triangles := SurfaceTool.new()
			triangles.begin(Mesh.PRIMITIVE_TRIANGLES)
			_surfaces[pivot] = triangles
		_append_part(source, xf, _surfaces[pivot])
	for child: Node3D in source.get_children():
		_collect(child, pivot, xf)

func _append_part(part: MeshInstance3D, xf: Transform3D, triangles: SurfaceTool) -> void:
	var paint: ShaderMaterial = part.material_override
	var color: Color = paint.get_shader_parameter("pigment")
	var code := color.to_html(false)
	assert(_swatches.has(code), "Missing painted finish for " + code)
	var swatch: int = _swatches[code]
	var origin := Vector2(swatch % 4, floori(swatch / 4.0)) * 32.0
	var response := Vector2(SHEEN[swatch], 1.0 if paint.get_shader_parameter("luminous") else 0.0)
	var normal_xf := xf.basis.inverse().transposed()
	for surface in part.mesh.get_surface_count():
		var arrays := part.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for i in (points.size() if indices.is_empty() else indices.size()):
			var vertex := i if indices.is_empty() else indices[i]
			var uv := Vector2(.5,.5) if uvs.is_empty() else uvs[vertex]
			if part.mesh is CylinderMesh:
				var cylinder: CylinderMesh = part.mesh
				if absf(normals[vertex].y) > .999:
					var radius := cylinder.top_radius if normals[vertex].y > 0 else cylinder.bottom_radius
					uv = Vector2(.5,.5) + Vector2(points[vertex].x,points[vertex].z) / maxf(2.*radius,.0001)
				else:
					uv.y = .5 - points[vertex].y / cylinder.height
			triangles.set_uv((origin + Vector2(2.5,2.5) + uv.clamp(Vector2.ZERO, Vector2.ONE) * 27.0) / 128.0)
			triangles.set_uv2(response)
			triangles.set_normal((normal_xf * normals[vertex]).normalized())
			triangles.add_vertex(xf * points[vertex])
