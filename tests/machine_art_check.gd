extends Node
## Render the catalog through the playable growth paths and the same scene used for a new game.

const REGION := "forest"
const IDS := ["propagator", "collector", "extractor"]
const FOCUS_CELLS := [Vector2i(3, 6), Vector2i(5, 5), Vector2i(6, 3)]
var game: Node
var view: Node3D
var checked_phases: Dictionary = {}

func _require(ok: bool, description: String) -> bool:
	if not ok:
		push_error("MACHINE ART CHECK: " + description)
		get_tree().quit(1)
	return ok

func _site(id: String, focus: Vector2i) -> Vector2i:
	var result := Vector2i(-1, -1)
	var best := INF
	for y in 11:
		for x in 11:
			var c := Vector2i(x,y)
			if Sim.can_add_life(REGION, c) != "" or Sim.machine_site_reason(id, REGION, c) != "": continue
			if not Sim.growth_at(REGION, c).is_empty(): continue
			var score := float((c-focus).length_squared())
			if score < best:
				best = score
				result = c
	return result

func _phase(c: Vector2i, id: String) -> bool:
	view._refresh_growth_visuals()
	var key := Land.parcel_key(REGION, c)
	if not _require(Sim.growth_at(REGION, c).get("stage","") == id and view._growth_nodes.has(key), "missing stage " + id): return false
	var bud: Node3D = view._growth_nodes[key].model
	if not _require(bud != null and bud.name == id and bud._meshes.size() == 1, "missing 3D growth mesh for " + id): return false
	if not _require(not bud._meshes[0].get_aabb().size.is_zero_approx(), "empty bud mesh " + id): return false
	checked_phases[id] = true
	return true

func _grow(id: String, c: Vector2i) -> bool:
	if not _require(Land.in_grid(c), "no viable site for " + id): return false
	if not _require(Sim.add_life_point(REGION,c) == "", "seed failed"): return false
	if not _phase(c,"phase1"): return false
	if id == "propagator":
		Sim._tick_life_growth(5.0)
		if not _phase(c,"phase2_1"): return false
	else:
		if not _require(Sim.add_life_point(REGION,c) == "", "second point failed"): return false
		if not _phase(c,"phase2_2"): return false
		if id == "collector":
			Sim._tick_life_growth(10.0)
			if not _phase(c,"phase3_1"): return false
		else:
			if not _require(Sim.add_life_point(REGION,c) == "", "third point failed"): return false
			if not _phase(c,"phase3_2"): return false
	Sim._tick_life_growth(10.0)
	view._refresh_growth_visuals()
	var m := Sim.machine_at(REGION,c)
	if not _require(m.get("type","") == id and view._machine_nodes.has(m.uid), "missing adult " + id): return false
	if not _require(not view._growth_nodes.has(Land.parcel_key(REGION,c)), "old growth sprite remains after maturing"): return false
	var model: Node3D = view._machine_nodes[m.uid].model
	if not _require(model.name == id and not model._joints.is_empty(), "missing articulated model " + id): return false
	if not _require(model._meshes.size() <= 10, "unbatched machine geometry " + id): return false
	for part: MeshInstance3D in model._meshes:
		var bounds := part.get_aabb().size
		if not _require(bounds.x > 0 and bounds.y > 0 and bounds.z > 0 and part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "empty mesh or missing shadow for " + id): return false
	var portrait := Art.machine(id)
	if not _require(portrait != null and portrait.resource_path.ends_with("/%s_portrait.png" % id), "missing portrait"): return false
	return true

func _ready() -> void:
	get_window().size = Vector2i(1600,960)
	Settings.autosave_seconds = 0
	Settings.tide_seconds = 30.0
	Sim.set_process(false)
	Sim.new_game(2026)
	Sim.inventory.life = 20
	if not _require(Data.machine_order.size() == IDS.size(), "retired machine in catalog"): return
	game = preload("res://scenes/game.tscn").instantiate()
	add_child(game)
	view = game.view
	for i in IDS.size():
		if not _require(Data.machine_order.has(IDS[i]), "missing catalog entry " + IDS[i]): return
		if not _grow(IDS[i], _site(IDS[i], FOCUS_CELLS[i])): return
	if not _require(checked_phases.size() == 5, "growth phases unchecked"): return
	var rest: Dictionary = {}
	for uid: int in view._machine_nodes:
		rest[uid] = view._machine_nodes[uid].model._joints[0].node.transform
	view._process(0.28)
	for uid: int in view._machine_nodes:
		var joint: Node3D = view._machine_nodes[uid].model._joints[0].node
		if not _require(not joint.transform.is_equal_approx(rest[uid]), "joint did not animate"): return
		rest[uid] = joint.transform
	Sim.paused = true
	view.rotate_view(1)
	view._process(1.25)
	for uid: int in view._machine_nodes:
		var node: Dictionary = view._machine_nodes[uid]
		if not _require(node.model._joints[0].node.transform.is_equal_approx(rest[uid]) and node.model.global_basis.is_equal_approx(Basis.IDENTITY), "camera rotation moved a paused model"): return
	view.set_build_type(IDS[0])
	view._set_hover(Vector2i(5,5))
	if not _require(view._ghost.visible and view._ghost_model.name == IDS[0] and view._ghost_model._meshes.size() > 0, "missing 3D placement preview"): return
	view.set_build_type("")
	view._set_hover(Vector2i(-1,-1))
	view.rotate_view(-1)
	view._zoom_target = 11.4
	Sim.paused = false
	Sim.set_process(true)
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(4.0).timeout
		await RenderingServer.frame_post_draw
		var path := "res://docs/initial-machines.png"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture="): path = arg.trim_prefix("--capture=")
		if not _require(get_viewport().get_texture().get_image().save_png(path) == OK, "capture failed"): return
	print("INITIAL MACHINE ART OK: 3 articulated machines, 5 3D growth models, solid placement preview, cast shadows, paused camera orbit")
	get_tree().quit()
