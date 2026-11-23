extends Node
## Global economy simulation. All four scenes keep running whether or not they are on screen.

signal growth_changed(biome: String)
signal inventory_changed
signal stats_changed
signal machines_changed(biome: String)
signal machine_cycled(uid: int)
signal orders_changed
signal weather_changed(biome: String)
signal toast(text: String, color: Color)

const SAVE_PATH: String = "user://neo_currency_save.json"
const TUTORIAL_SEED := 2026
const START_MONEY: int = 400
const ENERGY_CAP_BASE: float = 400.0

# The two decision windows expire into their default branch. A manual addition
# branches immediately and starts the full timer for the next phase.
const GROWTH_PHASES := {
	"phase1":   {"duration": 5.0,  "timeout": "phase2_1", "add": "phase2_2"},
	"phase2_1": {"duration": 10.0, "machine": "propagator"},
	"phase2_2": {"duration": 10.0, "timeout": "phase3_1", "add": "phase3_2"},
	"phase3_1": {"duration": 10.0, "machine": "collector"},
	"phase3_2": {"duration": 10.0, "machine": "extractor"},
}

var running: bool = false
var tutorial_session := false
var paused: bool = false
var time_scale: float = 1.0
var game_time: float = 0.0
var seed_value: int = 0

var money: int = 0
var reputation: int = 0
var inventory: Dictionary = {}
var eternity_records: Dictionary = {}
var life_growth: Dictionary = {}
var energy: float = 0.0
var energy_cap: float = ENERGY_CAP_BASE
var energy_in_rate: float = 0.0
var energy_out_rate: float = 0.0
var power_ratio: float = 1.0
var machines: Dictionary = {}     # uid -> Dictionary
var next_uid: int = 1
var orders: Array = []
var weather: Dictionary = {}      # biome -> {"effect": id, "remaining": t}
var weather_timer: Dictionary = {}
var delivered: int = 0
var _rng := RandomNumberGenerator.new()
var _rate_time: float = 0.0

func _ready() -> void:
	Land.binding_expired.connect(_on_binding_expired)
	Land.tide_finished.connect(_on_tide_finished)
	Land.riverbed_flooded.connect(_on_riverbed_flooded)

# ================================================================ lifecycle
func start_tutorial() -> void:
	new_game(TUTORIAL_SEED, true)

func new_game(seed_in: int, tutorial: bool = false) -> void:
	tutorial_session = tutorial
	seed_value = seed_in
	eternity_records.clear()
	life_growth.clear()
	_rng.seed = hash("sim|%d" % seed_in)
	Land.generate(seed_in)
	money = Settings.starting_money
	reputation = 0
	inventory = {"life": 10, "ember": 10, "timber": 12, "water": 6, "sand": 6, "iron_ore": 4, "charcoal": 2}
	energy = Settings.starting_energy
	energy_cap = ENERGY_CAP_BASE
	machines.clear()
	next_uid = 1
	orders.clear()
	weather.clear()
	weather_timer.clear()
	for b: String in Data.biome_order:
		weather_timer[b] = _rng.randf_range(50.0, 110.0)
	delivered = 0
	game_time = 0.0
	paused = false
	time_scale = 1.0
	_fill_orders()
	running = true
	_emit_all()

func _emit_all() -> void:
	inventory_changed.emit()
	stats_changed.emit()
	orders_changed.emit()
	for b: String in Data.biome_order:
		machines_changed.emit(b)
		weather_changed.emit(b)

# ================================================================ helpers
func count(item: String) -> int:
	return int(inventory.get(item, 0))

func has_items(needs: Dictionary, times: int = 1) -> bool:
	for id: String in needs:
		if count(id) < int(needs[id]) * times: return false
	return true

func take_items(needs: Dictionary) -> void:
	for id: String in needs:
		inventory[id] = count(id) - int(needs[id])
		if int(inventory[id]) <= 0: inventory.erase(id)
	inventory_changed.emit()

func give_items(items_in: Dictionary) -> void:
	for id: String in items_in:
		inventory[id] = count(id) + int(items_in[id])
	inventory_changed.emit()

