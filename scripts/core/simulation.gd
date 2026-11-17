extends Node
## Global economy simulation. All four scenes keep running whether or not they are on screen.

signal inventory_changed
signal stats_changed
signal machines_changed(biome: String)
signal machine_cycled(uid: int)
signal orders_changed
signal weather_changed(biome: String)
signal toast(text: String, color: Color)

const SAVE_PATH: String = "user://neo_currency_save.json"
const START_MONEY: int = 400
const ENERGY_CAP_BASE: float = 400.0

var running: bool = false
var paused: bool = false
var time_scale: float = 1.0
var game_time: float = 0.0
var seed_value: int = 0

var money: int = 0
var reputation: int = 0
var inventory: Dictionary = {}
var eternity_records: Dictionary = {}
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
var _rate_in_acc: float = 0.0
var _rate_out_acc: float = 0.0
var _rate_time: float = 0.0

func _ready() -> void:
	Land.binding_expired.connect(_on_binding_expired)

# ================================================================ lifecycle
func new_game(seed_in: int) -> void:
	seed_value = seed_in
	eternity_records.clear()
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
	return reputation >= int(Data.machines[machine_id].get("unlock_rep", 0))

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
	if not Data.machines.has(machine_id): return tr("Unknown machine")
	if not Land.in_grid(cell): return tr("Outside the 11x11 plot")
	if not machine_at(biome, cell).is_empty(): return tr("Plot already occupied")
	var def: Dictionary = Data.machines[machine_id]
	if not is_unlocked(machine_id): return tr("Needs %d reputation") % int(def.unlock_rep)
	var parcel: Dictionary = Land.get_parcel(biome, cell)
	if def.get("living", false):
		if int(parcel.sheet.get("adaptation", [1, 1])[0]) == 0: return "此地块不适合生灵"
		if count("life") < Land.life_cost(biome, cell): return "生灵不足"
	if def.kind == "extractor" and str(parcel.deposit) == "": return tr("Must stand on a deposit")
	if money < int(def.cost): return tr("Not enough money")
	if not has_items(def.get("materials", {})): return tr("Missing ") + Data.counts_text(def.materials)
	return ""

func place_machine(machine_id: String, biome: String, cell: Vector2i) -> String:
	var reason: String = can_place(machine_id, biome, cell)
	if reason != "": return reason
	var def: Dictionary = Data.machines[machine_id]
	money -= int(def.cost)
	if def.get("living", false): take_items({"life": Land.life_cost(biome, cell)})
	take_items(def.get("materials", {}))
	var m: Dictionary = _make_machine(machine_id, biome, cell, next_uid)
	next_uid += 1
	machines[m.uid] = m
	_bind_aura(m)
	stats_changed.emit()
	machines_changed.emit(biome)
	return ""

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

func _fill_orders() -> void:
	var guard: int = 0
	while orders.size() < Data.order_slots and guard < 50:
		guard += 1
		var open_ids: Array = orders.map(func(o: Dictionary) -> String: return o.id)
		var pool: Array = Data.orders.filter(func(t: Dictionary) -> bool: return int(t.min_rep) <= reputation and not open_ids.has(t.id))
		if pool.is_empty(): break
		# Prefer the newest tier a little so progression shows up.
		var t: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		orders.append({"id": t.id, "remaining": float(t.time)})

# ================================================================ tick
func _process(delta: float) -> void:
	if not running or paused: return
	step(delta * time_scale)

func step(dt: float) -> void:
	game_time += dt
	Land.tick(dt)
	_tick_weather(dt)
	_tick_orders(dt)
	_tick_machines(dt)

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

func _tick_machines(dt: float) -> void:
	# Pass 1: who wants power this tick?
	var demand: float = 0.0
	var plans: Array = []
	for m: Dictionary in machines.values():
		var def: Dictionary = Data.machines[m.type]
		var st: Dictionary = machine_stats(m)
		var plan: Dictionary = {"m": m, "st": st, "def": def, "active": false}
		if not m.enabled:
			m.status = tr("Paused")
		elif m.jammed:
			m.status = tr("Jammed - needs repair")
		elif def.kind == "support":
			plan.active = true
			m.status = tr("Radiating")
		elif float(st.speed) <= 0.001:
			m.status = tr("Too %s to work") % Data.temperatures[Land.get_parcel(m.biome, m.cell).temperature].name.to_lower()
		else:
			if not m.started:
				var r: Dictionary = recipe_of(m)
				if has_items(r.get("inputs", {})):
					take_items(r.get("inputs", {}))
					m.started = true
				else:
					var missing: Array = []
					for id: String in r.get("inputs", {}):
						if count(id) < int(r.inputs[id]): missing.append(Data.item_name(id))
					m.status = tr("Waiting for ") + ", ".join(missing)
			if m.started:
				plan.active = true
				m.status = tr("Working")
		if plan.active:
			demand += float(def.get("power", 0.0)) * float(st.energy) * dt
		plans.append(plan)
	power_ratio = 1.0 if demand <= 0.0001 else clampf(energy / demand, 0.0, 1.0)
	energy -= demand * power_ratio
	_rate_out_acc += demand * power_ratio
	# Pass 2: advance work.
	var touched: Dictionary = {}
	for plan: Dictionary in plans:
		if not plan.active or plan.def.kind == "support": continue
		var m: Dictionary = plan.m
		var st: Dictionary = plan.st
		var r: Dictionary = recipe_of(m)
		var ratio: float = power_ratio if float(plan.def.get("power", 0.0)) > 0.0 else 1.0
		if ratio < 0.999: m.status = tr("Low energy (%d%%)") % int(ratio * 100.0)
		m.progress = float(m.progress) + dt * float(st.speed) * ratio / maxf(float(r.get("duration", 1.0)), 0.1)
		if float(m.progress) >= 1.0:
			_finish_cycle(m, st, r)
			touched[m.biome] = true
	energy = clampf(energy, 0.0, energy_cap)
	_rate_time += dt
	if _rate_time >= 1.0:
		energy_in_rate = _rate_in_acc / _rate_time
		energy_out_rate = _rate_out_acc / _rate_time
		_rate_in_acc = 0.0
		_rate_out_acc = 0.0
		_rate_time = 0.0
		stats_changed.emit()
	for b: String in touched: machines_changed.emit(b)

