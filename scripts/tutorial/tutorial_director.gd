extends Node

signal finished
enum Stage { ARRIVAL, FIRST, PAIRS, WAIT_PROPAGATOR, PROPAGATOR_CARD, THIRD, WAIT_COLLECTOR, COLLECTOR_CARD, WAIT_EXTRACTOR, EXTRACTOR_CARD, COMPLETE }
enum InputMode { PARCEL, WHEEL, ARMED }

var stage := Stage.ARRIVAL
var hints: Array[Vector2i] = []
var _mode := InputMode.PARCEL
var _biome := ""
var _overlay: Control
var _eligible: Array[Vector2i] = []
var _sites: Array[Vector2i] = []
var _progress: Dictionary = {}
var _third := Vector2i(-1, -1)
var _collector := Vector2i(-1, -1)
var _delay := 8.0
const EXTRACTOR_FINISH_DELAY := 2.0

func _ready() -> void:
	# The guide supplies the growth offsets for the paired plots until free play.
	Sim.set_process(false)

func start(biome: String, overlay: Control) -> void:
	_biome = biome
	_overlay = overlay
	_overlay.intro_dismissed.connect(_dismiss_card)
	Land.tide_tiles_settled.connect(_refresh_first_plots)
	_set_stage(Stage.FIRST)
	_refresh_first_plots()

func _refresh_first_plots() -> void:
	if stage != Stage.FIRST: return
	var view: Node3D = _overlay._view
	var offscreen: Array[Vector2i] = []
	_eligible.clear()
	for cell: Vector2i in view._tiles:
		var parcel: Dictionary = Land.get_parcel(_biome, cell)
		if parcel.get("land", "") != "sheet_grass": continue
		if Sim.can_add_life(_biome, cell) != "": continue
		if ["propagator", "collector", "extractor"].any(func(id: String) -> bool: return Sim.machine_site_reason(id, _biome, cell) != ""): continue
		var tile: MeshInstance3D = view._tiles[cell]
		var p: Vector2 = view.camera.unproject_position(tile.to_global(Vector3(0, .31, 0)))
		if get_viewport().get_visible_rect().grow(-150).has_point(p) and view._pick(p) == cell:
			_eligible.append(cell)
		else:
			offscreen.append(cell)
	var visible_count := _eligible.size()
	if visible_count < 3: _eligible.append_array(offscreen)
	if not hints.is_empty() and _eligible.has(hints[0]): return
	hints.clear()
	if _eligible.size() >= 3:
		var index := randi_range(0, visible_count - 1) if visible_count > 0 else 0
		hints.append(_eligible[index])
	if _mode != InputMode.WHEEL: _show_tiles()

func stop() -> void:
	set_process(false)
	Sim.set_process(true)

func is_complete() -> bool:
	return stage == Stage.COMPLETE

func is_armed() -> bool:
	return _mode == InputMode.ARMED

func open_menu(cell: Vector2i) -> bool:
	if _mode != InputMode.PARCEL or hints.is_empty() or not Land.in_grid(cell): return false
	_mode = InputMode.WHEEL
	_overlay.show_sector()
	return true

func arm_life() -> void:
	if _mode != InputMode.WHEEL: return
	_mode = InputMode.ARMED
	_show_tiles()

func cancel_selection() -> void:
	if _mode == InputMode.PARCEL: return
	_mode = InputMode.PARCEL
	if not hints.is_empty(): _show_tiles()

