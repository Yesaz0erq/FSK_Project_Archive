extends Node3D
## An inhabited 3D landscape around the 11×11 playable plot grid.
## Simulation data lives in Land / Sim; this node only presents it and reports input.

signal hovered(cell: Vector2i)
signal clicked(cell: Vector2i, button: int)
signal context_requested(cell: Vector2i, point: Vector2)

const TILE: float = 1.6
const GRID: int = 11
const VOLUMES := {
	"propagator": preload("res://assets/models/flora/propagator.scn"),
	"collector": preload("res://assets/models/flora/collector.scn"),
	"extractor": preload("res://assets/models/flora/extractor.scn"),
	"phase1": preload("res://assets/models/flora/phase1.scn"),
	"phase2_1": preload("res://assets/models/flora/phase2_1.scn"),
	"phase2_2": preload("res://assets/models/flora/phase2_2.scn"),
	"phase3_1": preload("res://assets/models/flora/phase3_1.scn"),
	"phase3_2": preload("res://assets/models/flora/phase3_2.scn"),
}
const MACHINE_BADGE_HEIGHT := 3.04
const WORK_CYCLES_PER_SECOND := 0.75
const ENTRY_DEPTH := 0.44
const PLAY_ZOOM := 24.5
const SHOWCASE_ZOOM := 28.0
const SceneryScript := preload("res://scripts/world/scenery.gd")
const FocusShader := preload("res://assets/shaders/parcel_focus.gdshader")
const TideCrestShader := preload("res://assets/shaders/tide_crest.gdshader")
const RootShadow := preload("res://assets/models/flora/root_shadow.tres")
const DepositPigments := preload("res://assets/terrain/deposit_pigments.png")
const ORE_SWATCH := {"timber": 0, "resin": 2, "water": 3, "ice": 4, "frost_quartz": 5,
	"salt": 6, "obsidian": 7, "sulfur": 8, "iron_ore": 9, "copper_ore": 10, "sand": 11}
static var _ore_materials: Dictionary = {}
const TerrainSurface := preload("res://assets/models/terrain/terrain_surface.gd")

var biome: String = "forest"
var showcase: bool = false
var showcase_machines: Dictionary = {}
var overlay: String = "none"          # none / fire / water / earth / air / temperature / effects
var build_type: String = ""
var hover_cell := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)

var scenery: Node3D
var camera: Camera3D
var _pivot: Node3D
var _yaw: float = 45.0
var _yaw_target: float = 45.0
var _zoom: float = PLAY_ZOOM
var _zoom_target: float = PLAY_ZOOM
var _pan := Vector3.ZERO
var _camera_pan := Vector3.ZERO
var _dragging: bool = false
var _entry_age: float = 0.0
var _selection_lifts: Dictionary = {}
var _moving_cells: Dictionary = {}
var _tile_heights: Dictionary = {}
var _prop_base_heights: Dictionary = {}
var _recolor_pending := false
var _cell_props: Dictionary = {}
var _tiles: Dictionary = {}          # cell -> MeshInstance3D
var _tide_tweens: Dictionary = {}
static var _terrain_meshes: Dictionary = {}
var _tile_mats: Dictionary = {}      # cell -> StandardMaterial3D
var _grid_root: Node3D
var _effect_root: Node3D
var _effect_anchors: Array[Node3D] = []
var _machine_root: Node3D
var _machine_nodes: Dictionary = {}        # uid -> Dictionary of nodes
var _growth_nodes: Dictionary = {}
var _growth_refresh_left := 0.0
var _hover_frame: Node3D
var _select_frame: Node3D
var _aura_preview: Node3D
var _ghost: Node3D
var _ghost_model: Node3D
var _t: float = 0.0
var _badge_timer: float = 0.0
var _label_font: Font