func is_unlocked(machine_id: String) -> bool:
	return Data.machines.has(machine_id) and reputation >= int(Data.machines[machine_id].get("unlock_rep", 0))

func machine_at(biome: String, cell: Vector2i) -> Dictionary:
	for m: Dictionary in machines.values():
		if m.biome == biome and m.cell == cell: return m
	return {}

func machines_in(biome: String) -> Array:
	return machines.values().filter(func(m: Dictionary) -> bool: return m.biome == biome)

func machine_stats(m: Dictionary) -> Dictionary:
	return StatMath.machine_stats(m.type, Land.get_parcel(m.biome, m.cell))

func recipe_of(m: Dictionary) -> Dictionary:
	var recipes: Array = Data.machines[m.type].get("recipes", [])
	if recipes.is_empty(): return {}
	return recipes[clampi(int(m.recipe), 0, recipes.size() - 1)]

func repair_cost(m: Dictionary) -> int:
	return 8 + int(float(Data.machines[m.type].cost) * 0.12)

# ================================================================ commands
## Returns "" on success or the reason it cannot be placed.
func can_place(machine_id: String, biome: String, cell: Vector2i) -> String:
	return tr("Plant Life on a plot to grow a machine")

func growth_at(biome: String, cell: Vector2i) -> Dictionary:
	return life_growth.get(Land.parcel_key(biome,cell), {})

func can_add_life(biome: String, cell: Vector2i) -> String:
	if not Data.biomes.has(biome) or not Land.in_grid(cell): return tr("Choose a plot")
	if not machine_at(biome, cell).is_empty(): return tr("This plot already has a machine")
	var g := growth_at(biome, cell)
	var sheet: Dictionary = Land.get_parcel(biome, cell).sheet
	if int(sheet.get("support", 0)) < 1: return tr("Requires ground support %d") % 1
	if g.is_empty():
		if int(sheet.get("adaptation", [1, 1])[0]) == 0:
			return tr("Life cannot take root here")
	else:
		if not GROWTH_PHASES[g.stage].has("add"): return tr("Growth branch already chosen")
		var target: String = GROWTH_PHASES[GROWTH_PHASES[g.stage].add].get("machine", "")
		if target != "":
			var reason := machine_site_reason(target, biome, cell)
			if reason != "": return reason
	if count("life") < 1: return tr("Not enough Life points")
	return ""

func _enter_growth_phase(g: Dictionary, phase: String) -> void:
	var rule: Dictionary = GROWTH_PHASES[phase]
	g.stage = phase
	g.remaining = rule.duration
	g.machine = rule.get("machine", "")
	g.erase("blocked")

func add_life_point(biome: String, cell: Vector2i) -> String:
	var reason := can_add_life(biome, cell)
	if reason != "": return reason
	var g := growth_at(biome, cell)
	if g.is_empty():
		g = {"biome": biome, "cell": [cell.x, cell.y]}
		_enter_growth_phase(g, "phase1")
		life_growth[Land.parcel_key(biome, cell)] = g
	else:
		_enter_growth_phase(g, GROWTH_PHASES[g.stage].add)
	take_items({"life": 1})
	growth_changed.emit(biome)
	return ""

func _tick_life_growth(dt: float, growth_holds: Dictionary = {}) -> void:
	if dt < 0.0: return
	for key: String in life_growth.keys():
		var g: Dictionary = life_growth[key]
		var budget := maxf(0.0, dt - float(growth_holds.get(key, 0.0)))
		while true:
			var remaining: float = g.remaining
			if remaining - budget > 0.000000001:
				g.remaining = remaining - budget
				break
			budget = maxf(0.0, budget - remaining)
			var rule: Dictionary = GROWTH_PHASES[g.stage]
			if rule.has("timeout"):
				_enter_growth_phase(g, rule.timeout)
				growth_changed.emit(g.biome)
				continue
			var cell := Vector2i(int(g.cell[0]), int(g.cell[1]))
			var blocked := machine_site_reason(g.machine, g.biome, cell)
			if not machine_at(g.biome, cell).is_empty(): blocked = tr("This plot already has a machine")
			if blocked != "":
				g.remaining = 0.0
				if g.get("blocked", "") != blocked:
					g.blocked = blocked
					growth_changed.emit(g.biome)
				break
			life_growth.erase(key)
			var m := _make_machine(g.machine, g.biome, cell, next_uid)
			next_uid += 1
			machines[m.uid] = m
			_bind_aura(m)
			machines_changed.emit(g.biome)
			growth_changed.emit(g.biome)
			break

