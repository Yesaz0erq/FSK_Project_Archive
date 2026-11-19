extends SceneTree
const IDS := ["sheet_sand", "sheet_grass", "sheet_burnt", "sheet_river", "sheet_river_low", "sheet_riverbed", "sheet_oasis"]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/terrain")
	for id: String in IDS:
		if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args(): continue
		var top := _material(id, "top")
		var side := _material(id, "side")
		var bottom := StandardMaterial3D.new()
		bottom.albedo_color = Color.BLACK
		bottom.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bottom.resource_name = id + "_black_bottom"
		var mesh := ArrayMesh.new()
		mesh.resource_name = id + "_six_faces"
		var t: float = 0.765
		var b: float = 0.735
		var h: float = 0.31
		var faces: Array = [
			[Vector3(-t,h,-t),Vector3(t,h,-t),Vector3(t,h,t),Vector3(-t,h,t)],
			[Vector3(-t,h,t),Vector3(t,h,t),Vector3(b,-h,b),Vector3(-b,-h,b)],
			[Vector3(t,h,-t),Vector3(-t,h,-t),Vector3(-b,-h,-b),Vector3(b,-h,-b)],
			[Vector3(t,h,t),Vector3(t,h,-t),Vector3(b,-h,-b),Vector3(b,-h,b)],
			[Vector3(-t,h,-t),Vector3(-t,h,t),Vector3(-b,-h,b),Vector3(-b,-h,-b)],
			[Vector3(-b,-h,b),Vector3(b,-h,b),Vector3(b,-h,-b),Vector3(-b,-h,-b)]
		]
		var normals := [Vector3.UP,Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3.DOWN]
		var uv := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
		for face in range(6):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index in [0,1,2,0,2,3]:
				st.set_normal(normals[face])
				st.set_uv(uv[index])
				if face == 0: st.set_uv2(uv[index])
				st.add_vertex(faces[face][index])
			st.set_material(top if face == 0 else (bottom if face == 5 else side))
			st.commit(mesh)
		ResourceSaver.save(mesh, "res://assets/models/terrain/" + id + ".tres", ResourceSaver.FLAG_CHANGE_PATH)
		var node := MeshInstance3D.new()
		node.name = id
		node.mesh = load("res://assets/models/terrain/" + id + ".tres")
		var scene := PackedScene.new()
		scene.pack(node)
		ResourceSaver.save(scene, "res://assets/models/terrain/" + id + ".tscn")
		node.free()
	print("TERRAIN MODELS CREATED")
	quit()

func _material(id: String, kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = id + "_" + kind
	var extension := "png" if kind == "top" else "svg"
	var texture_id := "sheet_riverbed" if id == "sheet_river_low" and kind == "side" else id
	material.albedo_texture = load("res://assets/terrain/%s_%s.%s" % [texture_id, kind, extension])
	var span := (252.0 if kind == "top" else 124.0) / 512.0
	material.uv1_scale = Vector3(span, span, 1.0)
	material.uv1_offset = Vector3(2.0 / 512.0, 2.0 / 512.0, 0.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = false
	if kind == "top":
		material.detail_enabled = true
		material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		material.detail_albedo = load("res://assets/terrain/parcel_corner.svg")
	material.roughness = 0.66 if id in ["sheet_river", "sheet_river_low", "sheet_oasis"] and kind == "top" else 0.96
	material.metallic_specular = 0.18
	return material
