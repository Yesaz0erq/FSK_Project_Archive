extends Node3D
## One biome on screen: 3D backdrop + the 11x11 plot grid + 2D plant-machine sprites.
## Simulation data lives in Land / Sim; this node only presents it and reports input.

signal hovered(cell: Vector2i)
signal clicked(cell: Vector2i, button: int)
signal context_requested(cell: Vector2i, point: Vector2)

const TILE: float = 1.6
const GRID: int = 11
const SPRITE_PX: float = 0.0049
const SceneryScript := preload("res://scripts/world/scenery.gd")

var biome: String = "forest"
var showcase: bool = false
var overlay: String = "none"          # none / fire / water / earth / air / temperature / effects
var build_type: String = ""
var hover_cell := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)

var scenery: Node3D
var camera: Camera3D
var _pivot: Node3D
var _yaw: float = 45.0
var _yaw_target: float = 45.0
var _zoom: float = 21.0
var _zoom_target: float = 21.0
var _pan := Vector3.ZERO
var _dragging: bool = false
var _entry_age: float = 0.0
var _selection_lifts: Dictionary = {}
var _cell_props: Dictionary = {}
var _tiles: Dictionary = {}          # cell -> MeshInstance3D
var _tide_tweens: Dictionary = {}
var _tile_mats: Dictionary = {}      # cell -> StandardMaterial3D
var _grid_root: Node3D
var _effect_root: Node3D
var _machine_root: Node3D
var _sprites: Dictionary = {}        # uid -> Dictionary of nodes
var _hover_frame: Node3D
var _select_frame: Node3D
var _aura_preview: Node3D
var _ghost: Sprite3D
var _t: float = 0.0
var _badge_timer: float = 0.0
var _label_font: Font

func setup(biome_id: String, is_showcase: bool = false) -> void:
	biome = biome_id
	showcase = is_showcase
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
	_hover_frame = _frame(Color("f2e6c8"), 0.6)
	_select_frame = _frame(Color("ffcf6b"), 1.6)
	_aura_preview = Node3D.new()
	add_child(_aura_preview)
	_ghost = Sprite3D.new()
	_setup_sprite(_ghost)
	_ghost.modulate = Color(1, 1, 1, 0.6)
	_ghost.visible = false
	add_child(_ghost)
	refresh_machines()
	refresh_weather()
	Land.parcels_changed.connect(_on_parcels_changed)
	Land.tide_tile_changed.connect(_on_tide_tile)
	Land.tide_tile_transformed.connect(_on_tide_transform)
	Sim.machines_changed.connect(_on_machines_changed)
	Sim.machine_cycled.connect(_on_machine_cycled)
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
	_pivot.position = _pan
	_pivot.rotation.y = deg_to_rad(_yaw)
	camera.position = Vector3(0, sin(pitch) * 60.0, cos(pitch) * 60.0)
	camera.rotation = Vector3(-pitch, 0, 0)
	camera.size = _zoom

func rotate_view(step: int) -> void:
	_yaw_target += 90.0 * step

func reset_view() -> void:
	_pan = Vector3.ZERO
	_zoom_target = 21.0

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
			var base: Vector3 = cell_to_world(c)
			var tile := MeshInstance3D.new()
			_set_tile_model(tile, str(parcel.land), c)
			tile.scale = Vector3(1.0392, 1.0, 1.0392)
			tile.position = base + Vector3(0, h - 0.31 - 2.4, 0)
			_grid_root.add_child(tile)
			_tiles[c] = tile
			rng.seed = int(parcel.variant) + x * 31 + y * 7
			var props := Node3D.new()
			_grid_root.add_child(props)
			_cell_props[c] = props
			props.position.y = -2.4
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
	var col: Color = Data.item_color(resource)
	for i in range(3):
		var off := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
		MeshKit.ball(parent, top + off + Vector3(0, 0.06, 0), Vector3(0.26, 0.2, 0.24) * rng.randf_range(0.8, 1.3), col, 5, 3)
	var icon := Sprite3D.new()
	icon.texture = Art.item(resource)
	icon.pixel_size = 0.0075
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	icon.shaded = false
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position = top + Vector3(0.42, 0.55, 0.42)
	icon.set_meta("bob", rng.randf() * TAU)
	icon.name = "Deposit_%s" % resource
	parent.add_child(icon)

