extends Node3D
## Heightfield around the playable parcels. A narrow deformable margin carries
## each border parcel's actual top coordinates into the continuous valley.
signal margin_rebuilt

const Surface := preload("res://assets/models/terrain/terrain_surface.gd")
const GroundShader := preload("res://assets/shaders/district_ground.gdshader")
const TILE := 1.6
const EDGE := 8.8
const COLLAR := 12.0
const TIDE_BLEND_SECONDS := Land.TIDE_ROW_SECONDS * 0.56
const LAST := 10
const IDS := ["sheet_sand", "sheet_grass", "sheet_burnt", "sheet_river", "sheet_riverbed", "sheet_oasis", "sheet_river_low"]
const DELTAS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
const OUTWARD := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
var biome: String
var _seed: int
var _district: int
var _phase: float
var crossing_z: float
var _horizontal: bool
var _bend_rate: float
var _bend_size: float
var _levels := PackedFloat32Array()
var _level_from := PackedFloat32Array()
var _level_target := PackedFloat32Array()
var _level_time := 0.0
var _widths := Vector2i.ZERO
var _relief := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _axis := PackedFloat32Array()
var _mouths: Array[Vector2] = []
var _borders := {}
var _mat: ShaderMaterial
var _lip := MeshInstance3D.new()
var _refresh_pending := false
static var _valleys: Dictionary = {}
static var _district_materials: Dictionary = {}
static var _cached_seed: int = -1

func build(biome_id: String, seed_value: int) -> void:
	biome = biome_id
	_seed = seed_value
	_district = Surface.BIOME_ROWS.find(biome)
	_phase = posmod(hash([_seed, biome]), 809) * 0.047
	_relief.seed = hash([biome, _seed])
	_relief.frequency = 0.056
	_relief.fractal_octaves = 3
	_detail.seed = _relief.seed + 47
	_detail.frequency = 0.17
	_detail.fractal_octaves = 2
	if not _district_materials.has(biome):
		var paint := ShaderMaterial.new()
		paint.shader = GroundShader
		paint.set_shader_parameter("district", _district)
		for i in IDS.size():
			paint.set_shader_parameter("paint_%d" % i, load("res://assets/terrain/%s_top.png" % IDS[i]))
		_district_materials[biome] = paint
	_mat = _district_materials[biome].duplicate()
	for y in 11:
		for x in 11:
			if x == 0 or y == 0 or x == LAST or y == LAST:
				_read_border(Vector2i(x, y))
	var mouths: Array = Land.river_mouths[biome]
	_horizontal = int(mouths[0].edge) == 0
	rotation.y = PI * 0.5 if _horizontal else 0.0
	for mouth: Dictionary in mouths:
		var span := Vector2((int(mouth.first) - 5.5) * TILE, (int(mouth.last) - 4.5) * TILE)
		_mouths.append(Vector2(-span.y, -span.x) if _horizontal else span)
	_widths = Vector2i(roundi((_mouths[0].y - _mouths[0].x) / TILE), roundi((_mouths[1].y - _mouths[1].x) / TILE))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, biome, "watershed"])
	_bend_rate = rng.randf_range(0.10, 0.21)
	_bend_size = rng.randf_range(2.0, 4.4)
	crossing_z = (EDGE + rng.randf_range(4.5, 7.0)) * (-1.0 if rng.randf() < 0.5 else 1.0)
	_update_levels(true)
	# Bilaterally symmetric spacing gives the border real half-tile resolution
	# and keeps distant triangles large enough to avoid unnecessary geometry.
	var positive := PackedFloat32Array()
	for i in range(1, 32): positive.append(i * 0.8)
	for i in range(17, 32): positive.append(i * 1.6)
	for i in range(17, 41): positive.append(i * 3.2)
	for i in range(positive.size() - 1, -1, -1): _axis.append(-positive[i])
	_axis.append(0.0)
	_axis.append_array(positive)
	var outer := MeshInstance3D.new()
	outer.name = "Valley"
	if _seed != _cached_seed:
		_valleys.clear()
		_cached_seed = _seed
	var route_key := [biome, _horizontal, _mouths[0], _mouths[1]]
	if not _valleys.has(route_key): _valleys[route_key] = _build_surface(false)
	outer.mesh = _valleys[route_key]
	outer.material_override = _mat
	add_child(outer)
	_lip.name = "ParcelMargins"
	_lip.mesh = _build_surface(true)
	_lip.material_override = _mat
	add_child(_lip)
	# Exposed in the moment a parcel is lifted or rotated.
	var soil := BoxMesh.new()
	soil.size = Vector3(2.0 * EDGE + 1.0, 1.2, 2.0 * EDGE + 1.0)
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Data.palette(biome, "cliff").lightened(0.045)
	soil.material = soil_mat
	var earth := MeshInstance3D.new()
	earth.name = "Subsoil"
	earth.mesh = soil
	earth.position.y = -1.29
	add_child(earth)

