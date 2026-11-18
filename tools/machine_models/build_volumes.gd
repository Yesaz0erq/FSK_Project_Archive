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
var _paint := ShaderMaterial.new()

func _initialize() -> void:
	_paint.shader = Runtime.PAINT
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
		triangles.set_material(_paint)
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
	color.a = 1.0 if paint.get_shader_parameter("luminous") else 0.0
	var normal_xf := xf.basis.inverse().transposed()
	for surface in part.mesh.get_surface_count():
		var arrays := part.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for i in (points.size() if indices.is_empty() else indices.size()):
			var vertex := i if indices.is_empty() else indices[i]
			triangles.set_color(color)
			triangles.set_normal((normal_xf * normals[vertex]).normalized())
			triangles.add_vertex(xf * points[vertex])