func growth_text(g: Dictionary) -> String:
	var remaining := float(g.get("remaining", 0.0))
	if g.has("blocked"):
		return tr("%s ready · waiting for site\n%s") % [Data.machines[g.machine].name, g.blocked]
	match str(g.get("stage", "")):
		"phase1": return tr("Phase 1 · %.1fs left\nWait for 2-1, or add 1 Life for 2-2") % remaining
		"phase2_2": return tr("Phase 2-2 · %.1fs left\nWait for 3-1, or add 1 Life for 3-2") % remaining
	if Data.machines.has(g.get("machine", "")):
		return tr("Growing %s · %.1fs left") % [Data.machines[g.machine].name, remaining]
	return ""

func restore_life_growth(saved: Dictionary) -> void:
	life_growth.clear()
	for raw: Variant in saved.values():
		if not raw is Dictionary: continue
		var biome := str(raw.get("biome", ""))
		var coords: Variant = raw.get("cell", [])
		if not Data.biomes.has(biome) or not coords is Array or coords.size() != 2: continue
		var cell := Vector2i(int(coords[0]), int(coords[1]))
		if not Land.in_grid(cell) or not machine_at(biome, cell).is_empty(): continue
		var phase := str(raw.get("stage", ""))
		var seconds := float(raw.get("remaining", 0.0))
		# In the first save format, stage1/stage2/mature each held one Life;
		# both partially grown machine routes had already consumed a second.
		match phase:
			"stage1": phase = "phase1"
			"stage2": phase = "phase2_1"
			"mature":
				phase = "phase2_1"
				seconds = 0.0
			"machine":
				if raw.get("machine", "") not in ["pitcher_still", "leafwing_turbine"]: continue
				phase = "phase3_1"
		if not GROWTH_PHASES.has(phase): continue
		var g := {"biome": biome, "cell": [cell.x, cell.y]}
		_enter_growth_phase(g, phase)
		g.remaining = clampf(seconds, 0.0, float(g.remaining))
		life_growth[Land.parcel_key(biome, cell)] = g
	_tick_life_growth(0.0)

func place_machine(machine_id: String, biome: String, cell: Vector2i) -> String:
	return can_place(machine_id,biome,cell)

func _make_machine(machine_id: String, biome: String, cell: Vector2i, uid: int) -> Dictionary:
	return {"uid": uid, "type": machine_id, "biome": biome, "cell": cell, "recipe": 0,
		"progress": 0.0, "started": false, "wear": 0.0, "jammed": false, "enabled": true,
		"status": tr("Idle"), "carry": {}, "cycles": 0}

func _bind_aura(m: Dictionary) -> void:
	var aura: String = str(Data.machines[m.type].get("aura", ""))
	if aura != "":
		Land.bind_effect(aura, m.biome, m.cell, int(Data.effects[aura].get("radius", 1)), "machine", "machine:%d" % m.uid, -1.0)

func remove_machine(uid: int) -> void:
	if not machines.has(uid): return
	var m: Dictionary = machines[uid]
	var def: Dictionary = Data.machines[m.type]
	if m.started: give_items(recipe_of(m).get("inputs", {}))
	money += int(def.cost) / 2
	Land.unbind_source("machine:%d" % uid)
	machines.erase(uid)
	toast.emit(tr("Dismantled %s (+¤%d)") % [def.name, int(def.cost) / 2], Color("d9c9a0"))
	stats_changed.emit()
	machines_changed.emit(m.biome)

