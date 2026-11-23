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

func _ready() -> void:
	# Never let the autoload tick simultaneously with the guided timeline.
	Sim.paused = true

func start(biome: String, overlay: Control) -> void:
	_biome = biome
	_overlay = overlay
	_overlay.intro_dismissed.connect(_dismiss_card)
	var view: Node3D = overlay._view
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in view._tiles:
		var parcel: Dictionary = Land.get_parcel(biome, cell)
		if parcel.get("land", "") != "sheet_grass": continue
		if Sim.can_add_life(biome, cell) != "": continue
		if ["propagator", "collector", "extractor"].any(func(id: String) -> bool: return Sim.machine_site_reason(id, biome, cell) != ""): continue
		var tile: MeshInstance3D = view._tiles[cell]
		var p: Vector2 = view.camera.unproject_position(tile.to_global(Vector3(0, .31, 0)))
		if get_viewport().get_visible_rect().grow(-150).has_point(p) and view._pick(p) == cell:
			candidates.append(cell)
	if candidates.size() < 3:
		push_error("Tutorial requires three visible suitable grass parcels.")
		stop()
		return
	_eligible = candidates.duplicate()
	candidates.shuffle()
	_sites.assign(candidates.slice(0, 3))
	_set_stage(Stage.FIRST, [_sites[0]])

func stop() -> void:
	set_process(false)

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
	_show_tiles()

func place_at(cell: Vector2i) -> void:
	if not is_armed(): return
	match stage:
		Stage.FIRST:
			if not _eligible.has(cell): return
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
				cancel_selection()
		Stage.THIRD:
			_third = cell
			_collector = _sites[1] if cell == _sites[2] else _sites[2]
			_set_stage(Stage.WAIT_COLLECTOR)

func _process(delta: float) -> void:
	if not is_instance_valid(_overlay) or Settings.is_open() or get_parent().pause_menu.active: return
	match stage:
		Stage.WAIT_PROPAGATOR:
			# Start paired seedlings after the one-point plant, leaving time to select the third point.
			var hold := minf(delta, _delay)
			_delay -= hold
			Sim.step(delta, {
				Land.parcel_key(_biome, _sites[1]): hold,
				Land.parcel_key(_biome, _sites[2]): hold,
			})
			_check_machine(_sites[0], "propagator", Stage.PROPAGATOR_CARD)
		Stage.WAIT_COLLECTOR:
			Sim.step(delta)
			_check_machine(_collector, "collector", Stage.COLLECTOR_CARD)
		Stage.WAIT_EXTRACTOR:
			Sim.step(delta)
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
			Sim.time_scale = 1.0
			Sim.paused = false
			finished.emit()
			stop()

func _set_stage(next: Stage, cells: Array = []) -> void:
	stage = next
	hints.assign(cells)
	_mode = InputMode.PARCEL
	_show_tiles()

func _show_tiles() -> void:
	if hints.is_empty():
		_overlay.clear_hint()
		return
	var left := is_armed()
	var count := ("X2" if stage == Stage.PAIRS else "X1") if left else ""
	_overlay.show_tiles(hints, left, count)