func setup(biome_id: String, is_showcase: bool = false) -> void:
	biome = biome_id
	showcase = is_showcase
	_zoom = SHOWCASE_ZOOM if showcase else PLAY_ZOOM
	_zoom_target = _zoom
	_label_font = SystemFont.new()
	scenery = SceneryScript.new()
	add_child(scenery)
	scenery.build(biome, Land.world_seed)
	_build_camera()
	_grid_root = Node3D.new()
	add_child(_grid_root)
	_effect_root = Node3D.new()
	add_child(_effect_root)
	_machine_root = Node3D.new()
	add_child(_machine_root)
	_build_tiles()
	_build_effects()
	_hover_frame = _frame(Color("b6fff2"), false)
	_select_frame = _frame(Color("ffdb8d"), true)
	_aura_preview = Node3D.new()
	add_child(_aura_preview)
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)
	refresh_machines()
	refresh_weather()
	Land.parcels_changed.connect(_on_parcels_changed)
	Land.tide_tile_changed.connect(_on_tide_tile)
	Land.tide_tile_transformed.connect(_on_tide_transform)
	Sim.machines_changed.connect(_on_machines_changed)
	Sim.machine_cycled.connect(_on_machine_cycled)
	Sim.growth_changed.connect(func(b: String) -> void: if b == biome: _growth_refresh_left = 0.0)
	Sim.weather_changed.connect(func(b: String) -> void: if b == biome: refresh_weather())

static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - 5) * TILE, 0.0, (cell.y - 5) * TILE)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE + 5.5)), int(floor(p.z / TILE + 5.5)))

# ------------------------------------------------------------------ camera
func _build_camera() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	camera.near = 1.0
	camera.far = 200.0
	_pivot.add_child(camera)
	_apply_camera()
	camera.current = true

func _apply_camera() -> void:
	var pitch: float = deg_to_rad(33.0)
	_pivot.position = _camera_pan
	_pivot.rotation.y = deg_to_rad(_yaw)
	camera.position = Vector3(0, sin(pitch) * 60.0, cos(pitch) * 60.0)
	camera.rotation = Vector3(-pitch, 0, 0)
	camera.size = _zoom

func rotate_view(step: int) -> void:
	_yaw_target += 90.0 * step

func reset_view() -> void:
	_pan = Vector3.ZERO
	_zoom_target = SHOWCASE_ZOOM if showcase else PLAY_ZOOM

