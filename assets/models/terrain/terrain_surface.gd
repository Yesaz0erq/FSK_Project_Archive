extends RefCounted

# Tops use a 2x2 district atlas. The independently printed side strata use one
# row per district and four geological variations per row.
const BIOME_ROWS := ["forest", "desert", "volcano", "snow"]
const GUTTER := 2.0 / 512.0
const TOP_SPAN := 252.0 / 512.0
const SIDE_SLOT := 128.0 / 512.0
const SURFACE_FX := preload("res://assets/shaders/parcel_light.gdshader")
const SKY_REFLECTIONS := [Color("96e2d4"), Color("ffd8ad"), Color("ec9ca3"), Color("daefff")]
const EFFECTS := {"sheet_river": 0, "sheet_oasis": 1, "sheet_burnt": 2, "sheet_grass": 3, "sheet_river_low": 4}

# Adjacent cells share the same UV endpoint. The unequal intervals and mirror at
# each end carry sand ridges, moss banks and reflections across tile boundaries.
# Tide flips, selection lifts and the black undersides still move independently.
const PAINT_EDGES := [0.0, 0.18, 0.43, 0.63, 0.83, 1.0, 0.75, 0.45, 0.21,
	0.0, 0.26, 0.51, 0.79, 1.0, 0.72, 0.50, 0.25]

static var _sides: Dictionary = {}
static var _glints: Dictionary = {}
static var _glint_seed := -1

static func _edge(position: int) -> float:
	return PAINT_EDGES[posmod(position, PAINT_EDGES.size())]

static func atlas_rect(id: String, district: int, cell: Vector2i, seed_value: int) -> Rect2:
	var atlas_origin := Vector2(district % 2, floori(district / 2.0)) * 0.5 + Vector2.ONE * GUTTER
	var x := cell.x + posmod(seed_value, PAINT_EDGES.size())
	var y := cell.y + posmod(hash(seed_value), PAINT_EDGES.size())
	var first := Vector2(_edge(x), _edge(y))
	var last := Vector2(_edge(x + 1), _edge(y + 1))
	if id == "sheet_oasis":
		var column := posmod(hash(Vector3i(cell.x, cell.y, seed_value)), 4)
		first = Vector2(column % 2, floori(column / 2.0))
		last = Vector2.ONE - first
	return Rect2(atlas_origin + first * TOP_SPAN, (last - first) * TOP_SPAN)

static func apply(tile: MeshInstance3D, id: String, biome: String, cell: Vector2i) -> StandardMaterial3D:
	var district := maxi(BIOME_ROWS.find(biome), 0)
	var column := posmod(hash(Vector3i(cell.x, cell.y, Land.world_seed)), 4)
	var side_key := "%s/%d/%d" % [id, district, column]
	if not _sides.has(side_key):
		var side: StandardMaterial3D = tile.mesh.surface_get_material(1).duplicate()
		side.uv1_offset = Vector3(column * SIDE_SLOT + GUTTER, district * SIDE_SLOT + GUTTER, 0)
		_sides[side_key] = side
	for face in range(1, 5):
		tile.set_surface_override_material(face, _sides[side_key])

	var rect := atlas_rect(id, district, cell, Land.world_seed)
	var offset := rect.position
	var span := rect.size
	var top: StandardMaterial3D = tile.mesh.surface_get_material(0).duplicate()
	top.uv1_offset = Vector3(offset.x, offset.y, 0)
	top.uv1_scale = Vector3(span.x, span.y, 1)
	if EFFECTS.has(id):
		# Atlas offsets are seed-dependent. Tiles still in a transition hold
		# their own material references until their viewport is freed.
		if _glint_seed != Land.world_seed:
			_glints.clear()
			_glint_seed = Land.world_seed
		var key := "%s/%d" % [id, district]
		if id in ["sheet_grass", "sheet_burnt", "sheet_river_low"]:
			key += "/%s/%s" % [offset, span]
		if not _glints.has(key):
			var glint := ShaderMaterial.new()
			glint.shader = SURFACE_FX
			glint.set_shader_parameter("family", EFFECTS[id])
			glint.set_shader_parameter("reflected_sky", SKY_REFLECTIONS[district])
			glint.set_shader_parameter("paint", top.albedo_texture)
			glint.set_shader_parameter("atlas_corner", offset)
			glint.set_shader_parameter("atlas_span", span)
			_glints[key] = glint
		top.next_pass = _glints[key]
	return top