func _read_border(cell: Vector2i) -> void:
	var p := Land.get_parcel(biome, cell)
	var id: String = p.land
	_borders[cell] = {"height": float(p.height), "kind": IDS.find(id)}

func river_span_at(z: float) -> Vector2:
	var mouth := _mouths[0 if z < 0.0 else 1]
	var d := maxf(0.0, absf(z) - EDGE)
	var angle := _phase if z < 0.0 else _phase + 2.4
	var center := 0.5 * (mouth.x + mouth.y)
	center += (sin(d * _bend_rate + angle) * _bend_size + sin(d * 0.058 + angle) * 4.1) * smoothstep(0.0, 9.0, d)
	var width := (mouth.y - mouth.x) * 0.5 + (1.15 + 0.75 * sin(d * 0.18 + angle)) * smoothstep(0.0, 10.0, d)
	width += 2.8 * smoothstep(20.0, 34.0, d) * (1.0 - smoothstep(34.0, 46.0, d))
	return Vector2(center - width, center + width)

func _source_x(x: float, z: float, reverse: bool) -> float:
	if absf(z) <= EDGE: return x
	var inner := _mouths[0 if z < 0 else 1]
	var outer := river_span_at(z)
	var a := outer if reverse else inner
	var b := inner if reverse else outer
	return lerpf(b.x, b.y, inverse_lerp(a.x, a.y, x)) if x > a.x and x < a.y else (x - a.x + b.x if x <= a.x else x - a.y + b.y)

func _world_point(x: float, z: float) -> Vector2:
	return Vector2(z, -x) if _horizontal else Vector2(x, z)

func _river_point(x: float, z: float) -> Vector2:
	return Vector2(-z, x) if _horizontal else Vector2(x, z)

func _owner(x: float, z: float) -> Vector2i:
	var p := _world_point(x,z) / TILE + Vector2(5.5,5.5)
	return Vector2i(floori(p.x), floori(p.y)).clamp(Vector2i.ZERO, Vector2i(LAST,LAST))

func _update_levels(initial := false) -> void:
	# Sample each mouth parcel independently so exposed bars continue across
	# the boundary on the same side as their source parcel.
	var target := PackedFloat32Array()
	target.resize(22)
	for arm in 2:
		var z := -EDGE if arm == 0 else EDGE
		for i in _widths[arm]:
			var x := _mouths[arm].x + (i + 0.5) * TILE
			var kind := int(_borders[_owner(x,z)].kind)
			target[11*arm+i] = 1.0 if kind == 3 else (0.5 if kind == 6 else 0.0)
	if initial:
		_levels = target.duplicate()
		_level_target = target
		_mat.set_shader_parameter("river_levels", _levels)
		_mat.set_shader_parameter("mouth_widths", _widths)
		set_process(false)
	elif target != _level_target:
		# Start at the visible surface even if the next row arrives mid-blend.
		_level_from = _levels.duplicate()
		_level_target = target
		_level_time = 0.0
		set_process(true)

func _process(delta: float) -> void:
	if Sim.paused: return
	_level_time += delta * (Sim.time_scale if Land.tide_state.is_empty() else 1.0)
	var t := smoothstep(0.0,TIDE_BLEND_SECONDS,_level_time)
	for i in _levels.size():
		_levels[i] = lerpf(_level_from[i],_level_target[i],t)
	_mat.set_shader_parameter("river_levels", _levels)
	if _level_time >= TIDE_BLEND_SECONDS: set_process(false)