func place_at(cell: Vector2i) -> void:
	if not is_armed(): return
	match stage:
		Stage.FIRST:
			_refresh_first_plots()
			if _eligible.size() < 3 or not _eligible.has(cell): return
		Stage.PAIRS:
			if not hints.has(cell): return
		Stage.THIRD:
			if cell not in [_sites[1], _sites[2]] or Sim.growth_at(_biome, cell).get("stage", "") != "phase2_2": return
		_:
			return
	if Sim.add_life_point(_biome, cell) != "": return
	_progress[cell] = int(_progress.get(cell, 0)) + 1
	match stage:
		Stage.FIRST:
			_sites = [cell]
			for candidate: Vector2i in _eligible:
				if candidate == cell: continue
				_sites.append(candidate)
				if _sites.size() == 3: break
			_set_stage(Stage.PAIRS, [_sites[1], _sites[2]])
		Stage.PAIRS:
			if _progress[cell] >= 2: hints.erase(cell)
			if hints.is_empty():
				_set_stage(Stage.WAIT_PROPAGATOR)
			else:
				_show_tiles()
		Stage.THIRD:
			_third = cell
			_collector = _sites[1] if cell == _sites[2] else _sites[2]
			_set_stage(Stage.WAIT_COLLECTOR)

func _process(delta: float) -> void:
	if Sim.paused or not Sim.running or Settings.is_open() or get_parent().pause_menu.active: return
	var holds := {}
	if stage == Stage.WAIT_PROPAGATOR and _delay > 0.0:
		# Count only world time towards the paired seedlings' staggered start.
		for cell: Vector2i in [_sites[1], _sites[2]]:
			holds[Land.parcel_key(_biome, cell)] = _delay
	elif stage == Stage.WAIT_COLLECTOR:
		# Leave the extractor's final two seconds for its own introduction.
		var remaining := float(Sim.growth_at(_biome, _third).remaining)
		var available := maxf(0.0, remaining - EXTRACTOR_FINISH_DELAY)
		holds[Land.parcel_key(_biome, _third)] = maxf(0.0, delta * Sim.time_scale - available)
	var before := Sim.game_time
	Sim.step(delta, holds, Sim.time_scale)
	match stage:
		Stage.WAIT_PROPAGATOR:
			_delay = maxf(0.0, _delay - (Sim.game_time - before))
			_check_machine(_sites[0], "propagator", Stage.PROPAGATOR_CARD)
		Stage.WAIT_COLLECTOR:
			_check_machine(_collector, "collector", Stage.COLLECTOR_CARD)
		Stage.WAIT_EXTRACTOR:
			_check_machine(_third, "extractor", Stage.EXTRACTOR_CARD)

func _check_machine(cell: Vector2i, id: String, next: Stage) -> void:
	if Sim.machine_at(_biome, cell).get("type", "") != id: return
	_set_stage(next)
	_overlay.show_intro(cell, id)

func _dismiss_card() -> void:
	match stage:
		Stage.PROPAGATOR_CARD:
			_third = _sites[2]
			_collector = _sites[1]
			_set_stage(Stage.THIRD, [_third])
		Stage.COLLECTOR_CARD:
			_set_stage(Stage.WAIT_EXTRACTOR)
		Stage.EXTRACTOR_CARD:
			_set_stage(Stage.COMPLETE)
			stop()
			finished.emit()

func _scripted_pause(at_stage: Stage) -> bool:
	return at_stage in [Stage.PAIRS, Stage.PROPAGATOR_CARD, Stage.THIRD, Stage.COLLECTOR_CARD, Stage.EXTRACTOR_CARD]

func _set_stage(next: Stage, cells: Array = []) -> void:
	var was_locked := _scripted_pause(stage)
	stage = next
	var locked := _scripted_pause(stage)
	if locked:
		Sim.paused = true
	elif was_locked:
		Sim.time_scale = 1.0
		Sim.paused = false
	get_parent().hud.set_tutorial_time_locked(locked)
	hints.assign(cells)
	_show_tiles()

func _show_tiles() -> void:
	if hints.is_empty():
		_overlay.clear_hint()
		return
	var left := is_armed()
	var counts := {}
	if left:
		for cell: Vector2i in hints:
			counts[cell] = "X%d" % (2 - int(_progress.get(cell, 0))) if stage == Stage.PAIRS else "X1"
	_overlay.show_tiles(hints, left, counts)
