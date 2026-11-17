extends Node

const PATH := "user://settings.cfg"
var language: String = "zh_CN"
var fullscreen: bool = false
var vsync: bool = true
var camera_speed: float = 1.0
var starting_money: int = 400
var starting_energy: float = 60.0
var autosave_seconds: float = 120.0
var tide_seconds: float = 120.0
var dialog: Window
var _elapsed: float = 0.0

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		language = str(cfg.get_value("game", "language", "zh_CN"))
		fullscreen = bool(cfg.get_value("game", "fullscreen", false))
		vsync = bool(cfg.get_value("game", "vsync", true))
		camera_speed = clampf(float(cfg.get_value("game", "camera_speed", 1.0)), 0.25, 3.0)
		starting_money = clampi(int(cfg.get_value("game", "starting_money", 400)), 0, 100000)
		starting_energy = clampf(float(cfg.get_value("game", "starting_energy", 60.0)), 0, 400)
		autosave_seconds = clampf(float(cfg.get_value("game", "autosave_seconds", 120.0)), 0, 3600)
		tide_seconds = clampf(float(cfg.get_value("game", "tide_seconds", 120.0)), 0, 3600)
	var translation := Translation.new()
	translation.locale = "zh_CN"
	var messages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locales/zh_CN.json"))
	for key: String in messages: translation.add_message(key, str(messages[key]))
	TranslationServer.add_translation(translation)
	apply_display()

func apply_display() -> void:
	TranslationServer.set_locale(language)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func _process(delta: float) -> void:
	if not Sim.running or is_open(): return
	_elapsed += delta
	if autosave_seconds > 0 and _elapsed >= autosave_seconds:
		_elapsed = 0
		Sim.save_game()

func is_open() -> bool:
	return is_instance_valid(dialog) and dialog.visible

func _number(parent: VBoxContainer, caption: String, value: float, low: float, high: float, step_value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := UITheme.label(tr(caption), 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var edit := SpinBox.new()
	edit.min_value = low
	edit.max_value = high
	edit.step = step_value
	edit.value = value
	edit.custom_minimum_size.x = 150
	row.add_child(edit)
	return edit

func open() -> void:
	if is_open(): return
	dialog = Window.new()
	dialog.title = tr("Settings")
	dialog.size = Vector2i(650, 580)
	dialog.exclusive = true
	dialog.transient = true
	dialog.theme = UITheme.build()
	add_child(dialog)
	var was_paused: bool = Sim.paused
	Sim.paused = true
	var close := func() -> void:
		Sim.paused = was_paused
		dialog.queue_free()
	dialog.close_requested.connect(close)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	dialog.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(UITheme.label(tr("Settings"), 26, UITheme.BRASS))
	var lang := OptionButton.new()
	lang.add_item("简体中文")
	lang.add_item("English")
	lang.selected = 0 if language == "zh_CN" else 1
	box.add_child(lang)
	var full := CheckButton.new()
	full.text = tr("Fullscreen")
	full.button_pressed = fullscreen
	box.add_child(full)
	var sync := CheckButton.new()
	sync.text = tr("VSync")
	sync.button_pressed = vsync
	box.add_child(sync)
	var speed := _number(box, "Camera speed", camera_speed, 0.25, 3, 0.25)
	var funds := _number(box, "Starting funds (new games)", starting_money, 0, 100000, 10)
	var power := _number(box, "Starting energy (new games)", starting_energy, 0, 400, 5)
	var autosave := _number(box, "Autosave seconds (0 = off)", autosave_seconds, 0, 3600, 10)
	var tide := _number(box, "Tide interval (0 = manual)", tide_seconds, 0, 3600, 10)
	var row := HBoxContainer.new()
	box.add_child(row)
	var save := Button.new()
	save.text = tr("Apply")
	row.add_child(save)
	var cancel := Button.new()
	cancel.text = tr("Cancel")
	row.add_child(cancel)
	cancel.pressed.connect(close)
	save.pressed.connect(func() -> void:
		var changed_language: bool = language != ("zh_CN" if lang.selected == 0 else "en")
		language = "zh_CN" if lang.selected == 0 else "en"
		fullscreen = full.button_pressed
		vsync = sync.button_pressed
		camera_speed = speed.value
		starting_money = int(funds.value)
		starting_energy = power.value
		autosave_seconds = autosave.value
		tide_seconds = tide.value
		var cfg := ConfigFile.new()
		for key in ["language", "fullscreen", "vsync", "camera_speed", "starting_money", "starting_energy", "autosave_seconds", "tide_seconds"]:
			cfg.set_value("game", key, get(key))
		cfg.save(PATH)
		apply_display()
		close.call()
		if changed_language:
			Data.reload()
			Land._cache.clear()
			get_tree().reload_current_scene.call_deferred()
	)
	dialog.popup_centered()

func open_glossary() -> void:
	var window := AcceptDialog.new()
	window.title = "世界术语"
	window.size = Vector2i(720, 650)
	window.theme = UITheme.build()
	add_child(window)
	window.confirmed.connect(window.queue_free)
	window.canceled.connect(window.queue_free)
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(680, 570)
	text.bbcode_enabled = true
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/glossary.json"))
	for term: String in glossary: text.append_text("[color=#d9a85a][b]" + term + "[/b][/color]\n" + str(glossary[term]) + "\n\n")
	window.add_child(text)
	window.popup_centered()