func repair(uid: int) -> bool:
	if not machines.has(uid): return false
	var m: Dictionary = machines[uid]
	var c: int = repair_cost(m)
	if money < c:
		toast.emit(tr("Repair needs ¤%d") % c, Color("e88a6a"))
		return false
	money -= c
	m.wear = 0.0
	m.jammed = false
	stats_changed.emit()
	machines_changed.emit(m.biome)
	return true

func cycle_recipe(uid: int, step: int = 1) -> void:
	if not machines.has(uid): return
	var m: Dictionary = machines[uid]
	var recipes: Array = Data.machines[m.type].get("recipes", [])
	if recipes.size() < 2: return
	if m.started: give_items(recipe_of(m).get("inputs", {}))
	m.recipe = posmod(int(m.recipe) + step, recipes.size())
	m.progress = 0.0
	m.started = false
	machines_changed.emit(m.biome)

func toggle_enabled(uid: int) -> void:
	if machines.has(uid):
		machines[uid].enabled = not machines[uid].enabled
		machines_changed.emit(machines[uid].biome)

func deliver(index: int) -> bool:
	if index < 0 or index >= orders.size(): return false
	var o: Dictionary = orders[index]
	var t: Dictionary = _order_template(o.id)
	if not has_items(t.needs):
		toast.emit(tr("Not enough goods for %s") % t.name, Color("e88a6a"))
		return false
	take_items(t.needs)
	money += int(t.reward)
	reputation += int(t.rep)
	delivered += 1
	orders.remove_at(index)
	toast.emit(tr("%s paid ¤%d  +%d rep") % [t.customer, int(t.reward), int(t.rep)], Color("f2d27a"))
	for id: String in Data.machine_order:
		if int(Data.machines[id].get("unlock_rep", 0)) > reputation - int(t.rep) and is_unlocked(id):
			toast.emit(tr("New machine: %s") % Data.machines[id].name, Color("b8e08a"))
	_fill_orders()
	stats_changed.emit()
	orders_changed.emit()
	return true

func _order_template(id: String) -> Dictionary:
	for t: Dictionary in Data.orders:
		if t.id == id: return t
	return {}

func _can_supply_order(template: Dictionary) -> bool:
	for item: String in template.needs:
		if item not in ["life", "ember"] and count(item) < int(template.needs[item]):
			return false
	return true

func _fill_orders() -> void:
	var guard: int = 0
	while orders.size() < Data.order_slots and guard < 50:
		guard += 1
		var open_ids: Array = orders.map(func(o: Dictionary) -> String: return o.id)
		var pool: Array = Data.orders.filter(func(t: Dictionary) -> bool: return int(t.min_rep) <= reputation and not open_ids.has(t.id) and _can_supply_order(t))
		if pool.is_empty(): break
		# Prefer the newest tier a little so progression shows up.
		var t: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		orders.append({"id": t.id, "remaining": float(t.time)})

# ================================================================ tick
func _process(delta: float) -> void:
	if not running or paused: return
	step(delta * time_scale)

func step(dt: float, growth_holds: Dictionary = {}) -> void:
	game_time += dt
	Land.tick(dt)
	_tick_weather(dt)
	_tick_orders(dt)
	_tick_machines(dt)
	_tick_life_growth(dt, growth_holds)

func _tick_orders(dt: float) -> void:
	var changed: bool = false
	for i in range(orders.size() - 1, -1, -1):
		orders[i].remaining = float(orders[i].remaining) - dt
		if float(orders[i].remaining) <= 0.0:
			toast.emit(tr("Order expired: %s") % _order_template(orders[i].id).get("name", "?"), Color("a89a8a"))
			orders.remove_at(i)
			changed = true
	if changed:
		_fill_orders()
		orders_changed.emit()

func _tick_weather(dt: float) -> void:
	for b: String in Data.biome_order:
		if weather.has(b):
			weather[b].remaining = float(weather[b].remaining) - dt
			continue
		weather_timer[b] = float(weather_timer.get(b, 90.0)) - dt
		if float(weather_timer[b]) <= 0.0:
			var options: Array = Data.biomes[b].get("weather", [])
			if options.is_empty(): continue
			var eff: String = str(options[_rng.randi_range(0, options.size() - 1)])
			start_weather(b, eff, float(Data.effects[eff].get("duration", 45)))

