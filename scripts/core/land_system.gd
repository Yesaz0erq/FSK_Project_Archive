extends Node
## The land system: parcel attributes, land types, seed generation and effect binding.
##
## * Land type   - data/land_types.json. Every parcel inherits its type's base values.
## * Seed        - generate(seed) builds every biome's 11x11 parcels deterministically
##                 (land regions, small value jitter, resource deposits, natural effects).
## * Effects     - bind_effect() attaches an effect to a center parcel with a radius
##                 (or a whole biome with radius -1). Sources: seed / machine / weather.
## * Attributes  - get_parcel() combines type base + jitter + bound effects into the
##                 parcel's current four elements, temperature class and attributes.

signal tide_tile_changed(biome: String, cell: Vector2i, old_land: String, new_land: String, edge: int)
signal tide_tile_transformed(biome: String, cell: Vector2i, old_land: String, new_land: String, edge: int)
signal tide_started(edge: int)
signal tide_finished
signal riverbed_flooded(biome: String, cell: Vector2i)
signal parcels_changed(biome: String)
signal binding_expired(binding: Dictionary)

const GRID: int = 11
const JITTER: int = 7

var world_seed: int = 0
var cleared: Dictionary = {}
var terrain_overrides: Dictionary = {}
var energy_offsets: Dictionary = {}
var tide_state: Dictionary = {}
var tide_elapsed: float = 0.0
var tide_count: int = 0
const TIDE_ROW_SECONDS: float = 0.7
var _base: Dictionary = {}       # biome -> Array[Dictionary] (index = y * GRID + x)
var bindings: Array = []         # Array[Dictionary]
var _next_binding: int = 1
var _cache: Dictionary = {}      # biome -> Array (computed parcels) ; missing = dirty
var river_mouth_columns: Dictionary = {}  # Seed-generated north and south banks, before tides or cultivation.

func generate(seed_value: int) -> void:
	world_seed = seed_value
	cleared.clear()
	terrain_overrides.clear()
	energy_offsets.clear()
	tide_state.clear()
	tide_elapsed = 0.0
	tide_count = 0
	_base.clear()
	bindings.clear()
	_cache.clear()
	_next_binding = 1
	for biome: String in Data.biome_order:
		_generate_biome(biome)
	for biome: String in Data.biome_order:
		parcels_changed.emit(biome)

static func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID

static func machine_neighbors(cell: Vector2i, area: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x == 0 and y == 0: continue
			if area == "adjacent" and x != 0 and y != 0: continue
			var neighbor := cell + Vector2i(x, y)
			if in_grid(neighbor): result.append(neighbor)
	return result

func _rng_for(biome: String, salt: String = "") -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s|%s" % [world_seed, biome, salt])
	return rng

func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: float = 0.0
	for k: String in weights: total += float(weights[k])
	var roll: float = rng.randf() * total
	for k: String in weights:
		roll -= float(weights[k])
		if roll <= 0.0: return k
	return str(weights.keys()[0])

func _generate_biome(biome: String) -> void:
	var def: Dictionary = Data.biomes[biome]
	var rng := _rng_for(biome)
	var weights: Dictionary = def.land_weights
	# 1. Land regions: a warped Voronoi field. Every land type of the biome gets at
	#    least one region, the rest are drawn by weight.
	var points: Array = []
	var guaranteed: Array = weights.keys()
	var count: int = 7 + rng.randi_range(0, 3)
	for i in range(count):
		var land: String = str(guaranteed[i]) if i < guaranteed.size() else _weighted(rng, weights)
		points.append({"pos": Vector2(rng.randf_range(-0.5, GRID - 0.5), rng.randf_range(-0.5, GRID - 0.5)), "land": land, "pull": rng.randf_range(0.8, 1.25)})
	var cells: Array = []
	cells.resize(GRID * GRID)
	for y in range(GRID):
		for x in range(GRID):
			var best: float = INF
			var land_id: String = ""
			var warp := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
			for p: Dictionary in points:
				var d: float = (Vector2(x, y) + warp).distance_to(p.pos) * float(p.pull)
				if d < best:
					best = d
					land_id = p.land
			var jitter: Dictionary = {}
			for e: String in Data.element_ids:
				jitter[e] = rng.randi_range(-JITTER, JITTER) if e in ["life", "ember"] else 0
			cells[y * GRID + x] = {
				"cell": Vector2i(x, y), "land": land_id, "jitter": jitter,
				"richness_jitter": snappedf(rng.randf_range(-0.08, 0.08), 0.01),
				"deposit": "", "variant": rng.randi_range(0, 999)
			}
	# Spreadsheet terrain: connected river, adjoining grass, dry land beyond.
	var river_cells: Dictionary = {}
	var outlets: Array[Vector2i] = []
	var rx: int = 5
	for y in range(GRID):
		var next_x: int = clampi(rx + rng.randi_range(-1, 1), 4, 6)
		if y == 0 or y == GRID - 1: outlets.append(Vector2i(mini(rx, next_x), maxi(rx, next_x)))
		for x in range(mini(rx, next_x), maxi(rx, next_x) + 1): river_cells[Vector2i(x, y)] = true
		rx = next_x
	river_mouth_columns[biome] = outlets
	for y in range(GRID):
		for x in range(GRID):
			var cell := Vector2i(x, y)
			var near_water: bool = false
			for yy in range(maxi(0, y - 1), mini(GRID, y + 2)):
				for xx in range(maxi(0, x - 1), mini(GRID, x + 2)):
					if river_cells.has(Vector2i(xx, yy)): near_water = true
			cells[y * GRID + x].land = "sheet_river" if river_cells.has(cell) else ("sheet_grass" if near_water else "sheet_sand")
	# Isolated oasis is water: convert its neighbours to grass as well.
	var oasis := Vector2i(rng.randi_range(0, 1), rng.randi_range(1, GRID - 2))
	cells[oasis.y * GRID + oasis.x].land = "sheet_oasis"
	for yy in range(maxi(0, oasis.y - 1), mini(GRID, oasis.y + 2)):
		for xx in range(maxi(0, oasis.x - 1), mini(GRID, oasis.x + 2)):
			if Vector2i(xx, yy) != oasis and cells[yy * GRID + xx].land == "sheet_sand": cells[yy * GRID + xx].land = "sheet_grass"
	# 2. Deposits: weighted toward land types that favour the resource.
	for resource: String in def.get("deposits", {}):
		for n in range(int(def.deposits[resource])):
			var cw: Dictionary = {}
			for i in range(cells.size()):
				var c: Dictionary = cells[i]
				if c.deposit != "": continue
				var w: float = float(Data.land_types[c.land].get("resources", {}).get(resource, 0)) + 0.15
				cw[str(i)] = w
			if cw.is_empty(): break
			cells[int(_weighted(rng, cw))].deposit = resource
	_base[biome] = cells
	# 3. Natural effects bound by the seed.
	var natural: Dictionary = def.get("natural_effects", {})
	if not natural.is_empty():
		var n_eff: int = rng.randi_range(3, 4)
		for i in range(n_eff):
			var eff: String = _weighted(rng, natural)
			var center := Vector2i(rng.randi_range(1, GRID - 2), rng.randi_range(1, GRID - 2))
			bind_effect(eff, biome, center, int(Data.effects[eff].get("radius", 1)), "seed", "seed", -1.0)

# ---------------------------------------------------------------- effect binding
func bind_effect(effect_id: String, biome: String, center: Vector2i, radius: int, source: String, source_id: String, duration: float) -> int:
	if not Data.effects.has(effect_id): return -1
	var b: Dictionary = {"id": _next_binding, "effect": effect_id, "biome": biome, "center": center,
		"radius": radius, "source": source, "source_id": source_id, "remaining": duration}
	_next_binding += 1
	bindings.append(b)
	_invalidate(biome)
	return int(b.id)

func unbind_source(source_id: String) -> void:
	var touched: Dictionary = {}
	for i in range(bindings.size() - 1, -1, -1):
		if bindings[i].source_id == source_id:
			touched[bindings[i].biome] = true
			bindings.remove_at(i)
	for biome: String in touched: _invalidate(biome)

func tick(delta: float) -> void:
	_tick_tide(delta)
	var expired: Array = []
	for b: Dictionary in bindings:
		if float(b.remaining) >= 0.0:
			b.remaining = float(b.remaining) - delta
			if float(b.remaining) <= 0.0: expired.append(b)
	for b: Dictionary in expired:
		bindings.erase(b)
		_invalidate(b.biome)
		binding_expired.emit(b)

func covers(b: Dictionary, cell: Vector2i) -> bool:
	if int(b.radius) < 0: return true
	var c: Vector2i = b.center
	return maxi(absi(c.x - cell.x), absi(c.y - cell.y)) <= int(b.radius)

func bindings_in(biome: String) -> Array:
	return bindings.filter(func(b: Dictionary) -> bool: return b.biome == biome)

func _invalidate(biome: String) -> void:
	_cache.erase(biome)
	parcels_changed.emit(biome)

# ---------------------------------------------------------------- parcel attributes
func get_parcel(biome: String, cell: Vector2i) -> Dictionary:
	if not _base.has(biome) or not in_grid(cell): return {}
	if not _cache.has(biome):
		var arr: Array = []
		arr.resize(GRID * GRID)
		_cache[biome] = arr
	var arr2: Array = _cache[biome]
	var idx: int = cell.y * GRID + cell.x
	if arr2[idx] == null:
		arr2[idx] = _compute(biome, _base[biome][idx])
	return arr2[idx]

func _compute(biome: String, base: Dictionary) -> Dictionary:
	var land: Dictionary = Data.land_types[base.land]
	var sheet: Dictionary = land.get("sheet", {})
	var key: String = parcel_key(biome, base.cell)
	var offsets: Dictionary = energy_offsets.get(key, {})
	var correction: Array = sheet.get("correction", [0, 0])
	var life_concentration: int = int(correction[0]) + int(offsets.get("concentration", 0))
	if not cleared.has(key) and sheet.get("presence", "/") == "生灵补正+1":
		life_concentration += 1
	var base_el: Dictionary = {}
	var el: Dictionary = {}
	for e: String in Data.element_ids:
		base_el[e] = clampf(float(land.elements.get(e, 0)) + float(base.jitter.get(e, 0)) + float(offsets.get(e, 0)), 0.0, 100.0)
		el[e] = base_el[e]
	var heat: float = float(land.environment.heat)
	var moisture: float = float(land.environment.moisture)
	var attrs: Dictionary = {
		"richness": float(land.richness) + float(base.richness_jitter),
		"stability": float(land.stability), "conductivity": float(land.conductivity), "fertility": float(land.fertility)}
	var stat_mults: Dictionary = {}
	var effect_list: Array = []
	for b: Dictionary in bindings:
		if b.biome != biome or not covers(b, base.cell): continue
		var eff: Dictionary = Data.effects[b.effect]
		heat += float(eff.get("environment", {}).get("heat", 0))
		moisture += float(eff.get("environment", {}).get("moisture", 0))
		for e: String in eff.get("elements", {}): el[e] = float(el[e]) + float(eff.elements[e])
		for s: String in eff.get("stats", {}): stat_mults[s] = float(stat_mults.get(s, 1.0)) * float(eff.stats[s])
		for a: String in eff.get("parcel", {}): attrs[a] = float(attrs.get(a, 0.0)) + float(eff.parcel[a])
		effect_list.append({"effect": b.effect, "name": eff.name, "source": b.source, "remaining": b.remaining, "color": eff.get("color", "#ffffff")})
	for e: String in Data.element_ids: el[e] = clampf(float(el[e]), 0.0, 100.0)
	attrs.stability = clampf(attrs.stability, 0.0, 1.0)
	attrs.fertility = clampf(attrs.fertility, 0.0, 1.5)
	attrs.conductivity = maxf(attrs.conductivity, 0.3)
	attrs.richness = maxf(attrs.richness, 0.2)
	return {
		"biome": biome, "cell": base.cell, "land": base.land, "land_name": land.name,
		"land_color": Color(str(land.color)), "height": float(land.get("height", 0.0)), "variant": base.variant,
		"heat": heat, "moisture": moisture,
		"sheet": sheet, "attachment_cleared": cleared.has(key),
		"life_concentration": life_concentration, "stabilized": bool(offsets.get("stabilized", false)),
		"base_elements": base_el, "elements": el,
		"base_temperature": Data.temperature_class(float(land.environment.heat), float(land.environment.moisture)),
		"temperature": Data.temperature_class(heat, moisture),
		"richness": attrs.richness, "stability": attrs.stability, "conductivity": attrs.conductivity, "fertility": attrs.fertility,
		"deposit": base.deposit, "effects": effect_list, "stat_mults": stat_mults
	}

# ---------------------------------------------------------------- save helpers
func save_bindings() -> Array:
	var out: Array = []
	for b: Dictionary in bindings:
		if b.source == "weather":
			out.append({"effect": b.effect, "biome": b.biome, "remaining": b.remaining, "source_id": b.source_id})
	return out

func parcel_key(biome: String, cell: Vector2i) -> String:
	return "%s:%d:%d" % [biome, cell.x, cell.y]

func change_concentration(biome: String, cell: Vector2i, amount: int, stabilize: bool = false) -> void:
	var key: String = parcel_key(biome, cell)
	var offsets: Dictionary = energy_offsets.get(key, {})
	offsets["concentration"] = int(offsets.get("concentration", 0)) + amount
	if stabilize: offsets["stabilized"] = true
	energy_offsets[key] = offsets
	_invalidate(biome)

func seed_plot(biome: String, cell: Vector2i) -> void:
	var p: Dictionary = get_parcel(biome, cell)
	if p.land != "sheet_grass":
		_replace_land(biome, cell, "sheet_grass", false, 0)
	change_concentration(biome, cell, 1, true)

func clear_attachment(biome: String, cell: Vector2i) -> void:
	var p: Dictionary = get_parcel(biome, cell)
	if p.is_empty() or p.attachment_cleared: return
	var attachment: String = str(p.sheet.get("attachment", "/"))
	if attachment == "/": return
	cleared[parcel_key(biome, cell)] = true
	if attachment == "矮灌木": Sim.give_items({"life": 1})
	_invalidate(biome)

func life_cost(biome: String, cell: Vector2i) -> int:
	var p: Dictionary = get_parcel(biome, cell)
	var rule: Dictionary = p.get("sheet", {})
	var correction: Array = rule.get("correction", [0, 0])
	var discount: int = 0
	if str(rule.get("attachment", "/")) != "/":
		if not p.attachment_cleared or str(rule.attachment) == "矮草丛": discount = 1
	return maxi(0, 1 - int(correction[0]) - discount)

# Edges: west, east, north, south. One front crosses every biome.
func start_tide() -> void:
	if not tide_state.is_empty(): return
	var rng := _rng_for("tide", str(tide_count))
	tide_count += 1
	tide_elapsed = 0.0
	var edge: int = rng.randi_range(0, 3)
	tide_state = {"edge": edge, "row": 0, "elapsed": 0.0, "flow": 1 if tide_count % 2 == 1 else -1}
	tide_started.emit(edge)

func _tick_tide(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0:
		if tide_state.is_empty():
			if Settings.tide_seconds <= 0.0: return
			var until_tide := maxf(0.0, Settings.tide_seconds - tide_elapsed)
			if remaining < until_tide:
				tide_elapsed += remaining
				return
			remaining -= until_tide
			start_tide()
		var until_row := maxf(0.0, TIDE_ROW_SECONDS - float(tide_state.elapsed))
		if remaining + 0.000000001 < until_row:
			tide_state.elapsed = float(tide_state.elapsed) + remaining
			tide_elapsed += remaining
			return
		remaining = maxf(0.0, remaining - until_row)
		tide_elapsed += until_row
		tide_state.elapsed = 0.0
		var row: int = int(tide_state.row)
		var edge: int = int(tide_state.edge)
		for b: String in Data.biome_order:
			for i in range(GRID):
				var cell := Vector2i(row if edge == 0 else GRID - 1 - row, i) if edge < 2 else Vector2i(i, row if edge == 2 else GRID - 1 - row)
				_tide_replace(b, cell, edge)
		tide_state.row = row + 1
		if int(tide_state.row) >= GRID:
			tide_state.clear()
			_water_oasis_neighbors(edge)
			tide_finished.emit()

# Resolve oasis conversions after the last row so their outcome is identical
# for eastbound and westbound tides.
func _water_oasis_neighbors(edge: int) -> void:
	for biome: String in Data.biome_order:
		for base: Dictionary in _base[biome]:
			if base.land != "sheet_oasis": continue
			for cell in machine_neighbors(base.cell, "adjacent"):
				var p: Dictionary = get_parcel(biome, cell)
				if p.sheet.get("base", "") == "土地" and p.land != "sheet_grass" and not p.stabilized:
					_replace_land(biome, cell, "sheet_grass", false, edge)

func _tide_replace(biome: String, cell: Vector2i, edge: int) -> void:
	var base: Dictionary = _base[biome][cell.y * GRID + cell.x]
	var old_id: String = str(base.land)
	var rule: Dictionary = Data.land_types[old_id].get("sheet", {})
	var key: String = parcel_key(biome, cell)
	var flow: float = float(tide_state.get("flow", 1))
	var offsets: Dictionary = energy_offsets.get(key, {}).duplicate()
	for energy_id: String in ["life", "ember"]:
		var current: float = float(get_parcel(biome, cell).elements[energy_id])
		offsets[energy_id] = float(offsets.get(energy_id, 0)) + clampf(current + flow * 10.0, 0, 100) - current
	offsets["concentration"] = int(offsets.get("concentration", 0)) + 1
	energy_offsets[key] = offsets
	_invalidate(biome)
	if old_id == "sheet_riverbed":
		clear_attachment(biome, cell)
		riverbed_flooded.emit(biome, cell)
	if bool(offsets.get("stabilized", false)): return
	var mode: String = str(rule.get("tide", "/"))
	var next_id: String = ""
	if mode == "翻转":
		next_id = str(rule.get("flip_to", ""))
		if not Data.land_types.has(next_id): return
		if Data.land_types[next_id].get("sheet", {}).get("flip_to", "") != old_id: return
	elif mode == "转变":
		var candidates: Array[String] = []
		for id: String in Data.land_types:
			var candidate: Dictionary = Data.land_types[id].get("sheet", {})
			if id != old_id and candidate.get("base", "") == rule.base and str(candidate.get("level", "/")) == str(rule.level): candidates.append(id)
		if candidates.is_empty(): return
		var rng := _rng_for(biome, "tide:%d:%d:%d" % [tide_count, cell.x, cell.y])
		next_id = candidates[rng.randi_range(0, candidates.size() - 1)]
	else: return
	_replace_land(biome, cell, next_id, mode == "翻转", edge)

func _replace_land(biome: String, cell: Vector2i, next_id: String, flip: bool, edge: int) -> void:
	var base: Dictionary = _base[biome][cell.y * GRID + cell.x]
	var old_id: String = base.land
	if old_id == next_id: return
	clear_attachment(biome, cell)
	var key: String = parcel_key(biome, cell)
	cleared.erase(key)
	base.land = next_id
	terrain_overrides[key] = next_id
	_invalidate(biome)
	if flip: tide_tile_changed.emit(biome, cell, old_id, next_id, edge)
	else: tide_tile_transformed.emit(biome, cell, old_id, next_id, edge)

func restore_terrain(saved: Dictionary) -> void:
	terrain_overrides = saved.duplicate()
	for b: String in Data.biome_order:
		for y in range(GRID):
			for x in range(GRID):
				var key: String = parcel_key(b, Vector2i(x, y))
				var id: String = str(saved.get(key, ""))
				if Data.land_types.has(id): _base[b][y * GRID + x].land = id
		_cache.erase(b)
