extends SceneTree
const IDS := ["sheet_sand", "sheet_grass", "sheet_burnt", "sheet_river", "sheet_riverbed", "sheet_oasis"]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/terrain")
	for id: String in IDS:
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
				st.add_vertex(faces[face][index])
			st.set_material(top if face == 0 else (bottom if face == 5 else side))
			st.commit(mesh)
		ResourceSaver.save(mesh, "res://assets/models/terrain/" + id + ".tres")
		var node := MeshInstance3D.new()
		node.name = id
		node.mesh = mesh
		var scene := PackedScene.new()
		scene.pack(node)
		ResourceSaver.save(scene, "res://assets/models/terrain/" + id + ".tscn")
		node.free()
	print("SIX TERRAIN MODELS CREATED")
	quit()

func _material(id: String, kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = id + "_" + kind
	var image := Image.new()
	image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/terrain/" + id + "_" + kind + ".svg"))
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.95
	material.metallic_specular = 0.1
	return material