func start_weather(biome: String, eff: String, duration: float) -> void:
	Land.unbind_source("weather:" + biome)
	Land.bind_effect(eff, biome, Vector2i(5, 5), -1, "weather", "weather:" + biome, duration)
	weather[biome] = {"effect": eff, "remaining": duration}
	toast.emit("%s: %s" % [Data.biome_name(biome), Data.effects[eff].name], Color(str(Data.effects[eff].color)))
	weather_changed.emit(biome)

func _on_binding_expired(b: Dictionary) -> void:
	if b.source == "weather":
		weather.erase(b.biome)
		weather_timer[b.biome] = _rng.randf_range(80.0, 150.0)
		weather_changed.emit(b.biome)

func machine_site_reason(id: String, biome: String, cell: Vector2i) -> String:
	var p := Land.get_parcel(biome, cell)
	var def: Dictionary = Data.machines.get(id, {})
	if p.is_empty() or def.is_empty(): return tr("Invalid machine site")
	if int(p.sheet.get("support", 0)) < int(def.support):
		return tr("Requires ground support %d") % int(def.support)
	if def.has("site_life_min") and int(p.life_concentration) < int(def.site_life_min):
		return tr("Requires Life concentration of at least %d") % int(def.site_life_min)
	return ""

func _on_riverbed_flooded(biome: String, cell: Vector2i) -> void:
	var m := machine_at(biome, cell)
	if not m.is_empty():
		machines.erase(m.uid)
		machines_changed.emit(biome)

func _has_working_plot(biome: String, neighbors: Array[Vector2i]) -> bool:
	for cell in neighbors:
		if int(Land.get_parcel(biome, cell).life_concentration) >= 0: return true
	return false

func _tick_machines(dt: float) -> void:
	var wave_active := not Land.tide_state.is_empty()
	for m: Dictionary in machines.values():
		var neighbors := Land.machine_neighbors(m.cell, Data.machines[m.type].area)
		if not m.enabled:
			m.status = tr("Paused")
		elif not _has_working_plot(m.biome, neighbors):
			m.status = tr("No plot in range has nonnegative Life concentration")
		else:
			m.status = tr("Working") if wave_active else tr("Waiting for tide")
		m.progress = (float(Land.tide_state.get("row", 0)) / Land.GRID) if wave_active and m.enabled else 0.0
	_rate_time += dt
	if _rate_time >= 1.0:
		_rate_time = 0.0
		stats_changed.emit()

func _on_tide_finished() -> void:
	# Resolve all seeding before reading the collectors' totals. Extractors
	# sharing plots draw in UID order, including after restoring a save.
	var ids: Array = machines.keys()
	ids.sort()
	var changed: Dictionary = {}
	for type: String in ["propagator", "collector", "extractor"]:
		var def: Dictionary = Data.machines[type]
		for uid: int in ids:
			var m: Dictionary = machines[uid]
			if m.type != type: continue
			m.last_output = {}
			if not m.enabled: continue
			var neighbors := Land.machine_neighbors(m.cell, def.area)
			if not _has_working_plot(m.biome, neighbors): continue
			match type:
				"propagator":
					for cell in neighbors: Land.seed_plot(m.biome, cell)
					m.cycles = int(m.cycles) + neighbors.size()
				"collector":
					var concentration := 0
					for cell in neighbors:
						concentration += int(Land.get_parcel(m.biome, cell).life_concentration)
					_credit_tide_output(m, "life", floori(maxi(0, concentration) / 8.0))
				"extractor":
					var extracted := int(m.carry.get("concentration", 0))
					for cell in neighbors:
						if int(Land.get_parcel(m.biome, cell).life_concentration) > 0:
							Land.change_concentration(m.biome, cell, -1)
							extracted += 1
					m.carry.concentration = extracted % 8
					_credit_tide_output(m, "liquid_energy_canister", floori(extracted / 8.0))
			changed[m.biome] = true
			machine_cycled.emit(uid)
	for biome: String in changed: machines_changed.emit(biome)

