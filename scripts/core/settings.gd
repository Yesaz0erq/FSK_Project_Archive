extends Node

const PATH := "user://settings.cfg"
var language: String = "zh_CN"
var fullscreen: bool = false
var vsync: bool = true
var camera_speed: float = 1.0
var starting_money: int = 400
var starting_energy: float = 60.0
var autosave_seconds: float = 120.0
var tide_seconds: float = 30.0
const ArchiveMark := preload("res://scripts/ui/archive_mark.gd")
var dialog: Window
var _glossary: AcceptDialog
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
		tide_seconds = clampf(float(cfg.get_value("game", "tide_seconds", 30.0)), 0, 3600)
	var translation := Translation.new()
	translation.locale = "zh_CN"
	var messages: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locales/zh_CN.json"))
	for key: String in messages: translation.add_message(key, str(messages[key]))
	TranslationServer.add_translation(translation)
	apply_display()

func apply_display() -> void:
	TranslationServer.set_locale(language)
	DisplayServer.window_set_title(tr("Project Archive"))
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
	edit.custom_minimum_size = Vector2(140, 38)
	row.add_child(edit)
	return edit

func _heading(parent: Control, title: String) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var mark := ArchiveMark.new()
	mark.custom_minimum_size = Vector2(40, 44)
	header.add_child(mark)
	header.add_child(UITheme.label(title, 30, UITheme.CREAM, true))
	parent.add_child(header)
	parent.add_child(HSeparator.new())

func _settings_tab(tabs: TabContainer, caption: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = tr(caption)
	page.add_theme_constant_override("separation", 14)
	tabs.add_child(page)
	return page

func _dialog_size(desired: Vector2i) -> Vector2i:
	var available := Vector2i(get_viewport().get_visible_rect().size) - Vector2i(36, 48)
	return desired.min(available)

func open() -> void:
	if is_open(): return
	dialog = Window.new()
	dialog.title = tr("Settings")
	dialog.borderless = true
	dialog.unresizable = true
	dialog.exclusive = true
	dialog.transient = true
	dialog.theme = UITheme.build()
	add_child(dialog)
	var was_paused: bool = Sim.paused
	Sim.paused = true
	var window := dialog
	var close := func() -> void:
		Sim.paused = was_paused
		window.hide()
		window.queue_free()
	window.close_requested.connect(close)
	window.window_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			window.set_input_as_handled()
			close.call())
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.frame(UITheme.BG, 22))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	frame.add_child(box)
	_heading(box, tr("Settings"))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	var display := _settings_tab(tabs, "Display and controls")
	var world := _settings_tab(tabs, "New world")
	var timing := _settings_tab(tabs, "Simulation")
	tabs.tab_changed.connect(func(index: int) -> void: UITheme.reveal(tabs.get_tab_control(index), 0.18))
	var language_row := HBoxContainer.new()
	display.add_child(language_row)
	var caption := UITheme.label(tr("Language"), 15)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_row.add_child(caption)
	var lang := OptionButton.new()
	lang.custom_minimum_size = Vector2(140, 38)
	lang.add_item("简体中文")
	lang.add_item("English")
	lang.selected = 0 if language == "zh_CN" else 1
	language_row.add_child(lang)
	var full := CheckButton.new()
	full.text = tr("Fullscreen")
	full.button_pressed = fullscreen
	display.add_child(full)
	var sync := CheckButton.new()
	sync.text = tr("VSync")
	sync.button_pressed = vsync
	display.add_child(sync)
	display.add_child(HSeparator.new())
	var speed := _number(display, "Camera speed", camera_speed, 0.25, 3, 0.25)
	var funds := _number(world, "Starting funds (new games)", starting_money, 0, 100000, 10)
	var power := _number(world, "Starting energy (new games)", starting_energy, 0, 400, 5)
	var autosave := _number(timing, "Autosave seconds (0 = off)", autosave_seconds, 0, 3600, 10)
	var tide := _number(timing, "Tide interval (0 = manual)", tide_seconds, 0, 3600, 10)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 9)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = tr("Cancel")
	cancel.custom_minimum_size = Vector2(98, 40)
	UITheme.button_motion(cancel)
	row.add_child(cancel)
	cancel.pressed.connect(close)
	var save := Button.new()
	save.text = tr("Apply")
	save.icon = UITheme.icon("save")
	save.custom_minimum_size = Vector2(110, 40)
	UITheme.button_motion(save)
	row.add_child(save)
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
	window.popup_centered(_dialog_size(Vector2i(660, 490)))
	UITheme.reveal(box, 0.19)

func open_glossary() -> void:
	if is_instance_valid(_glossary) and _glossary.visible: return
	var window := AcceptDialog.new()
	_glossary = window
	window.title = tr("World glossary")
	window.borderless = true
	window.exclusive = true
	window.transient = true
	window.unresizable = true
	window.theme = UITheme.build()
	add_child(window)
	window.confirmed.connect(window.queue_free)
	window.canceled.connect(window.queue_free)
	window.get_ok_button().text = tr("Close")
	window.get_ok_button().custom_minimum_size = Vector2(110, 38)
	UITheme.button_motion(window.get_ok_button())
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	window.add_child(page)
	_heading(page, window.title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var index_scroll := ScrollContainer.new()
	index_scroll.custom_minimum_size.x = 166
	index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(index_scroll)
	var index := VBoxContainer.new()
	index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	index.add_theme_constant_override("separation", 4)
	index_scroll.add_child(index)
	columns.add_child(VSeparator.new())
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 16)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail)
	var title := UITheme.label("", 34, UITheme.JADE, true)
	detail.add_child(title)
	detail.add_child(HSeparator.new())
	var definition := UITheme.label("", 19, UITheme.CREAM)
	definition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	definition.add_theme_constant_override("line_spacing", 7)
	detail.add_child(definition)
	var glossary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/glossary.json"))
	var entries := ButtonGroup.new()
	for term: String in glossary:
		var entry := Button.new()
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.text = term
		entry.toggle_mode = true
		entry.button_group = entries
		entry.custom_minimum_size.y = 38
		UITheme.button_motion(entry)
		entry.pressed.connect(func() -> void:
			title.text = term
			definition.text = str(glossary[term])
			UITheme.reveal(detail, 0.17))
		index.add_child(entry)
		if index.get_child_count() == 1:
			entry.set_pressed_no_signal(true)
			title.text = term
			definition.text = str(glossary[term])
	window.popup_centered(_dialog_size(Vector2i(710, 570)))
	UITheme.reveal(page, 0.18)