func set_overlay(mode: String) -> void:
	overlay = mode
	_recolor_tiles()
	for ch in _effect_root.get_children():
		if ch.has_meta("effect_label"): ch.visible = mode == "effects"

func _recolor_tiles() -> void:
	for c: Vector2i in _tiles:
		if _tide_tweens.has(c): continue
		var p: Dictionary = Land.get_parcel(biome, c)
		var col: Color = Color.WHITE if str(p.land).begins_with("sheet_") else p.land_color
		match overlay:
			"life", "ember", "silence", "eternity":
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

func _frame(color: Color, emission: float) -> Node3D:
	var f := Node3D.new()
	var w: float = TILE - 0.04
	for i in range(4):
		var horiz: bool = i < 2
		var s := Vector3(w, 0.05, 0.07) if horiz else Vector3(0.07, 0.05, w)
		var off := Vector3(0, 0.03, (w * 0.5) * (1 if i == 0 else -1)) if horiz else Vector3((w * 0.5) * (1 if i == 2 else -1), 0.03, 0)
		MeshKit.box(f, s, off, color, emission, false)
	f.visible = false
	add_child(f)
	return f

func _place_frame(f: Node3D, c: Vector2i) -> void:
	f.visible = Land.in_grid(c)
	if f.visible:
		f.position = cell_to_world(c) + Vector3(0, _tiles[c].position.y + 0.33, 0)

func select_cell(c: Vector2i) -> void:
	selected_cell = c
	_recolor_tiles()
	_place_frame(_select_frame, c)
	_update_aura_preview()

# ------------------------------------------------------------------ effects
func _build_effects() -> void:
	for ch in _effect_root.get_children(): ch.queue_free()
	for b: Dictionary in Land.bindings_in(biome):
		if b.source != "seed": continue
		var eff: Dictionary = Data.effects[b.effect]
		var col := Color(str(eff.color))
		var center: Vector3 = cell_to_world(b.center) + Vector3(0, float(Land.get_parcel(biome, b.center).height), 0)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		tm.rings = 18
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = MeshKit.mat(col, 1.8)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = center + Vector3(0, 0.9, 0)
		ring.set_meta("spin", true)
		_effect_root.add_child(ring)
		var core: MeshInstance3D = MeshKit.ball(_effect_root, center + Vector3(0, 0.9, 0), Vector3(0.16, 0.16, 0.16), col, 6, 4, 2.5)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r: int = int(b.radius)
		var area := Vector2((r * 2 + 1) * TILE - 0.1, (r * 2 + 1) * TILE - 0.1)
		MeshKit.plane(_effect_root, area, center + Vector3(0, 0.04, 0), Color(col, 0.13))
		var lbl := _label(str(eff.name), center + Vector3(0, 1.5, 0), col.lightened(0.25), 28)
		lbl.set_meta("effect_label", true)
		lbl.visible = overlay == "effects"
		_effect_root.add_child(lbl)

func _update_aura_preview() -> void:
	for ch in _aura_preview.get_children(): ch.queue_free()
	var aura: String = ""
	var c: Vector2i = selected_cell
	if build_type != "" and Land.in_grid(hover_cell):
		aura = str(Data.machines[build_type].get("aura", ""))
		c = hover_cell
	elif Land.in_grid(selected_cell):
		var m: Dictionary = Sim.machine_at(biome, selected_cell)
		if not m.is_empty(): aura = str(Data.machines[m.type].get("aura", ""))
	if aura == "": return
	var eff: Dictionary = Data.effects[aura]
	var r: int = int(eff.get("radius", 1))
	var size: float = (r * 2 + 1) * TILE - 0.1
	MeshKit.plane(_aura_preview, Vector2(size, size), cell_to_world(c) + Vector3(0, 0.2, 0), Color(Color(str(eff.color)), 0.28))

# ------------------------------------------------------------------ machines
func _setup_sprite(s: Sprite3D) -> void:
	s.pixel_size = SPRITE_PX
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.shaded = false
	s.double_sided = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func set_build_type(id: String) -> void:
	build_type = id
	if id != "":
		_ghost.texture = Art.machine(id)
		_ghost.offset = Vector2(0, 280)
		_ghost.render_priority = 2
	set_overlay("build" if id != "" else ("none" if overlay == "build" else overlay))
	_update_ghost()