func _finish_cycle(m: Dictionary, st: Dictionary, r: Dictionary) -> void:
	var def: Dictionary = Data.machines[m.type]
	var outputs: Dictionary = r.get("outputs", {}).duplicate()
	if def.kind == "extractor":
		var dep: String = str(Land.get_parcel(m.biome, m.cell).deposit)
		if dep != "": outputs = {dep: 1}
	var produced: Dictionary = {}
	for id: String in outputs:
		var amount: float = float(outputs[id]) * float(st["yield"]) + float(m.carry.get(id, 0.0))
		var whole: int = int(floor(amount))
		m.carry[id] = amount - whole
		if whole > 0: produced[id] = whole
	if not produced.is_empty(): give_items(produced)
	var e_out: float = float(r.get("energy_out", 0.0)) * float(st["yield"])
	if e_out > 0.0:
		energy = minf(energy + e_out, energy_cap)
		_rate_in_acc += e_out
	m.wear = float(m.wear) + float(def.get("wear", 0.0)) * float(st.wear)
	if float(m.wear) >= 100.0:
		m.wear = 100.0
		m.jammed = true
		toast.emit(tr("%s jammed in the %s") % [def.name, Data.biome_name(m.biome)], Color("e88a6a"))
	m.progress = 0.0
	m.started = false
	m.cycles = int(m.cycles) + 1
	m.last_output = produced
	machine_cycled.emit(m.uid)

# ================================================================ save / load
func save_game() -> bool:
	var ms: Array = []
	for m: Dictionary in machines.values():
		ms.append({"uid": m.uid, "type": m.type, "biome": m.biome, "cell": [m.cell.x, m.cell.y], "recipe": m.recipe,
			"progress": m.progress, "started": m.started, "wear": m.wear, "jammed": m.jammed, "enabled": m.enabled, "carry": m.carry, "cycles": m.cycles})
	var data: Dictionary = {"version": 1, "seed": seed_value, "time": game_time, "money": money, "reputation": reputation,
		"inventory": inventory, "energy": energy, "machines": ms, "next_uid": next_uid, "orders": orders,
		"weather": weather, "weather_timer": weather_timer, "weather_bindings": Land.save_bindings(), "delivered": delivered,
		"energy_offsets": Land.energy_offsets, "eternity_records": eternity_records,
		"terrain_overrides": Land.terrain_overrides, "tide_state": Land.tide_state,
		"tide_elapsed": Land.tide_elapsed, "tide_count": Land.tide_count,
		"cleared_attachments": Land.cleared, "rng_state": str(_rng.state)}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	toast.emit(tr("Game saved"), Color("b8e08a"))
	return true

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save(): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary: return false
	var d: Dictionary = parsed
	seed_value = int(d.get("seed", 0))
	Land.generate(seed_value)
	Land.energy_offsets = d.get("energy_offsets", {})
	eternity_records = d.get("eternity_records", {})
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
	for raw: Dictionary in d.get("machines", []):
		if not Data.machines.has(str(raw.type)): continue
		var m: Dictionary = _make_machine(str(raw.type), str(raw.biome), Vector2i(int(raw.cell[0]), int(raw.cell[1])), int(raw.uid))
		for k: String in ["recipe", "progress", "started", "wear", "jammed", "enabled", "carry", "cycles"]:
			if raw.has(k): m[k] = raw[k]
		m.recipe = int(m.recipe)
		machines[m.uid] = m
		_bind_aura(m)
	next_uid = int(d.get("next_uid", machines.size() + 1))
	orders = d.get("orders", [])
	weather = d.get("weather", {})
	weather_timer = d.get("weather_timer", {})
	for wb: Dictionary in d.get("weather_bindings", []):
		Land.bind_effect(str(wb.effect), str(wb.biome), Vector2i(5, 5), -1, "weather", str(wb.source_id), float(wb.remaining))
	delivered = int(d.get("delivered", 0))
	paused = false
	time_scale = 1.0
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
	var machine: Dictionary = saved.machine.duplicate(true)
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
		machine.uid = next_uid
		next_uid += 1
		machine.cell = cell
		machines[machine.uid] = machine
		_bind_aura(machine)
	Land._invalidate(biome)
	Land.tide_tile_transformed.emit(biome, cell, "", str(saved.land), 0)
	_emit_all()
	toast.emit("永恒已按记录完整重塑", UITheme.GOOD)
