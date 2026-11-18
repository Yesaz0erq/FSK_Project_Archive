extends Node
## Open archive index over a slowly orbiting biome diorama.

const BiomeViewScript := preload("res://scripts/world/biome_view.gd")
const ArchiveMark := preload("res://scripts/ui/archive_mark.gd")
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
	_decorate_showcase(biome)
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
	p.offset_left = 58
	p.offset_right = 468
	p.offset_top = -272
	p.offset_bottom = 272
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(p)
	var curtain := ColorRect.new()
	curtain.z_index = -1
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := ShaderMaterial.new()
	paper.shader = preload("res://assets/shaders/title_canvas.gdshader")
	curtain.material = paper
	var update_size := func() -> void: paper.set_shader_parameter("surface_size", root.size)
	root.resized.connect(update_size)
	update_size.call()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 13)
	p.add_child(v)
	var masthead := HBoxContainer.new()
	masthead.add_theme_constant_override("separation", 16)
	v.add_child(masthead)
	var mark := ArchiveMark.new()
	mark.custom_minimum_size = Vector2(68, 76)
	masthead.add_child(mark)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	masthead.add_child(names)
	names.add_child(UITheme.label(tr("Project Archive"), 58 if Settings.language == "zh_CN" else 35, UITheme.CREAM, true))
	if Settings.language == "zh_CN":
		var display_font := FontVariation.new()
		display_font.base_font = UITheme.sans
		display_font.spacing_glyph = 3
		var english := UITheme.label("PROJECT ARCHIVE", 13, UITheme.JADE)
		english.add_theme_font_override("font", display_font)
		names.add_child(english)
	v.add_child(HSeparator.new())
	var sub := UITheme.label(tr("Gather Life and Ember.\nFuse nature through Silence; record and reshape through Eternity."), 16, UITheme.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	if Sim.has_save():
		var resume_button := _button(tr("Continue"), _continue)
		resume_button.icon = UITheme.icon("continue")
		actions.add_child(resume_button)
	var start_button := _button(tr("New Game"), _new_game)
	start_button.icon = UITheme.icon("new", UITheme.BRASS)
	start_button.add_theme_stylebox_override("normal", UITheme.box(Color("254848"), UITheme.JADE, 5, 1, 8))
	actions.add_child(start_button)
	var sh := HBoxContainer.new()
	sh.add_child(UITheme.label(tr("World seed"), 14, UITheme.MUTED))
	sh.custom_minimum_size.y = 40
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(randi() % 1000000)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_seed_edit)
	var dice := Button.new()
	dice.text = tr("Reroll")
	UITheme.button_motion(dice)
	dice.pressed.connect(func() -> void: _seed_edit.text = str(randi() % 1000000))
	sh.add_child(dice)
	v.add_child(sh)
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 8)
	v.add_child(utilities)
	utilities.add_child(_button("世界术语", Settings.open_glossary))
	utilities.add_child(_button(tr("Settings"), Settings.open))
	utilities.add_child(_button(tr("Quit"), func() -> void: get_tree().quit()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(HSeparator.new())
	var foot := UITheme.label(tr("Showing: %s — %s") % [Data.biome_name(biome), Data.biomes[biome].subtitle], 14, UITheme.JADE)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(foot)
	UITheme.reveal(p, 0.38)
	for i in v.get_child_count():
		UITheme.reveal(v.get_child(i), 0.34, 0.03 * i)
	var motion := p.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	motion.tween_property(p, "position:x", p.position.x, 0.5).from(p.position.x - 22.0)

func _decorate_showcase(biome: String) -> void:
	var cells := [Vector2i(4, 3), Vector2i(7, 4), Vector2i(6, 7)]
	for i in Data.machine_order.size():
		var model := Sim._make_machine(Data.machine_order[i], biome, cells[i], i + 1)
		_view.showcase_machines[model.uid] = model
	_view.refresh_machines()

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.button_motion(b)
	b.pressed.connect(cb)
	return b

func _new_game() -> void:
	var s: int = int(_seed_edit.text) if _seed_edit.text.is_valid_int() else hash(_seed_edit.text)
	Sim.new_game(absi(s))
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _continue() -> void:
	if Sim.load_game():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