func _reach(ox: float, z: float) -> float:
	if absf(z) < EDGE - 0.001: return 0.0
	var mouth := _mouths[0 if z < 0.0 else 1]
	return signf(z) * (3.0 + clampf(inverse_lerp(mouth.x,mouth.y,ox), -1.0, 2.0))

func _level(reach: float) -> float:
	var arm := 0 if reach < 0.0 else 1
	var lane := clampf((absf(reach) - 3.0) * _widths[arm] - 0.5, 0.0, _widths[arm] - 1.0)
	return lerpf(_levels[arm*11 + floori(lane)], _levels[arm*11 + ceili(lane)], fposmod(lane,1.0))

func _water_height(z: float) -> float:
	return -0.15 - maxf(0.0, absf(z) - EDGE) * 0.011

func _channel_distance(x: float, z: float) -> float:
	if absf(z) < EDGE - 0.01: return 1000.0
	var span_at := river_span_at(z)
	return maxf(span_at.x - x, x - span_at.y)

func _natural_height(x: float, z: float) -> float:
	var radial := maxf(absf(x), absf(z))
	var outside := maxf(0.0, radial - EDGE)
	var grain := _detail.get_noise_2d(x, z)
	var ridge := _relief.get_noise_2d(x, z)
	var apron := smoothstep(0.0, 10.0, outside)
	var highland := smoothstep(12.0, 34.0, outside)
	var hills: float
	match _district:
		1: # Leeward dune crests and eroded sandstone benches.
			var sweep := 0.5 + 0.5 * sin(x * 0.29 + z * 0.12 + ridge * 3.3)
			hills = pow(sweep, 2.6) * (1.35 + 3.2 * highland) + highland * maxf(0.0, ridge + 0.02) * 13.0
		2: # Tilted folded basalt, cut by the cooler river channel.
			var rib := 1.0 - absf(sin(x * 0.18 - z * 0.20 + ridge * 2.9))
			hills = (rib * rib * 1.5 + (ridge + 0.40) * 2.1) + highland * (maxf(0.0, ridge + 0.23) * 15.0 + rib * 3.1)
		3: # Interlocking glacial spurs rise out of the moraine.
			var spur := 1.0 - absf(_relief.get_noise_2d(x * 0.81 + z * 0.33, z * 1.20)) * 1.65
			hills = (ridge + 0.35) * 1.75 + highland * (pow(maxf(spur, 0.0), 3.3) * 7.4 + maxf(0.0, ridge + 0.22) * 6.0)
		_: # Low alluvial meadow between irregular wooded terraces.
			hills = (ridge + 0.42) * (1.6 + 7.5 * highland) + highland * maxf(0.0, grain + 0.2) * 2.8
	var rise := apron * (hills + grain * (0.25 + 0.45 * highland))
	var bank := _channel_distance(x, z)
	if bank > 90: return rise
	return lerpf(_water_height(z), maxf(_water_height(z) + 0.28, rise), smoothstep(0.0, 2.5 + highland * 3.5, bank))

func _height(ox: float, z: float, border: Dictionary) -> float:
	var y := _natural_height(_source_x(ox, z, false), z)
	if border.is_empty(): return y
	var dist := maxf(absf(ox), absf(z)) - EDGE
	return lerpf(float(border.height), y, smoothstep(0.0, 1.5, dist))

func _visible_height(ox: float, z: float, owner: Dictionary) -> float:
	var h := _height(ox,z,owner)
	var reach := _reach(ox,z)
	if reach == 0.0: return h
	var u := absf(reach) - 3.0
	var bank := 1.0 - smoothstep(0.0, 0.5, maxf(-u,u-1.0))
	var level := _level(reach)
	var drop := lerpf(-0.14,-0.08,level*2.0) if level < 0.5 else lerpf(-0.08,0.0,level*2.0-1.0)
	return h + drop * bank * smoothstep(0.0,1.5,absf(z)-EDGE)

func height_at(x: float, z: float) -> float:
	var p := _river_point(x,z)
	return height_in_river_frame(p.x,p.y)

