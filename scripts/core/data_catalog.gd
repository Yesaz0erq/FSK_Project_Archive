extends Node
## Loads every JSON table in res://data. All game rules live in these files.

var element_ids: Array[String] = ["life", "ember", "silence", "eternity"]
var stat_ids: Array[String] = ["speed", "yield", "energy", "wear"]

var elements: Dictionary = {}
var stat_influence: Dictionary = {}
var stat_info: Dictionary = {}
var stat_limits: Dictionary = {}
var temperature_rules: Array = []
var temperatures: Dictionary = {}
var land_types: Dictionary = {}
var biomes: Dictionary = {}
var biome_order: Array[String] = []
var effects: Dictionary = {}
var items: Dictionary = {}
var machines: Dictionary = {}
var machine_order: Array[String] = []
var orders: Array = []
var order_slots: int = 4

func _ready() -> void:
	reload()

func reload() -> void:
	var e: Dictionary = _read("res://data/elements.json")
	elements = e.get("elements", {})
	stat_influence = e.get("stat_influence", {})
	stat_info = e.get("stats", {})
	stat_limits = e.get("stat_limits", {})
	var t: Dictionary = _read("res://data/temperatures.json")
	temperature_rules = t.get("rules", [])
	temperatures = t.get("classes", {})
	land_types = _read("res://data/land_types.json").get("land_types", {})
	var b: Dictionary = _read("res://data/biomes.json")
	biomes = b.get("biomes", {})
	biome_order.clear()
	for id: Variant in b.get("order", []):
		biome_order.append(str(id))
	effects = _read("res://data/effects.json").get("effects", {})
	items = _read("res://data/items.json").get("items", {})
	machines = _read("res://data/machines.json").get("machines", {})
	machine_order.clear()
	for id: Variant in machines.keys():
		machine_order.append(str(id))
	machine_order.sort_custom(func(a: String, b2: String) -> bool:
		return int(machines[a].deployment.life_cost) < int(machines[b2].deployment.life_cost))
	var o: Dictionary = _read("res://data/orders.json")
	orders = o.get("orders", [])
	order_slots = int(o.get("slots", 4))

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_translate_fields(parsed)
		return parsed
	push_error("Bad JSON: " + path)
	return {}

func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))

func item_color(id: String) -> Color:
	return Color(str(items.get(id, {}).get("color", "#cccccc")))

func biome_name(id: String) -> String:
	return str(biomes.get(id, {}).get("name", id))

func palette(biome: String, key: String) -> Color:
	return Color(str(biomes.get(biome, {}).get("palette", {}).get(key, "#808080")))

func temperature_class(fire: float, water: float) -> String:
	for rule: Dictionary in temperature_rules:
		if rule.has("fire_below") and not fire < float(rule.fire_below): continue
		if rule.has("fire_at_least") and not fire >= float(rule.fire_at_least): continue
		if rule.has("water_at_least") and not water >= float(rule.water_at_least): continue
		return str(rule["class"])
	return "dry"

func counts_text(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in counts:
		parts.append("%d %s" % [int(counts[id]), item_name(id)])
	return ", ".join(parts) if not parts.is_empty() else tr("nothing")

func _translate_fields(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			if str(key) in ["name", "description", "subtitle", "customer"] and value[key] is String:
				value[key] = tr(str(value[key]))
			else: _translate_fields(value[key])
	elif value is Array:
		for entry: Variant in value: _translate_fields(entry)
