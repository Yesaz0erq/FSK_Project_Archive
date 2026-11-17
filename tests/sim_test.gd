extends Node
## godot --headless --path . res://tests/sim_test.tscn
var fails: int = 0

func check(cond: bool, msg: String) -> void:
	if cond: print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)

func _ready() -> void:
	var Data: Node = get_node("/root/" + "Data")
	var Land: Node = get_node("/root/" + "Land")
	var Sim: Node = get_node("/root/" + "Sim")
	print("== land generation")
	Sim.new_game(12345)
	var a: Dictionary = Land.get_parcel("forest", Vector2i(3, 4)).duplicate(true)
	Sim.new_game(12345)
	var b: Dictionary = Land.get_parcel("forest", Vector2i(3, 4))
	check(a.land == b.land and a.elements == b.elements, "same seed -> same parcels")
	Sim.new_game(999)
	var diff: int = 0
	for y in 11:
		for x in 11:
			if Land.get_parcel("forest", Vector2i(x, y)).land != a.land: diff += 1
	check(diff > 0, "different seed -> different land")
	var temps: Dictionary = {}
	var types: Dictionary = {}
	var deposits: Dictionary = {}
	for seed_try in [1, 2, 3, 4, 5]:
		Sim.new_game(seed_try)
		for biome in Data.biome_order:
			for y in 11:
				for x in 11:
					var p: Dictionary = Land.get_parcel(biome, Vector2i(x, y))
					temps[p.temperature] = int(temps.get(p.temperature, 0)) + 1
					types[p.land] = true
					if p.deposit != "": deposits[p.deposit] = true
					# inheritance: base = land type +- jitter
					var lt: Dictionary = Data.land_types[p.land]
					for e in Data.element_ids:
						if absf(float(p.base_elements[e]) - clampf(float(lt.elements[e]), 0, 100)) > Land.JITTER + 0.01:
							check(false, "inheritance %s %s" % [p.land, e])
	print("  temperature spread: ", temps)
	check(temps.size() == 6, "all six temperature classes appear")
	check(types.size() == Data.land_types.size(), "all land types appear")
	check(deposits.size() >= 11, "deposits for every resource: %d" % deposits.size())
	print("== effect binding")
	Sim.new_game(42)
	var cell := Vector2i(5, 5)
	var before: float = float(Land.get_parcel("snow", cell).elements.fire)
	var id: int = Land.bind_effect("lily_warmth", "snow", cell, 1, "machine", "test", -1.0)
	var after: float = float(Land.get_parcel("snow", cell).elements.fire)
	check(after > before or after == 100.0, "aura raises fire %.0f -> %.0f" % [before, after])
	var effs: Array = Land.get_parcel("snow", Vector2i(6, 6)).effects.map(func(x): return x.effect)
	var effs_far: Array = Land.get_parcel("snow", Vector2i(7, 7)).effects.map(func(x): return x.effect)
	check(effs.has("lily_warmth") and not effs_far.has("lily_warmth"), "radius 1 covers neighbour only")
	Land.unbind_source("test")
	check(is_equal_approx(float(Land.get_parcel("snow", cell).elements.fire), before), "unbind restores")
	Land.bind_effect("heatwave", "desert", Vector2i(5, 5), -1, "weather", "w", 2.0)
	var hot: float = float(Land.get_parcel("desert", Vector2i(0, 0)).elements.fire)
	Land.tick(3.0)
	check(float(Land.get_parcel("desert", Vector2i(0, 0)).elements.fire) <= hot, "timed weather expires")
	print("== element stats")
	var p_hot: Dictionary = Land.get_parcel("volcano", Vector2i(2, 2)).duplicate(true)
	p_hot.elements = {"fire": 95, "water": 5, "earth": 50, "air": 50}
	p_hot.temperature = Data.temperature_class(95, 5)
	var p_cold: Dictionary = p_hot.duplicate(true)
	p_cold.elements = {"fire": 5, "water": 50, "earth": 50, "air": 50}
	p_cold.temperature = Data.temperature_class(5, 50)
	var sh: Dictionary = StatMath.machine_stats("seedpod_kiln", p_hot)
	var sc: Dictionary = StatMath.machine_stats("seedpod_kiln", p_cold)
	print("  kiln hot ", sh.speed, " cold ", sc.speed)
	check(float(sh.speed) > float(sc.speed), "fire speeds the kiln")
	check(float(sh.wear) > float(sc.wear), "fire wears the kiln")
	var ph: Dictionary = StatMath.machine_stats("pitcher_still", p_cold)
	check(float(ph.speed) == 0.0, "pitcher still freezes (%s)" % p_cold.temperature)
	print("== economy")
	Sim.new_game(7)
	var dep_cell := Vector2i(-1, -1)
	for y in 11:
		for x in 11:
			if Land.get_parcel("forest", Vector2i(x, y)).deposit == "timber": dep_cell = Vector2i(x, y)
	check(dep_cell.x >= 0, "forest has a timber deposit")
	check(Sim.place_machine("taproot_drill", "forest", Vector2i(dep_cell.x, dep_cell.y)) == "", "place drill on deposit")
	var free := Vector2i(-1, -1)
	for y in 11:
		for x in 11:
			if free.x < 0 and Land.get_parcel("forest", Vector2i(x, y)).deposit == "" : free = Vector2i(x, y)
	check(Sim.place_machine("taproot_drill", "forest", free) != "", "drill refused off-deposit")
	check(Sim.place_machine("leafwing_turbine", "forest", free) == "", "place turbine")
	check(Sim.place_machine("bloom_press", "forest", Vector2i(0, 0)) != "", "locked machine refused")
	var t0: int = Sim.count("timber")
	for i in 600: Sim.step(0.1)
	print("  timber ", t0, " -> ", Sim.count("timber"), "  energy ", Sim.energy)
	check(Sim.count("timber") > t0, "drill produced timber")
	check(Sim.save_game(), "save")
	var money: int = Sim.money
	var t1: int = Sim.count("timber")
	Sim.new_game(1)
	check(Sim.load_game(), "load")
	check(Sim.money == money and Sim.count("timber") == t1 and Sim.machines.size() == 2, "state restored")
	check(Land.bindings.filter(func(bb): return bb.source == "machine").size() == 1, "turbine aura rebound")
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