func _unhandled_input(event: InputEvent) -> void:
	if showcase or Settings.is_open(): return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _zoom_target = clampf(_zoom_target - 1.5 * Settings.camera_speed, 9.0, 32.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _zoom_target = clampf(_zoom_target + 1.5 * Settings.camera_speed, 9.0, 32.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE: _dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			context_requested.emit(_pick(mb.position), mb.position)
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var c: Vector2i = _pick(mb.position)
			clicked.emit(c, mb.button_index)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging:
			var scale_f: float = _zoom / get_viewport().get_visible_rect().size.y
			var right: Vector3 = _pivot.global_transform.basis.x
			var fwd: Vector3 = Vector3(_pivot.global_transform.basis.z.x, 0, _pivot.global_transform.basis.z.z).normalized()
			_pan -= (right * mm.relative.x + fwd * mm.relative.y * 1.7) * scale_f * Settings.camera_speed
			_pan = _pan.clamp(Vector3(-12, 0, -12), Vector3(12, 0, 12))
		_set_hover(_pick(mm.position))

func _pick(screen: Vector2) -> Vector2i:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001: return Vector2i(-1, -1)
	var nearest: float = INF
	var result := Vector2i(-1, -1)
	for cell: Vector2i in _tiles:
		var tile: MeshInstance3D = _tiles[cell]
		var inverse: Transform3D = tile.global_transform.affine_inverse()
		var hit: Variant = tile.get_aabb().intersects_ray(inverse * origin, inverse.basis * dir)
		if hit is Vector3:
			var distance: float = origin.distance_to(tile.global_transform * hit)
			if distance < nearest:
				nearest = distance
				result = cell
	return result

func _set_hover(c: Vector2i) -> void:
	if c == hover_cell: return
	if Land.in_grid(hover_cell): _moving_cells[hover_cell] = true
	if Land.in_grid(c): _moving_cells[c] = true
	hover_cell = c
	_place_frame(_hover_frame, c)
	_update_ghost()
	hovered.emit(c)

func pan_keys(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO: return
	var right: Vector3 = _pivot.global_transform.basis.x
	var fwd: Vector3 = Vector3(_pivot.global_transform.basis.z.x, 0, _pivot.global_transform.basis.z.z).normalized()
	_pan += (right * dir.x + fwd * dir.y) * delta * _zoom * 0.9 * Settings.camera_speed
	_pan = _pan.clamp(Vector3(-12, 0, -12), Vector3(12, 0, 12))

# ------------------------------------------------------------------ tiles
func _build_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	for y in range(GRID):
		for x in range(GRID):
			var c := Vector2i(x, y)
			var parcel: Dictionary = Land.get_parcel(biome, c)
			var h: float = float(parcel.height)
			_tile_heights[c] = h
			_prop_base_heights[c] = h
			var base: Vector3 = cell_to_world(c)
			var tile := MeshInstance3D.new()
			_set_tile_model(tile, str(parcel.land), c)
			tile.scale = Vector3(1.0392, 1.0, 1.0392)
			tile.position = base + Vector3(0, h - 0.31 - ENTRY_DEPTH, 0)
			_grid_root.add_child(tile)
			_tiles[c] = tile
			rng.seed = int(parcel.variant) + x * 31 + y * 7
			var props := Node3D.new()
			_grid_root.add_child(props)
			_cell_props[c] = props
			props.position.y = -ENTRY_DEPTH
			_decorate(base + Vector3(0, h, 0), parcel, rng, props)
			if str(parcel.deposit) != "":
				_deposit_marker(base + Vector3(0, h, 0), str(parcel.deposit), rng, props)
	_recolor_tiles()

func _decorate(top: Vector3, parcel: Dictionary, rng: RandomNumberGenerator, parent: Node3D) -> void:
	var col: Color = parcel.land_color
	var n: int = rng.randi_range(0, 2)
	for i in range(n):
		var off := Vector3(rng.randf_range(-0.55, 0.55), 0, rng.randf_range(-0.55, 0.55))
		match str(parcel.land):
			"loam", "river_bank":
				MeshKit.cyl(parent, top + off + Vector3(0, 0.1, 0), 0.0, 0.08, 0.22, col.lightened(0.25), 4)
			"moss_bog":
				MeshKit.ball(parent, top + off + Vector3(0, 0.03, 0), Vector3(0.3, 0.1, 0.3), Color("6b8a3a"), 5, 2)
			"old_root":
				MeshKit.cyl(parent, top + off + Vector3(0, 0.05, 0), 0.05, 0.07, 0.6, Color("5c3f27"), 4).rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0)
			"dune", "salt_flat", "sandstone":
				MeshKit.ball(parent, top + off, Vector3(0.14, 0.08, 0.12), col.darkened(0.2), 4, 2)
			"oasis":
				MeshKit.cyl(parent, top + off + Vector3(0, 0.15, 0), 0.0, 0.07, 0.3, Color("7c9a4a"), 4)
			"lava_crust":
				MeshKit.box(parent, Vector3(0.6, 0.02, 0.05), top + off + Vector3(0, 0.005, 0), Color("ff6a2a"), 2.0, false).rotation.y = rng.randf() * PI
			"sulfur_vent":
				MeshKit.ball(parent, top + off, Vector3(0.18, 0.1, 0.18), Color("e0d050"), 5, 2)
			"basalt", "ash_field":
				MeshKit.ball(parent, top + off, Vector3(0.2, 0.12, 0.16), col.lightened(0.15), 4, 2)
			"snowfield", "glacier":
				MeshKit.ball(parent, top + off, Vector3(0.3, 0.12, 0.26), Color("f2f6f8"), 5, 2)
			"permafrost":
				MeshKit.cyl(parent, top + off + Vector3(0, 0.12, 0), 0.0, 0.06, 0.25, Color("bfe3f0"), 4, 0.2)
			"hot_spring":
				MeshKit.ball(parent, top + off, Vector3(0.36, 0.04, 0.36), Color("8ed0e0"), 6, 2, 0.4)

func _deposit_marker(top: Vector3, resource: String, rng: RandomNumberGenerator, parent: Node3D) -> void:
	var paint := int(ORE_SWATCH.get(resource, 11))
	var cluster := Node3D.new()
	cluster.name = "Deposit_" + resource
	cluster.position = top
	cluster.rotation.y = rng.randf() * TAU
	parent.add_child(cluster)
	for i in 3:
		var angle := TAU * i / 3.0
		var off := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.09, 0.27)
		var h := rng.randf_range(0.14, 0.38)
		var piece: MeshInstance3D
		match resource:
			"timber":
				piece = MeshKit.cyl(cluster, off + Vector3.UP * 0.10, 0.088, 0.095, 0.42, Color.WHITE, 7)
				piece.rotation = Vector3(PI / 2, i * 0.21, 0.0)
				var end := MeshKit.cyl(piece, Vector3.UP * .211, .076, .076, .008, Color.WHITE, 7)
				end.material_override = _ore_material(1)
			"ice", "frost_quartz", "salt", "obsidian", "sulfur":
				piece = MeshKit.cyl(cluster, off + Vector3.UP * h * 0.48, 0.094, 0.12, h, Color.WHITE, 5)
				piece.rotation = Vector3(cos(angle) * 0.24, angle, sin(angle) * 0.24)
				var tip := MeshKit.cyl(piece, Vector3.UP * (h * .5 + .062), 0, .094, .125, Color.WHITE, 5)
				tip.material_override = _ore_material(paint)
			"water":
				piece = MeshKit.ball(cluster, off + Vector3.UP * .058, Vector3(.32,.14,.29), Color.WHITE, 7, 3)
			"iron_ore", "copper_ore":
				piece = MeshKit.ball(cluster, off + Vector3.UP * .09, Vector3(.37,.31,.29), Color.WHITE, 5, 3)
				piece.rotation.y = angle
			_:
				piece = MeshKit.ball(cluster, off + Vector3.UP * h * .22, Vector3(.22,h * .78,.23), Color.WHITE, 6, 3)
		piece.material_override = _ore_material(paint)

func _ore_material(slot: int) -> StandardMaterial3D:
	if not _ore_materials.has(slot):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = DepositPigments
		mat.uv1_scale = Vector3(23.0/128., 23.0/128., 1)
		mat.uv1_offset = Vector3((32*(slot%4) + 4.5)/128., (32*floori(slot/4.) + 4.5)/128., 0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.roughness = .58 if slot in [2, 3, 4, 5, 7] else .92
		mat.metallic_specular = .21
		_ore_materials[slot] = mat
	return _ore_materials[slot]

func set_overlay(mode: String) -> void:
	overlay = mode
	_recolor_tiles()
	for ch in _effect_root.get_children():
		if ch.has_meta("overlay_only"): ch.visible = mode == "effects"

func _recolor_tiles() -> void:
	_recolor_pending = false
	for c: Vector2i in _tiles:
		_recolor_tile(c)

func _recolor_tile(c: Vector2i) -> void:
	if _tide_tweens.has(c): return
	var p: Dictionary = Land.get_parcel(biome, c)
	var col: Color = Color.WHITE if str(p.land).begins_with("sheet_") else p.land_color
	match overlay:
		"life":
			var concentration := int(p.life_concentration)
			if concentration < 0: col = Color("935f96")
			elif concentration == 0: col = Color("387781")
			elif concentration < 8: col = Color("6caa6e").lerp(Color("b0c781"), concentration / 8.0)
			else: col = Color("eac277")
		"ember", "silence", "eternity":
			var v: float = float(p.elements[overlay]) / 100.0
			var ec := Color(str(Data.elements[overlay].color))
			col = Color("1c1a1e").lerp(ec, 0.15 + v * 0.85)
		"temperature":
			col = Color(str(Data.temperatures[p.temperature].color))
		"effects":
			col = col.darkened(0.45)
			if not p.effects.is_empty():
				col = Color(str(p.effects[0].color)).lerp(col, 0.25)
		"build":
			if build_type != "":
				var reason: String = Sim.can_place(build_type, biome, c)
				if reason == tr("Not enough money") or reason.begins_with("Missing"): reason = ""
				if reason != "":
					col = col.darkened(0.55)
				else:
					var st: Dictionary = StatMath.machine_stats(build_type, p)
					col = Color("b8503a").lerp(Color("8ad06a"), StatMath.suitability(st))
	var selected: bool = c == selected_cell
	_tile_mats[c].albedo_color = col.lightened(0.2) if selected else col
	_tile_mats[c].emission_enabled = selected
	_tile_mats[c].emission = Color("f6d67b")
	_tile_mats[c].emission_energy_multiplier = 0.18

func _frame(color: Color, selected: bool) -> Node3D:
	var f := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (TILE - 0.025)
	f.mesh = plane
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FocusShader
	material.set_shader_parameter("ink", color)
	material.set_shader_parameter("selected", selected)
	material.render_priority = 4 if selected else 3
	f.material_override = material
	f.visible = false
	add_child(f)
	return f

func _place_frame(f: Node3D, c: Vector2i) -> void:
	f.visible = Land.in_grid(c)
	if f.visible:
		var tile: MeshInstance3D = _tiles[c]
		f.position = tile.transform * Vector3(0, 0.34, 0)
		f.rotation = tile.rotation

func select_cell(c: Vector2i) -> void:
	var previous := selected_cell
	selected_cell = c
	if Land.in_grid(previous):
		_moving_cells[previous] = true
		_recolor_tile(previous)
	if Land.in_grid(c):
		_moving_cells[c] = true
		_recolor_tile(c)
	_place_frame(_select_frame, c)
	_update_aura_preview()

# ------------------------------------------------------------------ effects
func _build_effects() -> void:
	_effect_anchors.clear()
	for ch in _effect_root.get_children(): ch.queue_free()
	for b: Dictionary in Land.bindings_in(biome):
		if b.source != "seed": continue
		var eff: Dictionary = Data.effects[b.effect]
		var col := Color(str(eff.color))
		var center: Vector3 = cell_to_world(b.center) + Vector3(0, float(Land.get_parcel(biome, b.center).height), 0)
		var motes := MeshKit.particles(_effect_root, Vector3.ZERO, col.lightened(0.25), 7, Vector3(0.26,0.12,0.26),Vector3(0.07,0.34,-0.03),0.055,2.6,0.7)
		motes.position = center + Vector3.UP * 0.70
		motes.set_meta("cell", b.center)
		_effect_anchors.append(motes)
		var r: int = int(b.radius)
		var area := Vector2((r * 2 + 1) * TILE - 0.1, (r * 2 + 1) * TILE - 0.1)
		var extent := MeshKit.plane(_effect_root, area, center + Vector3(0, 0.04, 0), Color(col, 0.18))
		extent.set_meta("overlay_only", true)
		extent.visible = overlay == "effects"
		var lbl := _label(str(eff.name), center + Vector3(0, 1.5, 0), col.lightened(0.25), 28)
		lbl.set_meta("overlay_only", true)
		lbl.visible = overlay == "effects"
		_effect_root.add_child(lbl)

func _update_aura_preview() -> void:
	for ch in _aura_preview.get_children(): ch.queue_free()
	if showcase: return
	var origin := selected_cell
	var type := build_type
	if type != "":
		origin = hover_cell
	else:
		type = str(Sim.machine_at(biome, origin).get("type", ""))
	if type == "" or not Land.in_grid(origin): return
	var footprint := Land.machine_neighbors(origin, str(Data.machines[type].area))
	for cell: Vector2i in footprint:
		var marker := _frame(Color("8feace"), false)
		marker.reparent(_aura_preview)
		marker.set_meta("cell", cell)
		_place_frame(marker, cell)

# ------------------------------------------------------------------ machines
func set_build_type(id: String) -> void:
	if _ghost_model:
		_ghost_model.free()
		_ghost_model = null
	build_type = id if Data.machines.has(id) else ""
	if build_type != "":
		_ghost_model = VOLUMES[build_type].instantiate()
		_ghost.add_child(_ghost_model)
	set_overlay("build" if build_type != "" else ("none" if overlay == "build" else overlay))
	_update_ghost()

func _update_ghost() -> void:
	_ghost.visible = _ghost_model != null and Land.in_grid(hover_cell)
	if _ghost.visible:
		_position_ghost()
		var ok := Sim.can_place(build_type, biome, hover_cell) == ""
		_ghost_model.set_finish(Color("a8ffd7") if ok else Color("ed8290"))
	_update_aura_preview()

func _position_ghost() -> void:
	var tile: MeshInstance3D = _tiles[hover_cell]
	_ghost.position = tile.position + Vector3.UP * 0.31

func refresh_machines() -> void:
	var alive: Dictionary = {}
	for m: Dictionary in (showcase_machines.values() if showcase else Sim.machines_in(biome)):
		alive[m.uid] = true
		if not _machine_nodes.has(m.uid): _machine_nodes[m.uid] = _make_machine_node(m)
		_update_machine_node(m)
	for uid: int in _machine_nodes.keys():
		if not alive.has(uid):
			_machine_nodes[uid].root.queue_free()
			_machine_nodes.erase(uid)

func _make_machine_node(m: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.position = cell_to_world(m.cell) + Vector3(0, float(Land.get_parcel(biome, m.cell).height), 0)
	_machine_root.add_child(root)
	_add_root_shadow(root, 1.0)
	var model: Node3D = VOLUMES[m.type].instantiate()
	root.add_child(model)
	var badge := _label("", Vector3(0, MACHINE_BADGE_HEIGHT, 0), Color("f0b35b"), 30)
	badge.pixel_size = 0.0115
	root.add_child(badge)
	var node: Dictionary = {"root": root, "model": model, "badge": badge, "phase": randf() * TAU, "playhead": 0.0}
	var light := OmniLight3D.new()
	light.light_color = {"propagator": Color("e4cf76"), "collector": Color("9cf2c6"), "extractor": Color("85d9ee")}[m.type]
	light.omni_range = 2.7
	light.light_energy = 0.0
	light.position = Vector3(0, 1.0, 0.3)
	root.add_child(light)
	node.light = light
	node.pulse = 0.0
	return node

func _add_root_shadow(root: Node3D, size_factor: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = RootShadow
	shadow.scale = Vector3(size_factor, 1.0, size_factor)
	shadow.position.y = .013
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)

func _update_machine_node(m: Dictionary) -> void:
	var n: Dictionary = _machine_nodes[m.uid]
	n.work_rate = 1.0 if showcase else (0.30 if m.enabled else 0.0)
	var badge: Label3D = n.badge
	badge.text = "" if m.enabled else tr("Paused")
	badge.modulate = Color("b9bec8")
	if not showcase and m.type == "extractor" and selected_cell == m.cell:
		badge.text = ("%s  " % badge.text if not badge.text.is_empty() else "") + "%d / 8" % int(m.carry.get("concentration", 0))
	n.model.set_finish(Color.WHITE if m.enabled else Color("8f9ca8"))

func _on_machines_changed(b: String) -> void:
	if b == biome:
		refresh_machines()
		_update_ghost()
		if overlay == "build": _recolor_tiles()

func _on_parcels_changed(b: String) -> void:
	if b != biome: return
	if overlay != "none": _queue_recolor()

func _queue_recolor() -> void:
	if not _recolor_pending:
		_recolor_pending = true
		_recolor_tiles.call_deferred()

func _on_machine_cycled(uid: int) -> void:
	if showcase or not _machine_nodes.has(uid): return
	var n: Dictionary = _machine_nodes[uid]
	n.pulse = 1.0
	var m: Dictionary = Sim.machines.get(uid, {})
	var out: Dictionary = m.get("last_output", {})
	var text: String = ""
	var col := Color("f2e6c8")
	for id: String in out:
		text += "+%d %s  " % [int(out[id]), Data.item_name(id)]
		col = Data.item_color(id).lightened(0.3)
	if text == "": return
	var lbl: Label3D = _label(text.strip_edges(), n.root.position + Vector3(0, 3.4, 0), col, 30)
	lbl.pixel_size = 0.0105
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.2, 1.4)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.4)
	tw.tween_callback(lbl.queue_free)

func refresh_weather() -> void:
	var w: Dictionary = Sim.weather.get(biome, {})
	scenery.set_weather(str(w.get("effect", "")))
	if overlay != "none": _recolor_tiles()

func _label(text: String, pos: Vector3, color: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font = _label_font
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color("1a1416")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	return l

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	_update_tile_motion(delta)
	if not showcase and (not Sim.life_growth.is_empty() or not _growth_nodes.is_empty()):
		_growth_refresh_left -= delta
		if _growth_refresh_left <= 0.0:
			_refresh_growth_visuals()
			_growth_refresh_left = 0.1
	for tween: Tween in _tide_tweens.values():
		tween.set_speed_scale(0.0 if Sim.paused else Sim.time_scale)
	_t += delta
	if showcase: _yaw_target += delta * 0.6
	_yaw = lerpf(_yaw, _yaw_target, 1.0 - exp(-delta * 7.0))
	_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-delta * 9.0))
	_camera_pan = _camera_pan.lerp(_pan, 1.0 - exp(-delta * 20.0))
	_apply_camera()
	var sim_speed := 1.0 if showcase else (0.0 if Sim.paused else Sim.time_scale)
	if _ghost.visible: _position_ghost()
	for marker: Node3D in _aura_preview.get_children():
		_place_frame(marker, marker.get_meta("cell"))
	for uid: int in _machine_nodes:
		var n: Dictionary = _machine_nodes[uid]
		var m: Dictionary = showcase_machines.get(uid, {}) if showcase else Sim.machines.get(uid, {})
		if m.is_empty(): continue
		n.root.position.y = _tiles[m.cell].position.y + 0.31
		n.pulse = maxf(0.0, float(n.pulse) - delta * sim_speed * 0.55)
		var rate: float = float(n.work_rate) + float(n.pulse) * 1.5 if m.enabled else 0.0
		if sim_speed * rate > 0.0:
			n.playhead = fposmod(float(n.playhead) + delta * sim_speed * rate * WORK_CYCLES_PER_SECOND, 4.0)
			n.model.pose(n.playhead)
		if n.has("light"):
			var flicker := sin(float(n.playhead) * TAU + float(n.phase))
			var target := 0.38 + 0.1 * flicker + float(n.pulse) if rate > 0.0 else 0.0
			n.light.light_energy = lerpf(n.light.light_energy, target, 1.0 - exp(-4.0 * delta * sim_speed))
	_badge_timer -= delta
	if _badge_timer <= 0.0:
		_badge_timer = 0.25
		for m2: Dictionary in (showcase_machines.values() if showcase else Sim.machines_in(biome)):
			if _machine_nodes.has(m2.uid): _update_machine_node(m2)
	for anchor: Node3D in _effect_anchors:
		anchor.position.y = _tiles[anchor.get_meta("cell")].position.y + 1.01