func _update_ghost() -> void:
	_ghost.visible = build_type != "" and Land.in_grid(hover_cell)
	if _ghost.visible:
		_ghost.position = cell_to_world(hover_cell) + Vector3(0, float(Land.get_parcel(biome, hover_cell).height), 0)
		var ok: bool = Sim.can_place(build_type, biome, hover_cell) == ""
		_ghost.modulate = Color(0.85, 1.0, 0.8, 0.7) if ok else Color(1.0, 0.5, 0.45, 0.55)
	_update_aura_preview()

func refresh_machines() -> void:
	var alive: Dictionary = {}
	for m: Dictionary in Sim.machines_in(biome):
		alive[m.uid] = true
		if not _sprites.has(m.uid): _sprites[m.uid] = _make_machine_node(m)
		_update_machine_node(m)
	for uid: int in _sprites.keys():
		if not alive.has(uid):
			_sprites[uid].root.queue_free()
			_sprites.erase(uid)

func _make_machine_node(m: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.position = cell_to_world(m.cell) + Vector3(0, float(Land.get_parcel(biome, m.cell).height), 0)
	_machine_root.add_child(root)
	var s := Sprite3D.new()
	_setup_sprite(s)
	s.texture = Art.machine(m.type)
	s.offset = Vector2(0, 280)
	root.add_child(s)
	var shadow: MeshInstance3D = MeshKit.plane(root, Vector2(1.45, 1.2), Vector3(0, 0.02, 0), Color(0.05, 0.03, 0.02, 0.35))
	shadow.material_override = MeshKit.mat(Color(0.05, 0.03, 0.02, 0.32), 0.0, true)
	var badge := _label("", Vector3(0, 3.55, 0), Color("f0b35b"), 30)
	badge.pixel_size = 0.0115
	root.add_child(badge)
	var bar_bg: Sprite3D = _bar_sprite(Color(0.08, 0.06, 0.07, 0.85), Vector3(0, 3.2, 0), 1.1, 0.13)
	root.add_child(bar_bg)
	var bar: Sprite3D = _bar_sprite(Color("ffcf6b"), Vector3(0, 3.2, 0.0), 1.04, 0.08)
	bar.render_priority = 1
	root.add_child(bar)
	var node: Dictionary = {"root": root, "sprite": s, "badge": badge, "bar": bar, "bar_bg": bar_bg, "phase": randf() * TAU, "kick": 0.0}
	var def: Dictionary = Data.machines[m.type]
	var light_color := Color()
	match str(m.type):
		"ember_lily": light_color = Color("ff9a50")
		"seedpod_kiln", "gourd_kettle": light_color = Color("ffa050")
		"bloom_press": light_color = Color("f0a0c0")
	if light_color != Color():
		var l := OmniLight3D.new()
		l.light_color = light_color
		l.omni_range = 3.6
		l.light_energy = 0.0
		l.position = Vector3(0, 1.0, 0.3)
		root.add_child(l)
		node.light = l
	var puff_color := Color()
	match str(m.type):
		"seedpod_kiln", "gourd_kettle": puff_color = Color("cfc8bc")
		"mist_fern", "pitcher_still": puff_color = Color("cfeaf2")
		"spore_garden": puff_color = Color("efe2c4")
		"leafwing_turbine": puff_color = Color("b6c75a")
	if puff_color != Color():
		var p: CPUParticles3D = MeshKit.particles(root, Vector3(0, 1.6, 0), puff_color, 10, Vector3(0.25, 0.1, 0.25), Vector3(0.1, 0.6, 0), 0.22, 2.2)
		p.emitting = false
		node.puff = p
	node.living = bool(def.get("living", false))
	return node

func _update_machine_node(m: Dictionary) -> void:
	var n: Dictionary = _sprites[m.uid]
	var status: String = str(m.status)
	var working: bool = status == tr("Working") or status == tr("Radiating") or status.begins_with("Low energy")
	n.working = working
	var badge: Label3D = n.badge
	if m.jammed:
		badge.text = "JAMMED"
		badge.modulate = Color("ed7965")
	elif not m.enabled:
		badge.text = "paused"
		badge.modulate = Color("a8a0a0")
	elif status.begins_with("Waiting"):
		badge.text = status.replace(tr("Waiting for "), "needs ")
		badge.modulate = Color("e8c070")
	elif status.begins_with("Low energy"):
		badge.text = "low energy"
		badge.modulate = Color("8ab8e0")
	elif status.begins_with("Too"):
		badge.text = status.to_lower()
		badge.modulate = Color("a8d8f0")
	else:
		badge.text = ""
	var def: Dictionary = Data.machines[m.type]
	var show_bar: bool = def.kind != "support"
	n.bar.visible = show_bar
	n.bar_bg.visible = show_bar
	n.sprite.modulate = Color(0.75, 0.68, 0.68) if m.jammed else Color.WHITE
	if Land.in_grid(selected_cell) and selected_cell == m.cell: n.sprite.modulate = Color(1.12, 1.08, 0.95)
	if n.has("puff"): n.puff.emitting = working and def.kind != "support" or (working and str(m.type) == "mist_fern")
	if n.has("light"): n.light.set_meta("on", working)

func _on_machines_changed(b: String) -> void:
	if b == biome:
		refresh_machines()
		_update_ghost()
		if overlay == "build": _recolor_tiles()

func _on_parcels_changed(b: String) -> void:
	if b != biome: return
	if overlay != "none": _recolor_tiles()

func _on_machine_cycled(uid: int) -> void:
	if not _sprites.has(uid): return
	var n: Dictionary = _sprites[uid]
	n.kick = 1.0
	var m: Dictionary = Sim.machines.get(uid, {})
	var out: Dictionary = m.get("last_output", {})
	var text: String = ""
	var col := Color("f2e6c8")
	for id: String in out:
		text += "+%d %s  " % [int(out[id]), Data.item_name(id)]
		col = Data.item_color(id).lightened(0.3)
	var r: Dictionary = Sim.recipe_of(m)
	if float(r.get("energy_out", 0.0)) > 0.0:
		text = "+energy"
		col = Color("8ad0f0")
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

static var _white: ImageTexture
func _bar_sprite(color: Color, pos: Vector3, w: float, h: float) -> Sprite3D:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	var s := Sprite3D.new()
	s.texture = _white
	s.pixel_size = 1.0
	s.scale = Vector3(w, h, 1.0)
	s.modulate = color
	s.position = pos
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	return s

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
	for tween: Tween in _tide_tweens.values():
		tween.set_speed_scale(0.0 if Sim.paused else Sim.time_scale)
	_t += delta
	if showcase: _yaw_target += delta * 0.6
	_yaw = lerpf(_yaw, _yaw_target, minf(1.0, delta * 6.0))
	_zoom = lerpf(_zoom, _zoom_target, minf(1.0, delta * 8.0))
	_apply_camera()
	for uid: int in _sprites:
		var n: Dictionary = _sprites[uid]
		var m: Dictionary = Sim.machines.get(uid, {})
		if m.is_empty(): continue
		n.root.position.y = _tiles[m.cell].position.y + 0.31
		var s: Sprite3D = n.sprite
		var working: bool = bool(n.get("working", false))
		var ph: float = float(n.phase)
		n.kick = maxf(0.0, float(n.kick) - delta * 3.0)
		var k: float = float(n.kick)
		var breathe: float = sin(_t * 2.2 + ph) * (0.025 if n.living else 0.0)
		var bob: float = absf(sin(_t * 7.0 + ph)) * 0.035 if working else 0.0
		s.scale = Vector3(1.0 + breathe + k * 0.08, 1.0 - breathe * 0.6 - k * 0.1 + bob, 1.0)
		var def: Dictionary = Data.machines[m.type]
		if def.kind != "support":
			var prog: float = clampf(float(m.progress), 0.0, 1.0)
			var bar: Sprite3D = n.bar
			var pr: float = maxf(prog, 0.002)
			bar.scale = Vector3(pr * 1.04, 0.08, 1.0)
			bar.offset = Vector2(-(1.0 - pr) / (2.0 * pr), 0.0)
		if n.has("light"):
			var on: bool = bool(n.light.get_meta("on", false))
			var target: float = (1.3 + 0.25 * sin(_t * 9.0 + ph) * sin(_t * 4.0)) if on else 0.0
			n.light.light_energy = lerpf(n.light.light_energy, target, minf(1.0, delta * 4.0))
	_badge_timer -= delta
	if _badge_timer <= 0.0:
		_badge_timer = 0.25
		for m2: Dictionary in Sim.machines_in(biome):
			if _sprites.has(m2.uid): _update_machine_node(m2)
	for ch in _effect_root.get_children():
		if ch.has_meta("spin"): ch.rotation.y += delta * 0.8
	for ch in _grid_root.get_children():
		if ch is Sprite3D and ch.has_meta("bob"):
			ch.position.y += sin(_t * 1.6 + float(ch.get_meta("bob"))) * delta * 0.08

func _on_tide_tile(b: String, cell: Vector2i, old_id: String, _next_id: String, edge: int) -> void:
	if b != biome or showcase or not _tiles.has(cell): return
	var tile: MeshInstance3D = _tiles[cell]
	if _tide_tweens.has(cell):
		var previous: Tween = _tide_tweens[cell]
		previous.kill()
	var old_height: float = float(Data.land_types[old_id].get("height", 0.0))
	var parcel: Dictionary = Land.get_parcel(biome, cell)
	var next_height: float = float(parcel.height)
	var lift: float = float(_selection_lifts.get(cell, 0.0))
	var origin: Vector3 = cell_to_world(cell) + Vector3(0, old_height - 0.31 + lift, 0)
	var target: Vector3 = cell_to_world(cell) + Vector3(0, next_height - 0.31 + lift, 0)
	tile.position = origin
	tile.rotation = Vector3.ZERO
	_set_tile_model(tile, old_id, cell)
	var axis: Vector3 = Vector3.FORWARD if edge < 2 else Vector3.RIGHT
	var direction: float = -1.0 if edge == 1 or edge == 2 else 1.0
	var tween := create_tween()
	_tide_tweens[cell] = tween
	tween.tween_property(tile, "position:y", origin.y + 0.9, 0.14).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile, "rotation", axis * direction * PI * 0.5, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		# Swap local face orientation edge-on: the new top emerges from below.
		_set_tile_model(tile, str(parcel.land), cell)
		tile.rotation = -axis * direction * PI * 0.5
	)
	tween.tween_property(tile, "rotation", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile, "position", target, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_tide_tweens.erase(cell)
		_recolor_tiles()
	)