func height_in_river_frame(x: float, z: float) -> float:
	var ox := _source_x(x, z, true)
	if maxf(absf(ox), absf(z)) < EDGE:
		return float(Land.get_parcel(biome, _owner(ox,z)).height)
	# Anchor scenery to the triangle planes actually submitted to the renderer.
	var ix := clampi(_axis.bsearch(ox) - 1, 0, _axis.size() - 2)
	var iz := clampi(_axis.bsearch(z) - 1, 0, _axis.size() - 2)
	var x0 := _axis[ix]
	var x1 := _axis[ix+1]
	var z0 := _axis[iz]
	var z1 := _axis[iz+1]
	var mid_x := (x0 + x1) * 0.5
	var mid_z := (z0 + z1) * 0.5
	var owner: Dictionary = _borders.get(_owner(mid_x, mid_z), {}) if maxf(absf(mid_x), absf(mid_z)) < COLLAR else {}
	var v := inverse_lerp(z0, z1, z)
	var left := lerpf(_source_x(x0,z0,false), _source_x(x0,z1,false), v)
	var right := lerpf(_source_x(x1,z0,false), _source_x(x1,z1,false), v)
	var diagonal := lerpf(_source_x(x0,z0,false), _source_x(x1,z1,false), v)
	var y0 := _visible_height(x0,z0,owner)
	var y2 := _visible_height(x1,z1,owner)
	var yd := lerpf(y0,y2,v)
	if x >= diagonal:
		var yr := lerpf(_visible_height(x1,z0,owner),y2,v)
		return lerpf(yd, yr, clampf((x - diagonal) / maxf(right - diagonal, 0.0001), 0.0, 1.0))
	var yl := lerpf(y0,_visible_height(x0,z1,owner),v)
	return lerpf(yl, yd, clampf((x - left) / maxf(diagonal - left, 0.0001), 0.0, 1.0))

func is_channel_at(x: float, z: float) -> bool:
	var p := _river_point(x,z)
	if _channel_distance(p.x,p.y) <= 0.0: return true
	var ox := _source_x(p.x,p.y,true)
	return maxf(absf(ox),absf(p.y)) <= EDGE + 1.5 and int(_borders.get(_owner(ox,p.y), {}).get("kind",-1)) in [3,4,5,6]

func is_crossing_at(x: float, z: float) -> bool:
	var p := _river_point(x,z)
	if absf(p.y - crossing_z) > 1.75: return false
	var span_at := river_span_at(crossing_z)
	return p.x > span_at.x - 2.0 and p.x < span_at.y + 2.0

func is_water_at(x: float, z: float) -> bool:
	var p := _river_point(x,z)
	var ox := _source_x(p.x,p.y,true)
	var dist := maxf(absf(ox),absf(p.y)) - EDGE
	if dist < 0.0:
		return Land.get_parcel(biome, _owner(ox,p.y)).land in ["sheet_river", "sheet_oasis", "sheet_river_low"]
	if dist < 1.5: return int(_borders[_owner(ox,p.y)].kind) in [3,5,6]
	if _channel_distance(p.x,p.y) > 0.0: return false
	return _level(_reach(ox,p.y)) > 0.21

func refresh_boundary(cell: Vector2i) -> void:
	if not _borders.has(cell): return
	_read_border(cell)
	if not _refresh_pending:
		_refresh_pending = true
		_rebuild_margin.call_deferred()

func _rebuild_margin() -> void:
	if not _refresh_pending: return
	_refresh_pending = false
	_update_levels()
	_lip.mesh = _build_surface(true)
	margin_rebuilt.emit()

func settle_wave() -> void:
	if _refresh_pending: _rebuild_margin()
	if is_processing(): _update_levels(true)