func _begin_tide_motion(cell: Vector2i, new_id: String) -> Tween:
	var tile: MeshInstance3D = _tiles[cell]
	if _tide_tweens.has(cell):
		_tide_tweens[cell].kill()
	tile.rotation = Vector3.ZERO
	tile.material_overlay = null
	_tile_heights[cell] = float(Data.land_types[new_id].get("height", 0.0))
	_moving_cells[cell] = true
	var tween := create_tween()
	tween.set_speed_scale(0.0 if Sim.paused else Sim.time_scale)
	_tide_tweens[cell] = tween
	return tween

func _finish_tide_motion(cell: Vector2i) -> void:
	var tile: MeshInstance3D = _tiles[cell]
	tile.material_overlay = null
	tile.rotation = Vector3.ZERO
	_tide_tweens.erase(cell)
	scenery.land.refresh_boundary(cell)
	_moving_cells[cell] = true
	_queue_recolor()

func _on_tide_tile(b: String, cell: Vector2i, old_id: String, next_id: String, edge: int) -> void:
	if b != biome or showcase or not _tiles.has(cell): return
	if old_id in ["sheet_river", "sheet_riverbed"] and next_id in ["sheet_river", "sheet_riverbed"]:
		_on_tide_transform(b, cell, old_id, next_id, edge)
		return
	var tile: MeshInstance3D = _tiles[cell]
	var tween := _begin_tide_motion(cell, next_id)
	var start_y := tile.position.y
	var axis: Vector3 = Vector3.FORWARD if edge < 2 else Vector3.RIGHT
	if edge == 1 or edge == 2: axis = -axis
	_set_tile_model(tile, old_id, cell)
	var animate := func(t: float) -> void:
		var lift := float(_selection_lifts.get(cell, 0.0))
		var rest_y := float(_tile_heights[cell]) - 0.31 + lift
		var angle := smoothstep(0.0, 1.0, t) * PI
		tile.position.y = lerpf(start_y, rest_y, t) + 0.93 * sin(t * PI)
		tile.rotation = axis * (angle if t < 0.5 else angle - PI)
	tween.tween_method(animate, 0.0, 0.5, 0.30)
	tween.tween_callback(_set_tile_model.bind(tile, next_id, cell))
	tween.tween_method(animate, 0.5, 1.0, 0.30)
	tween.tween_callback(_finish_tide_motion.bind(cell))