func _set_tile_model(tile: MeshInstance3D, id: String, cell: Vector2i) -> void:
	var model_path: String = "res://assets/models/terrain/%s.tres" % id
	tile.material_override = null
	if ResourceLoader.exists(model_path):
		tile.mesh = load(model_path)
		var top: StandardMaterial3D = tile.mesh.surface_get_material(0).duplicate()
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

func _update_tile_motion(delta: float) -> void:
	_entry_age += delta
	for cell: Vector2i in _tiles:
		var target_lift: float = 0.38 if cell == selected_cell else 0.0
		var lift: float = lerpf(float(_selection_lifts.get(cell, 0.0)), target_lift, 1.0 - exp(-delta * 14.0))
		_selection_lifts[cell] = lift
		var tile: MeshInstance3D = _tiles[cell]
		var height: float = float(Land.get_parcel(biome, cell).height)
		if not _tide_tweens.has(cell):
			var progress: float = clampf((_entry_age - float(cell.x + cell.y) * 0.045) / 0.5, 0.0, 1.0)
			var entry: float = -2.4 * pow(1.0 - progress, 3.0)
			tile.position.y = height - 0.31 + lift + entry
		if _cell_props.has(cell): _cell_props[cell].position.y = tile.position.y + 0.31 - height
	if is_instance_valid(_select_frame): _place_frame(_select_frame, selected_cell)
	if is_instance_valid(_hover_frame): _place_frame(_hover_frame, hover_cell)
	if is_instance_valid(_ghost) and Land.in_grid(hover_cell): _ghost.position.y = _tiles[hover_cell].position.y + 0.31


func _on_tide_transform(b: String, cell: Vector2i, _old_id: String, new_id: String, _edge: int) -> void:
	if b != biome or showcase: return
	var tile: MeshInstance3D = _tiles[cell]
	_set_tile_model(tile, new_id, cell)
	var material: StandardMaterial3D = _tile_mats[cell]
	material.albedo_color = Color("e5d9ee")
	var tween := create_tween()
	_tide_tweens[cell] = tween
	tween.tween_property(material, "albedo_color", Color.WHITE, 0.45)
	tween.tween_callback(func() -> void: _tide_tweens.erase(cell); _recolor_tiles())