func _build_surface(margin: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := _axis.bsearch(-COLLAR) if margin else 0
	var high := _axis.bsearch(COLLAR) if margin else _axis.size()-1
	var points: Dictionary = {}
	for iz in range(low, high):
		for ix in range(low, high):
			var mid := Vector2(_axis[ix]+_axis[ix+1], _axis[iz]+_axis[iz+1]) * 0.5
			var radius := maxf(absf(mid.x), absf(mid.y))
			if radius < EDGE or (radius < COLLAR) != margin: continue
			var site := _owner(mid.x,mid.y)
			var info: Dictionary = _borders[site] if margin else {}
			var kind := int(info.kind) if margin else -1
			var paint_cell := site
			var uv_rect := Rect2()
			if margin:
				if kind != 5:
					# Continue the print onto virtual cells outside the fence.
					paint_cell = Vector2i((_world_point(mid.x,mid.y) / TILE + Vector2(5.5,5.5)).floor())
				uv_rect = Surface.atlas_rect(IDS[kind], _district, paint_cell, _seed)
			var vertices := PackedVector3Array()
			var uvs := PackedVector2Array()
			var attrs := PackedVector2Array()
			for d: Vector2i in DELTAS:
				var key := Vector2i(ix,iz)+d
				var ox := _axis[key.x]
				var z := _axis[key.y]
				attrs.append(Vector2(kind, _reach(ox,z) if absf(mid.y) >= EDGE else 0.0))
				if margin:
					var point := Vector3(_source_x(ox,z,false), _height(ox,z,info), z)
					# Parcel tops are bevelled: close the 0.005-unit lip between
					# their actual edges and the nominal 1.6-unit lattice.
					if maxf(absf(ox),absf(z)) < EDGE + 0.001:
						if absf(ox) > EDGE - 0.001: point.x -= signf(ox) * 0.0051
						if absf(z) > EDGE - 0.001: point.z -= signf(z) * 0.0051
					vertices.append(point)
					var local := _world_point(ox,z) / TILE + Vector2(5.5,5.5) - Vector2(paint_cell)
					uvs.append(uv_rect.position + uv_rect.size * local.clamp(Vector2.ZERO,Vector2.ONE))
				else:
					if not points.has(key):
						var x := _source_x(ox,z,false)
						points[key] = Vector3(x,_natural_height(x,z),z)
					vertices.append(points[key])
					uvs.append(Vector2.ZERO)
			_tri(st, vertices, uvs, attrs, 0, 1, 2)
			_tri(st, vertices, uvs, attrs, 0, 2, 3)
			if margin and radius < EDGE + 1.5:
				# Neighboring tiles can differ in altitude (river, drained bed, or
				# oasis). Seal the short longitudinal walls until their banks meet.
				for j in 4:
					var a := vertices[j]
					var b := vertices[(j+1)%4]
					var near_tile := Vector2(_axis[ix+DELTAS[j].x], _axis[iz+DELTAS[j].y])
					var next_tile := Vector2(_axis[ix+DELTAS[(j+1)%4].x], _axis[iz+DELTAS[(j+1)%4].y])
					var neighbor_point: Vector2 = (near_tile + next_tile) * 0.5 + 0.015 * OUTWARD[j]
					var foot_a := a
					var foot_b := b
					if maxf(absf(neighbor_point.x), absf(neighbor_point.y)) < EDGE:
						# The playable tile can lift above its substrate.
						foot_a.y = -0.70
						foot_b.y = -0.70
					else:
						var neighbor: Dictionary = _borders[_owner(neighbor_point.x, neighbor_point.y)]
						if float(neighbor.height) >= float(info.height): continue
						foot_a.y = _height(near_tile.x, near_tile.y, neighbor)
						foot_b.y = _height(next_tile.x, next_tile.y, neighbor)
						if maxf(a.y - foot_a.y, b.y - foot_b.y) < 0.0001: continue
					# Only the high bank supplies the outward-facing wall.
					var wall := PackedVector3Array([a,b,foot_b,foot_a])
					var wall_uv := PackedVector2Array([uvs[j],uvs[(j+1)%4],uvs[(j+1)%4],uvs[j]])
					var wall_attrs := PackedVector2Array([attrs[j],attrs[(j+1)%4],attrs[(j+1)%4],attrs[j]])
					if b.y - foot_b.y > 0.0001: _tri(st,wall,wall_uv,wall_attrs,0,2,1)
					if a.y - foot_a.y > 0.0001: _tri(st,wall,wall_uv,wall_attrs,0,3,2)
	st.set_material(_district_materials[biome])
	return st.commit()

func _tri(st: SurfaceTool, vertices: PackedVector3Array, uvs: PackedVector2Array, attrs: PackedVector2Array, a: int, b: int, c: int) -> void:
	var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a]).normalized()
	st.set_normal(normal)
	for index: int in [a,b,c]:
		st.set_uv2(attrs[index])
		st.set_uv(uvs[index])
		st.add_vertex(vertices[index])