func _set_tile_model(tile: MeshInstance3D, id: String, cell: Vector2i) -> void:
	if tile.get_meta(&"land_id", "") == id: return
	tile.set_meta(&"land_id", id)
	var model_path: String = "res://assets/models/terrain/%s.tres" % id
	tile.material_override = null
	if not _terrain_meshes.has(id) and ResourceLoader.exists(model_path):
		_terrain_meshes[id] = load(model_path)
	if _terrain_meshes.has(id):
		tile.mesh = _terrain_meshes[id]
		var top := TerrainSurface.apply(tile, id, biome, cell)
		tile.set_surface_override_material(0, top)
		_tile_mats[cell] = top
	else:
		var fallback := BoxMesh.new()
		fallback.size = Vector3(TILE - 0.07, 0.62, TILE - 0.07)
		tile.mesh = fallback
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(str(Data.land_types[id].color))
		tile.material_override = material
		_tile_mats[cell] = material

func _refresh_growth_visuals() -> void:
	if showcase: return
	var alive: Dictionary = {}
	for key: String in Sim.life_growth:
		var g: Dictionary = Sim.life_growth[key]
		if str(g.biome) != biome: continue
		alive[key] = true
		if not _growth_nodes.has(key):
			var root := Node3D.new()
			var cell := Vector2i(int(g.cell[0]), int(g.cell[1]))
			_cell_props[cell].add_child(root)
			root.position = cell_to_world(cell) + Vector3.UP * float(_prop_base_heights[cell])
			_add_root_shadow(root, .52)
			var label := _label("",Vector3(0,1.8,0),UITheme.CREAM,26)
			label.font = UITheme.build().default_font
			root.add_child(label)
			_growth_nodes[key] = {"root":root, "model":null, "label":label, "stage":""}
		var nodes: Dictionary = _growth_nodes[key]
		if nodes.stage != str(g.stage):
			nodes.stage = str(g.stage)
			var phase := str(g.stage)
			if nodes.model: nodes.model.free()
			nodes.model = VOLUMES[phase].instantiate()
			nodes.root.add_child(nodes.model)
		nodes.label.text = Sim.growth_text(g).get_slice("\n", 0)
	for key: String in _growth_nodes.keys():
		if not alive.has(key):
			_growth_nodes[key].root.queue_free()
			_growth_nodes.erase(key)