func _credit_tide_output(m: Dictionary, item: String, quantity: int) -> void:
	if quantity <= 0: return
	m.cycles = int(m.cycles) + quantity
	m.last_output = {item: quantity}
	give_items(m.last_output)

# ================================================================ save / load
func save_game(path: String = SAVE_PATH) -> bool:
	if tutorial_session: return false
	var ms: Array = []
	for m: Dictionary in machines.values():
		ms.append({"uid": m.uid, "type": m.type, "biome": m.biome, "cell": [m.cell.x, m.cell.y], "recipe": m.recipe,
			"progress": m.progress, "started": m.started, "wear": m.wear, "jammed": m.jammed, "enabled": m.enabled,
			"carry": m.carry, "cycles": m.cycles, "last_output": m.get("last_output", {})})
	var data: Dictionary = {"version": 3, "seed": seed_value, "terrain_generator": Land.generation_version,
		"time": game_time, "money": money, "reputation": reputation,
		"life_growth": life_growth, "inventory": inventory, "energy": energy, "machines": ms, "next_uid": next_uid, "orders": orders,
		"weather": weather, "weather_timer": weather_timer, "weather_bindings": Land.save_bindings(), "delivered": delivered,
		"energy_offsets": Land.energy_offsets, "eternity_records": eternity_records,
		"terrain_overrides": Land.terrain_overrides, "tide_state": Land.tide_state,
		"tide_elapsed": Land.tide_elapsed, "tide_count": Land.tide_count,
		"cleared_attachments": Land.cleared, "rng_state": str(_rng.state)}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	toast.emit(tr("Game saved"), Color("b8e08a"))
	return true

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game(path: String = SAVE_PATH) -> bool:
	if tutorial_session: return false
	if not FileAccess.file_exists(path): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return false
	var d: Dictionary = parsed
	seed_value = int(d.get("seed", 0))
	Land.generate(seed_value, int(d.get("terrain_generator", 1)))
	Land.energy_offsets = d.get("energy_offsets", {})
	eternity_records = d.get("eternity_records", {})
	for record: Dictionary in eternity_records.values():
		var recorded: Dictionary = record.get("machine", {})
		if not Data.machines.has(recorded.get("type", "")): record.machine = {}
	Land.restore_terrain(d.get("terrain_overrides", {}))
	Land.tide_state = d.get("tide_state", {})
	Land.tide_elapsed = float(d.get("tide_elapsed", 0.0))
	Land.tide_count = int(d.get("tide_count", 0))
	Land.cleared = d.get("cleared_attachments", {})
	Land._cache.clear()
	_rng.seed = hash("sim|%d" % seed_value)
	if d.has("rng_state"): _rng.state = int(str(d.rng_state))
	game_time = float(d.get("time", 0.0))
	money = int(d.get("money", START_MONEY))
	reputation = int(d.get("reputation", 0))
	inventory = {}
	for k: String in d.get("inventory", {}): inventory[k] = int(d.inventory[k])
	energy = float(d.get("energy", 0.0))
	energy_cap = ENERGY_CAP_BASE
	machines.clear()
	next_uid = maxi(1, int(d.get("next_uid", 1)))
	for raw: Dictionary in d.get("machines", []):
		if not Data.machines.has(raw.get("type", "")) or not Data.biomes.has(raw.get("biome", "")): continue
		var coords: Variant = raw.get("cell", [])
		if not coords is Array or coords.size() != 2: continue
		var cell := Vector2i(int(coords[0]), int(coords[1]))
		var uid := int(raw.get("uid", 0))
		if not Land.in_grid(cell) or uid < 1 or machines.has(uid) or not machine_at(raw.biome, cell).is_empty(): continue
		var m := _make_machine(raw.type, raw.biome, cell, uid)
		next_uid = maxi(next_uid, uid + 1)
		for k: String in ["recipe", "progress", "started", "wear", "jammed", "enabled", "carry", "cycles", "last_output"]:
			if raw.has(k): m[k] = raw[k]
		m.recipe = int(m.recipe)
		machines[m.uid] = m
		_bind_aura(m)
	orders.clear()
	for order: Dictionary in d.get("orders", []):
		if not _order_template(str(order.get("id", ""))).is_empty(): orders.append(order)
	_fill_orders()
	weather = d.get("weather", {})
	weather_timer = d.get("weather_timer", {})
	for wb: Dictionary in d.get("weather_bindings", []):
		if not Data.biomes.has(wb.get("biome", "")) or wb.get("source_id", "") != "weather:" + str(wb.biome): continue
		Land.bind_effect(str(wb.effect), str(wb.biome), Vector2i(5, 5), -1, "weather", str(wb.source_id), float(wb.remaining))
	delivered = int(d.get("delivered", 0))
	paused = false
	time_scale = 1.0
	restore_life_growth(d.get("life_growth", {}))
	running = true
	_emit_all()
	return true

