extends Control
signal return_to_title
const ArchiveMark := preload("res://scripts/ui/archive_mark.gd")
const RenderLayout := preload("res://scripts/world/machine_sprites.gd")
var active: bool = false
var allow_save := true
var _was_paused: bool = false
var _menu: PanelContainer
var _codex: PanelContainer
var _codex_list: VBoxContainer
var _codex_info: VBoxContainer
var _machine_buttons: Dictionary = {}

var _portrait: TextureRect
var _pose: AtlasTexture
var _play_button: Button
var _preview_id := ""
var _angle := 0
var _elapsed := 0.0
var _playing := false

func _caption(chinese: String, english: String) -> String:
	return chinese if Settings.language == "zh_CN" else english

func _ready() -> void:
	set_process(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	var shade := ColorRect.new()
	shade.color = Color("081125bb")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.offset_left = -210; _menu.offset_right = 210
	_menu.offset_top = -210; _menu.offset_bottom = 210
	_menu.add_theme_stylebox_override("panel", UITheme.frame(UITheme.BG, 22))
	add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	_menu.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var mark := ArchiveMark.new()
	mark.custom_minimum_size = Vector2(42, 42)
	header.add_child(mark)
	header.add_child(UITheme.label(_caption("已暂停", "Paused"),32,UITheme.CREAM,true))
	box.add_child(HSeparator.new())
	_button(box,_caption("继续游戏", "Resume"),close)
	_button(box,_caption("机器图鉴", "Machine Codex"),open_codex)
	_button(box,_caption("设置", "Settings"),Settings.open)
	if allow_save: _button(box,_caption("保存游戏", "Save Game"),func() -> void: Sim.save_game())
	_button(box,_caption("返回标题", "Return to Title"),func() -> void: close(); return_to_title.emit())
	_codex = PanelContainer.new()
	_codex.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_codex.offset_left = -520; _codex.offset_right = 520
	_codex.offset_top = -340; _codex.offset_bottom = 340
	add_child(_codex)
	hide()

func _button(parent: Control, caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = 44
	UITheme.button_motion(b)
	b.pressed.connect(callback)
	parent.add_child(b)

func open() -> void:
	if active: return
	_was_paused = Sim.paused
	Sim.paused = true
	active = true
	_menu.show()
	_codex.hide()
	show()
	UITheme.reveal(self, 0.18)
	UITheme.reveal(_menu, 0.24)

func close() -> void:
	if not active: return
	Sim.paused = _was_paused
	active = false
	set_process(false)
	hide()

func _input(event: InputEvent) -> void:
	if not active or Settings.is_open(): return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if _codex.visible:
				_codex.hide()
				set_process(false)
				_menu.show()
				UITheme.reveal(_menu, 0.16)
			else: close()
		get_viewport().set_input_as_handled()

func open_codex() -> void:
	if _codex_info == null: _build_codex()
	_show_machine(str(Data.machine_order[0]))
	_menu.hide()
	_codex.show()
	UITheme.reveal(_codex, 0.2)

func _build_codex() -> void:
	_codex.add_theme_stylebox_override("panel", UITheme.frame(UITheme.BG, 24))
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 13)
	_codex.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := UITheme.label(_caption("机器图鉴", "Machine Codex"), 31, UITheme.CREAM, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button(header, _caption("返回暂停菜单", "Back to Menu"), func() -> void:
		_codex.hide()
		set_process(false)
		_menu.show()
		UITheme.reveal(_menu, 0.16))
	page.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 264
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_codex_list = VBoxContainer.new()
	_codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_codex_list)
	for id: String in Data.machine_order:
		var entry := Button.new()
		entry.text = str(Data.machines[id].name)
		entry.icon = Art.machine(id)
		entry.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		entry.expand_icon = true
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size.y = 46
		entry.add_theme_constant_override("icon_max_width", 38)
		entry.toggle_mode = true
		entry.pressed.connect(func() -> void: _show_machine(id))
		UITheme.button_motion(entry)
		_codex_list.add_child(entry)
		_machine_buttons[id] = entry
	columns.add_child(VSeparator.new())
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_scroll)
	_codex_info = VBoxContainer.new()
	_codex_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_info.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(_codex_info)
	page.add_child(HSeparator.new())
	var life := UITheme.label(_caption("投放第 1 点后有 5 秒追加第 2 点。投入第 2 点后，有 10 秒追加第 3 点。定型后再生长 10 秒。", "Plant 1 Life. Add the second within 5s, then the third within 10s, to change the outcome. Each final form grows for 10s."), 15, UITheme.MUTED)
	life.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(life)