func _update_tile_motion(delta: float) -> void:
	# Once the entrance has settled, touch only the parcels that still have a lift or tide in flight.
	var entering := _entry_age < 1.37
	_entry_age += delta
	var cells: Array = _tiles.keys() if entering else _moving_cells.keys()
	var blend := 1.0 - exp(-delta * 14.0)
	for cell: Vector2i in cells:
		var target := 0.38 if cell == selected_cell else (0.095 if cell == hover_cell else 0.0)
		var lift := lerpf(float(_selection_lifts.get(cell, 0.0)), target, blend)
		var settled := absf(target - lift) < 0.001
		if settled: lift = target
		_selection_lifts[cell] = lift
		var tile: MeshInstance3D = _tiles[cell]
		if not _tide_tweens.has(cell):
			var t := clampf((_entry_age - float(cell.x + cell.y) * 0.04) / 0.56, 0.0, 1.0)
			tile.position.y = float(_tile_heights[cell]) - 0.31 + lift - ENTRY_DEPTH * pow(1.0 - t, 3.0)
			if settled: _moving_cells.erase(cell)
		_cell_props[cell].position.y = tile.position.y + 0.31 - float(_prop_base_heights[cell])
	if is_instance_valid(_select_frame): _place_frame(_select_frame, selected_cell)
	if is_instance_valid(_hover_frame): _place_frame(_hover_frame, hover_cell if hover_cell != selected_cell else Vector2i(-1, -1))