func condense(biome: String, cell: Vector2i, kind: String) -> void:
	if kind not in ["life", "ember"]: return
	var parcel: Dictionary = Land.get_parcel(biome, cell)
	if float(parcel.elements[kind]) < 20.0: return
	var key: String = Land.parcel_key(biome, cell)
	var offsets: Dictionary = Land.energy_offsets.get(key, {}).duplicate()
	offsets[kind] = float(offsets.get(kind, 0)) - 20.0
	Land.energy_offsets[key] = offsets
	Land._invalidate(biome)
	give_items({kind: 1})

func record_eternity(biome: String, cell: Vector2i) -> void:
	var p: Dictionary = Land.get_parcel(biome, cell)
	if float(p.elements.eternity) <= 0: return
	var machine: Dictionary = machine_at(biome, cell).duplicate(true)
	if not machine.is_empty(): machine.cell = [cell.x, cell.y]
	var key: String = Land.parcel_key(biome, cell)
	var base: Dictionary = Land._base[biome][cell.y * Land.GRID + cell.x].duplicate(true)
	base.cell = [cell.x, cell.y]
	eternity_records[key] = {"base": base, "land": p.land, "cleared": p.attachment_cleared, "machine": machine, "offsets": Land.energy_offsets.get(key, {}).duplicate(true)}
	toast.emit("永恒已记录地块、附着物、自然能量与机械组成", UITheme.GOOD)

func reshape_eternity(biome: String, cell: Vector2i) -> void:
	var key: String = Land.parcel_key(biome, cell)
	if not eternity_records.has(key) or float(Land.get_parcel(biome, cell).elements.eternity) <= 0: return
	var saved: Dictionary = eternity_records[key]
	var current: Dictionary = machine_at(biome, cell)
	var machine: Dictionary = saved.get("machine", {}).duplicate(true)
	if not Data.machines.has(machine.get("type", "")): machine = {}
	if not machine.is_empty() and (current.is_empty() or current.type != machine.type):
		var def: Dictionary = Data.machines[machine.type]
		if money < int(def.cost) or not has_items(def.get("materials", {})):
			toast.emit("重塑所需资金或组成材料不足", UITheme.BAD)
			return
		money -= int(def.cost)
		take_items(def.get("materials", {}))
	if not current.is_empty():
		Land.unbind_source("machine:%d" % int(current.uid))
		machines.erase(current.uid)
	if saved.has("base"):
		var base: Dictionary = saved.base.duplicate(true)
		base.cell = cell
		Land._base[biome][cell.y * Land.GRID + cell.x] = base
	else: Land._base[biome][cell.y * Land.GRID + cell.x].land = saved.land
	Land.terrain_overrides[key] = saved.land
	Land.energy_offsets[key] = saved.offsets.duplicate(true)
	if saved.cleared: Land.cleared[key] = true
	else: Land.cleared.erase(key)
	if not machine.is_empty():
		life_growth.erase(key)
		machine.uid = next_uid
		next_uid += 1
		machine.cell = cell
		machines[machine.uid] = machine
		_bind_aura(machine)
	Land._invalidate(biome)
	Land.tide_tile_transformed.emit(biome, cell, "", str(saved.land), 0)
	_emit_all()
	toast.emit("永恒已按记录完整重塑", UITheme.GOOD)
