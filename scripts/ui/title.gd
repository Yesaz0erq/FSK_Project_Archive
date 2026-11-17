extends Node
## Title screen: a slowly orbiting biome diorama behind a small storybook menu.

const BiomeViewScript := preload("res://scripts/world/biome_view.gd")
var _seed_edit: LineEdit
var _view: Node3D

func _ready() -> void:
	var showcase_seed: int = randi() % 1000000
	Land.generate(showcase_seed)
	var biome: String = Data.biome_order[randi() % Data.biome_order.size()]
	_view = BiomeViewScript.new()
	add_child(_view)
	_view.setup(biome, true)
	_view._pan = Vector3(-2.4,0,2.4)
	_decorate_showcase(biome, showcase_seed)
	var layer := CanvasLayer.new()
	layer.layer = 5 # Draw after the world grading layer; never resample UI or text.
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	p.offset_left = 54; p.offset_right = 510; p.offset_top = -340; p.offset_bottom = 340
	p.add_theme_stylebox_override("panel", UITheme.box(Color("171a25", 0.98), UITheme.BORDER, 6, 2, 24))
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UITheme.label(tr("Project Archive"), 44 if Settings.language == "zh_CN" else 32, UITheme.BRASS, true))
	var english := UITheme.label("PROJECT ARCHIVE", 16, UITheme.CREAM)
	v.add_child(english)
	var sub := UITheme.label(tr("Gather Life and Ember.\nFuse nature through Silence; record and reshape through Eternity."), 17, UITheme.CREAM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(396, 0)
	v.add_child(sub)
	v.add_child(HSeparator.new())
	if Sim.has_save():
		v.add_child(_button(tr("Continue"), _continue))
	v.add_child(_button(tr("New Game"), _new_game))
	var sh := HBoxContainer.new()
	sh.add_child(UITheme.label(tr("World seed"), 16, UITheme.CREAM))
	sh.custom_minimum_size.y = 40
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(randi() % 1000000)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_seed_edit)
	var dice := Button.new()
	dice.text = tr("Reroll")
	dice.pressed.connect(func() -> void: _seed_edit.text = str(randi() % 1000000))
	sh.add_child(dice)
	v.add_child(sh)
	v.add_child(_button("世界术语", Settings.open_glossary))
	v.add_child(_button(tr("Settings"), Settings.open))
	v.add_child(_button(tr("Quit"), func() -> void: get_tree().quit()))
	var foot := UITheme.label(tr("Showing: %s — %s") % [Data.biome_name(biome), Data.biomes[biome].subtitle], 14, UITheme.MUTED)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(foot)

func _decorate_showcase(biome: String, seed_value: int) -> void:
	# Sprinkle a few machines on the showcase plot (presentation only; nothing runs).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array = Data.machine_order.duplicate()
	for i in range(6):
		var cell := Vector2i(rng.randi_range(2, 8), rng.randi_range(2, 8))
		var m: Dictionary = {"uid": 9000 + i, "type": ids[rng.randi_range(0, ids.size() - 1)], "biome": biome, "cell": cell,
			"recipe": 0, "progress": 0.0, "started": false, "wear": 0.0, "jammed": false, "enabled": true, "status": tr("Working"), "carry": {}, "cycles": 0}
		if Sim.machine_at(biome, cell).is_empty(): Sim.machines[m.uid] = m
	_view.refresh_machines()

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b

func _new_game() -> void:
	var s: int = int(_seed_edit.text) if _seed_edit.text.is_valid_int() else hash(_seed_edit.text)
	Sim.new_game(absi(s))
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _continue() -> void:
	if Sim.load_game():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