func _on_tide_transform(b: String, cell: Vector2i, old_id: String, new_id: String, edge: int) -> void:
	if b != biome or showcase or not _tiles.has(cell): return
	var tile: MeshInstance3D = _tiles[cell]
	var tween := _begin_tide_motion(cell, new_id)
	if old_id != "": _set_tile_model(tile, old_id, cell)
	var crest := ShaderMaterial.new()
	crest.shader = TideCrestShader
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	crest.set_shader_parameter("direction", directions[edge])
	crest.set_shader_parameter("crest_color", Color("a7f6fa").lerp(Data.palette(biome, "accent"), 0.42))
	tile.material_overlay = crest
	var start_y: float = tile.position.y - float(_selection_lifts.get(cell, 0.0))
	var end_y: float = float(_tile_heights[cell]) - 0.31
	var sweep := func(progress: float) -> void:
		crest.set_shader_parameter("progress", progress)
		tile.position.y = lerpf(start_y, end_y, smoothstep(0.0, 1.0, progress)) + float(_selection_lifts.get(cell, 0.0))
	tween.tween_method(sweep, 0.0, 0.5, 0.27)
	tween.tween_callback(_set_tile_model.bind(tile, new_id, cell))
	tween.tween_method(sweep, 0.5, 1.0, 0.27)
	tween.tween_callback(_finish_tide_motion.bind(cell))