func _show_machine(id: String) -> void:
	for child in _codex_info.get_children():
		_codex_info.remove_child(child)
		child.queue_free()
	for key: String in _machine_buttons:
		_machine_buttons[key].set_pressed_no_signal(key == id)
	var machine: Dictionary = Data.machines[id]
	_preview_id = id
	_angle = 0
	_elapsed = 0.0
	_playing = false
	set_process(false)
	_pose = null
	_portrait = TextureRect.new()
	_portrait.texture = Art.machine(id)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.custom_minimum_size.y = 225
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_codex_info.add_child(_portrait)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	_codex_info.add_child(controls)
	var left := _preview_button(controls, "◀", _caption("向左转", "Rotate left"))
	left.pressed.connect(_turn_preview.bind(-1))
	_play_button = _preview_button(controls, _caption("演示运转", "Play motion"), "")
	_play_button.custom_minimum_size.x = 112
	_play_button.toggle_mode = true
	_play_button.toggled.connect(_toggle_play)
	var right := _preview_button(controls, "▶", _caption("向右转", "Rotate right"))
	right.pressed.connect(_turn_preview.bind(1))
	_codex_info.add_child(UITheme.label(str(machine.name), 30, UITheme.BRASS, true))
	var description := UITheme.label(tr(str(machine.description)), 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_info.add_child(description)
	_codex_info.add_child(HSeparator.new())
	_codex_info.add_child(UITheme.label(_caption("操作部署", "Deployment"), 18, UITheme.JADE))
	var method: Dictionary = machine.get("deployment", {})
	var details := UITheme.label(tr(str(method.instructions)), 16)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_info.add_child(details)
	var support := int(machine.support)
	var site := _caption("支撑 ≥ %d" % support, "Support ≥ %d" % support)
	if machine.has("site_life_min"):
		site += _caption(" · 落点生灵浓度 ≥ %d", " · Site Life ≥ %d") % int(machine.site_life_min)
	var energy := _caption("自体供能", "Self-powered") if machine.supply == "self" else _caption("潮汐供能", "Tide-powered")
	_codex_info.add_child(UITheme.label("%s · %s" % [machine.tier, energy], 15, UITheme.JADE))
	_codex_info.add_child(UITheme.label(site, 15))
	var reach := _caption("上下左右四格", "4 cardinal neighbors") if machine.area == "adjacent" else _caption("周围八格", "8 surrounding neighbors")
	var work := UITheme.label(_caption("作用范围：%s。范围内至少有一格生灵浓度 ≥ 0 时可工作。", "Range: %s. Requires at least one neighbor with Life concentration ≥ 0.") % reach, 15, UITheme.MUTED)
	work.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_info.add_child(work)
	UITheme.reveal(_codex_info, 0.18)

func _preview_button(parent: Control, caption: String, hint: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(40, 34)
	UITheme.button_motion(button)
	parent.add_child(button)
	return button

func _turn_preview(direction: int) -> void:
	_angle = posmod(_angle + direction, RenderLayout.DIRECTIONS)
	_update_preview()

func _toggle_play(on: bool) -> void:
	_playing = on
	_play_button.text = _caption("暂停演示", "Pause motion") if on else _caption("演示运转", "Play motion")
	set_process(on)
	_update_preview()

func _update_preview() -> void:
	if _angle == 0 and not _playing and _elapsed == 0.0:
		_portrait.texture = Art.machine(_preview_id)
		return
	if _pose == null:
		_pose = AtlasTexture.new()
		_pose.atlas = Art.machine_sheet(_preview_id)
		_pose.filter_clip = true
	var frame := floori(_elapsed) % RenderLayout.POSES
	_pose.region = Rect2i(Vector2i(frame, _angle) * RenderLayout.FRAME, RenderLayout.FRAME)
	_portrait.texture = _pose

func _process(delta: float) -> void:
	var previous := floori(_elapsed)
	_elapsed = fmod(_elapsed + delta * 8.0, float(RenderLayout.POSES))
	if previous != floori(_elapsed):
		_update_preview()
