extends CanvasLayer
## In-game interface. Built in code so every number comes straight from Sim / Land / Data.

signal travel_requested(biome: String)
signal menu_requested
signal life_placement_requested(cell: Vector2i)

var view: Node3D                       # current BiomeView (set by game.gd)
var biome: String = "forest"
var build_type: String = ""
var _root: Control
var _money: Label
var _rep: Label
var _tide_text: Label
var _tide_bar_holder: Control
var _clock: Label
var _speed_buttons: Dictionary = {}
var _tutorial_time_locked := false
var _last_wave_row := -1
var _tool_buttons: Dictionary = {}
var _stats_panel: Control
var _tools_panel: Control
var _biome_buttons: Dictionary = {}
var _inv_box: VBoxContainer
var _inspect_box: VBoxContainer
var _orders_box: VBoxContainer
var _tabs: TabContainer
var _build_bar: HBoxContainer
var _build_cards: Dictionary = {}
var _view_buttons: Dictionary = {}
var _toast_box: VBoxContainer
var _title_card: VBoxContainer
var _biome_name: Label
var _biome_subtitle: Label
var _weather_label: Label
var _hint: Label
var _legend: VBoxContainer
var _inspect_dirty: bool = true
var _inspect_timer: float = 0.0
var _last_inspect_cell := Vector2i(-2, -2)

const ArchiveMark := preload("res://scripts/ui/archive_mark.gd")
var _title_motion: Tween
var _tide_motion: Tween
var _inventory_rows: Dictionary = {}
var _inventory_queued := false
var _orders_queued := false
var _order_rows: Array[Dictionary] = []
var _last_clock_second := -1
var _pantry_scroll: ScrollContainer
var _detail_motion: Tween
var _detail_height := -1.0

const VIEW_MODES := [["none", "Normal"], ["life", "生灵"], ["ember", "余烬"], ["silence", "静默"], ["eternity", "永恒"], ["temperature", "Temp"], ["effects", "Effects"]]

func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)
	_build_top_bar()
	_build_left()
	_build_right()
	_build_bottom()
	_build_toasts()
	for i in _root.get_child_count():
		var part: Control = _root.get_child(i)
		if part != _title_card: UITheme.reveal(part, 0.3, 0.04 * i)
	Sim.inventory_changed.connect(_on_inventory_changed)
	Sim.stats_changed.connect(_refresh_top)
	Sim.orders_changed.connect(_queue_orders)
	Sim.machines_changed.connect(func(_b: String) -> void: _inspect_dirty = true)
	Sim.weather_changed.connect(func(_b: String) -> void: _refresh_biome_tabs())
	Sim.toast.connect(show_toast)
	Sim.growth_changed.connect(func(_b: String) -> void: _inspect_dirty = true)
	Land.tide_started.connect(func(edge: int) -> void: show_toast(tr("Tide arriving: %s") % [tr(["West", "East", "North", "South"][edge])], UITheme.BRASS))
	Land.parcels_changed.connect(func(b: String) -> void: if b == biome: _inspect_dirty = true)
	_refresh_inventory()
	_refresh_top()
	_refresh_orders()

# ================================================================ layout
func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p

func _build_top_bar() -> void:
	var p := _panel(_root)
	_stats_panel = p
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.offset_left = 16; p.offset_right = 16; p.offset_top = 12; p.offset_bottom = 82
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var mark := ArchiveMark.new()
	mark.custom_minimum_size = Vector2(38, 40)
	h.add_child(mark)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -4)
	logo.add_child(UITheme.label(tr("Project Archive"), 22, UITheme.CREAM, true))
	_clock = UITheme.label(tr("Day 1 · 00:00"), 12, UITheme.MUTED)
	logo.add_child(_clock)
	h.add_child(logo)
	h.add_child(VSeparator.new())
	_money = _stat(h, tr("Funds"), "¤ 0", UITheme.BRASS)
	_rep = _stat(h, tr("Reputation"), "0", Color("e49aa8"))
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	ev.add_child(UITheme.label(tr("Tide"), 11, UITheme.MUTED))
	_tide_bar_holder = Control.new()
	_tide_bar_holder.custom_minimum_size = Vector2(170, 12)
	ev.add_child(_tide_bar_holder)
	_tide_text = UITheme.label("", 12, Color("8ad0f0"))
	ev.add_child(_tide_text)
	h.add_child(ev)
	h.add_child(VSeparator.new())
	for s: Array in [["II", 0.0], ["1x", 1.0], ["3x", 3.0]]:
		var b := Button.new()
		b.text = s[0]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(40, 0)
		b.focus_mode = Control.FOCUS_NONE
		var sp: float = s[1]
		UITheme.button_motion(b)
		b.pressed.connect(func() -> void: _set_speed(sp))
		h.add_child(b)
		_speed_buttons[sp] = b
	var dock := _panel(_root)
	dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dock.offset_left = -255
	dock.offset_right = 255
	dock.offset_top = -115
	dock.offset_bottom = -42
	dock.add_theme_stylebox_override("panel", UITheme.frame(UITheme.BG, 9))
	var bv := VBoxContainer.new()
	dock.add_child(bv)
	bv.add_theme_constant_override("separation", 2)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 5)
	for i in range(Data.biome_order.size()):
		var id: String = Data.biome_order[i]
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = UITheme.icon(id, Color(str(Data.biomes[id].palette.accent)))
		b.text = "%s  F%d" % [Data.biome_name(id), i + 1]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		UITheme.button_motion(b)
		b.pressed.connect(func() -> void: travel_requested.emit(id))
		bh.add_child(b)
		_biome_buttons[id] = b
	bv.add_child(bh)
	_weather_label = UITheme.label("", 12, UITheme.MUTED)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_weather_label)
	_weather_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weather_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var tools_panel := _panel(_root)
	_tools_panel = tools_panel
	tools_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tools_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools_panel.offset_left = -16
	tools_panel.offset_right = -16
	tools_panel.offset_top = 12
	tools_panel.offset_bottom = 82
	tools_panel.add_theme_stylebox_override("panel", UITheme.frame(UITheme.BG, 9))
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 4)
	tools_panel.add_child(tools_row)
	for s2: Array in [[tr("Tide"), "tide"], ["术语", "glossary"], [tr("Settings"), "settings"], [tr("Save"), "save"], [tr("Load"), "load"], [tr("Menu"), "menu"]]:
		var b := Button.new()
		b.text = s2[0]
		b.focus_mode = Control.FOCUS_NONE
		var action: String = s2[1]
		b.icon = UITheme.icon(action)
		b.custom_minimum_size.x = 64
		UITheme.button_motion(b)
		b.pressed.connect(func() -> void: _top_action(action))
		tools_row.add_child(b)
		_tool_buttons[action] = b

func set_tutorial_guidance(guided: bool) -> void:
	# Keep the clock and menu accessible while the world-space prompts own planting.
	for panel: Control in _root.get_children():
		panel.visible = not guided or panel == _stats_panel or panel == _tools_panel
	for action: String in _tool_buttons:
		_tool_buttons[action].visible = action == "menu" or (not guided and action not in ["save", "load"])
	_refresh_top()

func set_tutorial_time_locked(locked: bool) -> void:
	_tutorial_time_locked = locked
	for button: Button in _speed_buttons.values():
		button.disabled = locked
	_refresh_top()

func time_control_at(point: Vector2) -> bool:
	for button: Button in _speed_buttons.values():
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return true
	return false

func _stat(parent: Control, caption: String, value: String, color: Color) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UITheme.label(caption, 11, UITheme.MUTED))
	var l := UITheme.label(value, 22, color, true)
	v.add_child(l)
	v.custom_minimum_size = Vector2(88, 0)
	parent.add_child(v)
	return l

func _build_left() -> void:
	var p := _panel(_root)
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.offset_left = 16; p.offset_right = 254; p.offset_top = 104; p.offset_bottom = 104
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UITheme.label(tr("Shared Larder"), 18, UITheme.BRASS, true))
	v.add_child(HSeparator.new())
	v.tooltip_text = tr("All four scenes share these goods.")
	var sc := ScrollContainer.new()
	_pantry_scroll = sc
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_inv_box = VBoxContainer.new()
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_box.add_theme_constant_override("separation", 2)
	sc.add_child(_inv_box)
	var overlay_panel := _panel(_root)
	overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	overlay_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay_panel.offset_left = 16
	overlay_panel.offset_right = 254
	overlay_panel.offset_top = -190
	overlay_panel.offset_bottom = -42
	var overlay := VBoxContainer.new()
	overlay.add_theme_constant_override("separation", 7)
	overlay_panel.add_child(overlay)
	overlay.add_child(UITheme.label(tr("Land view  (V)"), 16, UITheme.JADE, true))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	for mode: Array in VIEW_MODES:
		var b := Button.new()
		b.text = tr(mode[1])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		var id: String = mode[0]
		if Data.elements.has(id): b.add_theme_color_override("font_color", Color(str(Data.elements[id].color)).lightened(0.2))
		UITheme.button_motion(b)
		b.pressed.connect(func() -> void: set_view_mode(id))
		g.add_child(b)
		_view_buttons[id] = b
	overlay.add_child(g)
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 2)
	overlay.add_child(_legend)
	_view_buttons["none"].button_pressed = true
	_refresh_legend("none")

func _build_right() -> void:
	_tabs = TabContainer.new()
	_root.add_child(_tabs)
	_tabs.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tabs.offset_left = -374; _tabs.offset_right = -16; _tabs.offset_top = 104; _tabs.offset_bottom = 400
	var s1 := ScrollContainer.new()
	s1.name = tr("Plot")
	s1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspect_box = VBoxContainer.new()
	_inspect_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect_box.add_theme_constant_override("separation", 5)
	s1.add_child(_inspect_box)
	_tabs.add_child(s1)
	var s2 := ScrollContainer.new()
	s2.name = tr("Orders")
	s2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_orders_box = VBoxContainer.new()
	_orders_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orders_box.add_theme_constant_override("separation", 8)
	s2.add_child(_orders_box)
	_tabs.add_child(s2)
	_tabs.tab_changed.connect(func(i: int) -> void:
		UITheme.reveal(_tabs.get_tab_control(i), 0.2)
		_fit_details())
	_root.resized.connect(_fit_details)
	_inspect_box.minimum_size_changed.connect(_fit_details, CONNECT_DEFERRED)
	_orders_box.minimum_size_changed.connect(_fit_details, CONNECT_DEFERRED)

func _fit_details() -> void:
	var content := _orders_box if _tabs.current_tab == 1 else _inspect_box
	var target := content.get_combined_minimum_size().y + 70.0
	var height := clampf(target, 148.0, _root.size.y - 146.0)
	if is_equal_approx(height, _detail_height): return
	_detail_height = height
	if _detail_motion: _detail_motion.kill()
	_detail_motion = _tabs.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_detail_motion.tween_property(_tabs, "size:y", height, 0.25)

func _build_bottom() -> void:
	_hint = UITheme.label("", 14, UITheme.MUTED)
	set_life_armed(false)
	_hint.add_theme_stylebox_override("normal", UITheme.box(Color("101b2cf2"), UITheme.BORDER, 3, 1, 4))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -360
	_hint.offset_right = 360
	_hint.offset_top = -28
	_hint.offset_bottom = -4
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)

func set_life_armed(armed: bool) -> void:
	var zh := Settings.language == "zh_CN"
	if armed:
		_hint.text = "已选中生灵点 · 左键连续投放 · 右键取消" if zh else "Life selected · Left-click plots to plant · Right-click to cancel"
	else:
		_hint.text = "按住右键打开轮盘 · 在生灵点分区松开即可选取" if zh else "Hold right-click to open the wheel · Release over Life to select it"

func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 100
	_toast_box.offset_left = -220
	_toast_box.offset_right = 220
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)
	_title_card = VBoxContainer.new()
	_title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title_card.offset_left = -260
	_title_card.offset_right = 260
	_title_card.offset_top = 145
	_title_card.offset_bottom = 222
	_title_card.add_theme_constant_override("separation", -3)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_name = UITheme.label("", 37, UITheme.CREAM, true)
	_biome_subtitle = UITheme.label("", 19, UITheme.JADE)
	for part: Label in [_biome_name, _biome_subtitle]:
		part.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		part.add_theme_color_override("font_outline_color", Color("102230"))
		part.add_theme_constant_override("outline_size", 5)
		_title_card.add_child(part)
	_title_card.modulate.a = 0.0
	_root.add_child(_title_card)

# ================================================================ refresh
func _on_inventory_changed() -> void:
	if _inventory_queued: return
	_inventory_queued = true
	_apply_inventory.call_deferred()

func _apply_inventory() -> void:
	_inventory_queued = false
	_refresh_inventory()
	_refresh_order_counts()
	_inspect_dirty = true

func _queue_orders() -> void:
	if _orders_queued: return
	_orders_queued = true
	_refresh_orders.call_deferred()

func set_biome(id: String, new_view: Node3D) -> void:
	biome = id
	view = new_view
	view.hovered.connect(func(_c: Vector2i) -> void:
		if _inspect_cell() != _last_inspect_cell: _inspect_dirty = true)
	if build_type != "": view.set_build_type(build_type)
	var mode: String = "none"
	for k: String in _view_buttons:
		if _view_buttons[k].button_pressed: mode = k
	if build_type == "": view.set_overlay(mode)
	_refresh_biome_tabs()
	_inspect_dirty = true
	var sub: String = str(Data.biomes[id].get("subtitle", ""))
	_biome_name.text = Data.biome_name(id)
	_biome_subtitle.text = sub
	if _title_motion: _title_motion.kill()
	_title_motion = _title_card.create_tween().set_trans(Tween.TRANS_SINE)
	var tw := _title_motion
	_title_card.modulate.a = 0.0
	tw.tween_property(_title_card, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.2)
	tw.tween_property(_title_card, "modulate:a", 0.0, 0.8)

func _refresh_biome_tabs() -> void:
	for id: String in _biome_buttons:
		var b: Button = _biome_buttons[id]
		b.button_pressed = id == biome
		var n: int = Sim.machines_in(id).size()
		b.text = "%s (%d)" % [Data.biome_name(id), n]
	var w: Dictionary = Sim.weather.get(biome, {})
	if w.is_empty():
		_weather_label.text = tr("Weather: calm")
	else:
		var eff: Dictionary = Data.effects[w.effect]
		_weather_label.text = tr("Weather: %s (%ds) — %s") % [eff.name, int(w.remaining), eff.description]
	_weather_label.tooltip_text = _weather_label.text

func _refresh_top() -> void:
	_money.text = "¤ %d" % Sim.money
	_rep.text = "%d" % Sim.reputation
	var zh := Settings.language == "zh_CN"
	var ratio := 0.0
	if not Land.tide_state.is_empty():
		var row := int(Land.tide_state.row)
		ratio = float(row) / Land.GRID
		_tide_text.text = ("潮汐推进  %d / %d" if zh else "Wave  %d / %d") % [row, Land.GRID]
	elif Settings.tide_seconds > 0.0:
		ratio = clampf(Land.tide_elapsed / Settings.tide_seconds, 0.0, 1.0)
		_tide_text.text = ("距下次潮汐  %d 秒" if zh else "Next tide in %ds") % ceili(maxf(0.0, Settings.tide_seconds - Land.tide_elapsed))
	else:
		_tide_text.text = "手动触发" if zh else "Manual tide"
	if _tide_bar_holder.get_child_count() == 0:
		_tide_bar_holder.add_child(UITheme.bar(ratio, UITheme.JADE, 170, 12))
	else:
		var fill := _tide_bar_holder.get_child(0).get_node("Fill") as ColorRect
		if _tide_motion: _tide_motion.kill()
		_tide_motion = fill.create_tween().set_trans(Tween.TRANS_SINE)
		_tide_motion.tween_property(fill, "size:x", 168.0 * ratio, 0.18)
	for sp: float in _speed_buttons:
		var active: bool = (Sim.paused and sp == 0.0) or (not Sim.paused and is_equal_approx(Sim.time_scale, sp))
		_speed_buttons[sp].set_pressed_no_signal(active)
	_refresh_biome_tabs()

func _refresh_inventory() -> void:
	var empty := _inv_box.get_node_or_null("Empty")
	for id: String in Data.items:
		var count: int = Sim.count(id)
		var row: HBoxContainer = _inventory_rows.get(id)
		if count <= 0:
			if row:
				_inv_box.remove_child(row)
				row.queue_free()
				_inventory_rows.erase(id)
			continue
		if not row:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var icon := TextureRect.new()
			icon.texture = Art.item(id)
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var name_l := UITheme.label(Data.item_name(id), 14)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_l)
			var quantity := UITheme.label("", 15, UITheme.BRASS)
			quantity.name = "Quantity"
			row.add_child(quantity)
			_inv_box.add_child(row)
			_inventory_rows[id] = row
		var quantity: Label = row.get_node("Quantity")
		if quantity.text != str(count):
			quantity.text = str(count)
			UITheme.reveal(quantity, 0.22)
	if _inventory_rows.is_empty() and empty == null:
		empty = UITheme.label(tr("Empty larder."), 13, UITheme.MUTED)
		empty.name = "Empty"
		_inv_box.add_child(empty)
	elif not _inventory_rows.is_empty() and empty:
		_inv_box.remove_child(empty)
		empty.queue_free()
	_pantry_scroll.custom_minimum_size.y = minf(360, maxi(1, _inventory_rows.size()) * 27)

func _process(delta: float) -> void:
	if not Sim.running: return
	var row := int(Land.tide_state.get("row", -1))
	if row != _last_wave_row:
		_last_wave_row = row
		_refresh_top()
	var t: int = int(Sim.game_time)
	if _last_clock_second != t:
		_last_clock_second = t
		_clock.text = tr("Day %d · %02d:%02d") % [t / 600 + 1, (t % 600) / 60 * 2 + 6, (t % 60)]
	_inspect_timer -= delta
	var interacting := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _tabs.get_global_rect().has_point(_root.get_global_mouse_position())
	if not interacting and _tabs.current_tab == 0 and (_inspect_timer <= 0.0 or _inspect_dirty):
		_inspect_timer = 0.3
		var c: Vector2i = _inspect_cell()
		if _inspect_dirty or c != _last_inspect_cell or (not Sim.paused and _has_live_machine(c)):
			_refresh_inspector()
		_inspect_dirty = false
	if Engine.get_process_frames() % 30 == 0:
		_refresh_order_timers()
		_refresh_biome_tabs()

func _has_live_machine(c: Vector2i) -> bool:
	return Land.in_grid(c) and (not Sim.machine_at(biome, c).is_empty() or not Sim.growth_at(biome,c).is_empty())

func _inspect_cell() -> Vector2i:
	if view == null: return Vector2i(-1, -1)
	if build_type == "" and Land.in_grid(view.selected_cell): return view.selected_cell
	return view.hover_cell if Land.in_grid(view.hover_cell) else view.selected_cell

# ================================================================ inspector
func _refresh_inspector() -> void:
	var c: Vector2i = _inspect_cell()
	_last_inspect_cell = c
	_fit_details()
	for ch in _inspect_box.get_children():
		_inspect_box.remove_child(ch)
		ch.queue_free()
	if not Land.in_grid(c):
		_inspect_box.add_child(UITheme.label(tr("Hover or click a plot"), 18, UITheme.BRASS, true))
		var help := UITheme.label(tr("Plots have a base class, variant and level. Life and Ember are natural energies; Silence and Eternity are artificial technologies. Tides replenish or draw energy, then trigger paired flips or transformations between different variants of the same base class and level. Heat and moisture determine temperature independently."), 13, UITheme.MUTED)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.custom_minimum_size = Vector2(300, 0)
		_inspect_box.add_child(help)
		return
	var p: Dictionary = Land.get_parcel(biome, c)
	var head := HBoxContainer.new()
	var title := UITheme.label(str(p.land_name), 20, UITheme.CREAM, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.label("%s%d" % [char(65 + c.x), c.y + 1], 14, UITheme.MUTED))
	_inspect_box.add_child(head)
	var zh := Settings.language == "zh_CN"
	var soil := ("生灵浓度 %d　·　支撑 %d" if zh else "Life concentration %d  ·  Support %d") % [p.life_concentration, p.sheet.support]
	if p.stabilized: soil += "　·　稳固" if zh else "  ·  Stabilized"
	_inspect_box.add_child(UITheme.label(soil, 15, UITheme.JADE))
	var machine := Sim.machine_at(biome, c)
	if not machine.is_empty():
		_machine_section(machine)
	else:
		var growth := Sim.growth_at(biome, c)
		_section("生灵培育" if zh else "Flora growth")
		if not growth.is_empty():
			var details := UITheme.label(Sim.growth_text(growth), 14, UITheme.GOOD)
			details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_inspect_box.add_child(details)
		if growth.is_empty() or growth.stage in ["phase1", "phase2_2"]:
			var plant := Button.new()
			plant.text = ("投放 1 点生灵" if zh else "Plant 1 Life") if growth.is_empty() else ("追加 1 点生灵" if zh else "Add 1 Life")
			plant.tooltip_text = Sim.can_add_life(biome, c)
			plant.disabled = plant.tooltip_text != ""
			plant.pressed.connect(func() -> void: life_placement_requested.emit(c))
			_inspect_box.add_child(plant)
	var temp_def: Dictionary = Data.temperatures[p.temperature]
	var tl := UITheme.label("%s · %s" % [temp_def.name, Data.biome_name(biome)], 14, Color(str(temp_def.color)))
	tl.tooltip_text = str(temp_def.description)
	tl.mouse_filter = Control.MOUSE_FILTER_PASS
	_inspect_box.add_child(tl)
	if p.temperature != p.base_temperature:
		_inspect_box.add_child(UITheme.label(tr("(naturally %s)") % Data.temperatures[p.base_temperature].name, 12, UITheme.MUTED))
	if str(p.deposit) != "":
		var dh := HBoxContainer.new()
		var di := TextureRect.new()
		di.texture = Art.item(p.deposit)
		di.custom_minimum_size = Vector2(20, 20)
		di.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dh.add_child(di)
		dh.add_child(UITheme.label(tr("%s deposit") % Data.item_name(p.deposit), 14, UITheme.BRASS))
		_inspect_box.add_child(dh)
	var rule: Dictionary = p.get("sheet", {})
	if not rule.is_empty():
		_inspect_box.add_child(UITheme.label("基础：%s · 等级 %s · %s生成" % [rule.base, rule.level, rule.generation], 13))
		_inspect_box.add_child(UITheme.label("潮汐：%s · 补正（生灵/余烬）：%s/%s" % [rule.get("tide_description", rule.tide), rule.correction[0], rule.correction[1]], 12))
		_inspect_box.add_child(UITheme.label("适应度（生灵/余烬）：%s/%s" % [rule.adaptation[0], rule.adaptation[1]], 12))
		var attachment: String = str(rule.attachment)
		if attachment != "/":
			_inspect_box.add_child(UITheme.label("附着物：%s%s" % [attachment, "（已清理）" if p.attachment_cleared else " · " + str(rule.presence)], 13))
			_inspect_box.add_child(UITheme.label("离场：" + str(rule.departure), 12))
			if not p.attachment_cleared:
				var clear_button := Button.new()
				clear_button.text = "清理附着物"
				clear_button.pressed.connect(func() -> void: Land.clear_attachment(biome, c); _inspect_dirty = true)
				_inspect_box.add_child(clear_button)

	var condense := Button.new()
	condense.text = tr("Condense Ember")
	condense.tooltip_text = "消耗地块的 20 点余烬，获得 1 点库存余烬。" if zh else "Spend 20 Ember from this plot to gain 1 Ember."
	condense.disabled = float(p.elements.ember) < 20
	condense.pressed.connect(func() -> void: Sim.condense(biome, c, "ember"); _inspect_dirty = true)
	_inspect_box.add_child(condense)
	if float(p.elements.eternity) > 0:
		var archive := Button.new()
		archive.text = "永恒：记录组成"
		archive.pressed.connect(func() -> void: Sim.record_eternity(biome, c); _inspect_dirty = true)
		_inspect_box.add_child(archive)
		var restore := Button.new()
		restore.text = "永恒：完整重塑"
		restore.disabled = not Sim.eternity_records.has(Land.parcel_key(biome, c))
		restore.tooltip_text = "恢复已记录的地块、附着物、能量与机械状态。缺失或不同的机械需支付建造资金与材料。"
		restore.pressed.connect(func() -> void: Sim.reshape_eternity(biome, c); _inspect_dirty = true)
		_inspect_box.add_child(restore)
	_section("自然能量与人工技术")
	for e: String in Data.element_ids:
		var row := HBoxContainer.new()
		var ec := Color(str(Data.elements[e].color))
		var nl := UITheme.label(str(Data.elements[e].name), 13, ec.lightened(0.15))
		nl.custom_minimum_size = Vector2(52, 0)
		nl.tooltip_text = str(Data.elements[e].description)
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(nl)
		row.add_child(UITheme.bar(float(p.elements[e]) / 100.0, ec, 170, 11, float(p.base_elements[e]) / 100.0))
		var delta_v: int = int(p.elements[e]) - int(p.base_elements[e])
		var vt: String = "%d" % int(p.elements[e]) + ((" (%+d)" % delta_v) if delta_v != 0 else "")
		row.add_child(UITheme.label(vt, 12, UITheme.CREAM if delta_v == 0 else (UITheme.GOOD if delta_v > 0 else Color("8ab8e0"))))
		_inspect_box.add_child(row)
	_section(tr("Plot attributes"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	for a: Array in [[tr("Richness"), "×%.2f" % p.richness], [tr("Stability"), "%d%%" % int(p.stability * 100)], [tr("Conductivity"), "×%.2f" % p.conductivity], [tr("Fertility"), "%d%%" % int(p.fertility * 100)]]:
		var al := UITheme.label("%s  %s" % [a[0], a[1]], 13)
		g.add_child(al)
	_inspect_box.add_child(g)
	_section(tr("Bound effects"))
	if p.effects.is_empty():
		_inspect_box.add_child(UITheme.label(tr("None"), 13, UITheme.MUTED))
	for ef: Dictionary in p.effects:
		var src: String = {"seed": tr("natural"), "machine": tr("machine aura"), "weather": tr("weather %ds") % int(ef.remaining)}.get(ef.source, ef.source)
		var el := UITheme.label("● %s  · %s" % [ef.name, src], 13, Color(str(ef.color)))
		el.tooltip_text = _effect_tooltip(str(ef.effect))
		el.mouse_filter = Control.MOUSE_FILTER_PASS
		_inspect_box.add_child(el)

func _section(text: String) -> void:
	var l := UITheme.label(text, 14, UITheme.BRASS, true)
	_inspect_box.add_child(HSeparator.new())
	_inspect_box.add_child(l)

func _machine_section(m: Dictionary) -> void:
	var def: Dictionary = Data.machines[m.type]
	var zh := Settings.language == "zh_CN"
	_section(str(def.name))
	var status := UITheme.label(str(m.status), 14, UITheme.GOOD if m.enabled else UITheme.MUTED)
	_inspect_box.add_child(status)
	var description := UITheme.label(tr(str(def.description)), 14, UITheme.CREAM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_box.add_child(description)
	var total: String
	match str(m.type):
		"propagator": total = ("累计播种 %d 格次" if zh else "Plots sown in total: %d") % int(m.cycles)
		"collector": total = ("累计收集 %d 点生灵" if zh else "Life collected: %d") % int(m.cycles)
		"extractor": total = ("累计 %d 罐 · 下罐进度 %d / 8" if zh else "%d canisters · Next canister %d / 8") % [int(m.cycles), int(m.carry.get("concentration", 0))]
	_inspect_box.add_child(UITheme.label(total, 14, UITheme.JADE))
	var toggle := Button.new()
	toggle.text = tr("Pause") if m.enabled else tr("Resume")
	toggle.pressed.connect(func() -> void: Sim.toggle_enabled(m.uid); _inspect_dirty = true)
	_inspect_box.add_child(toggle)

func _element_text(d: Dictionary) -> String:
	var parts: PackedStringArray = []
	for e: String in d: parts.append("%s %+d" % [Data.elements[e].name, int(d[e])])
	return ", ".join(parts)

func _effect_tooltip(id: String) -> String:
	var eff: Dictionary = Data.effects[id]
	var t: String = "%s\n%s" % [eff.name, eff.description]
	if not eff.get("elements", {}).is_empty(): t += tr("\nElements: ") + _element_text(eff.elements)
	for s: String in eff.get("stats", {}): t += "\n%s ×%.2f" % [Data.stat_info[s].name, float(eff.stats[s])]
	for a: String in eff.get("parcel", {}): t += "\n%s %+.2f" % [a.capitalize(), float(eff.parcel[a])]
	return t

# ================================================================ orders
func _refresh_orders() -> void:
	_orders_queued = false
	_order_rows.clear()
	for ch in _orders_box.get_children():
		_orders_box.remove_child(ch)
		ch.queue_free()
	_orders_box.add_child(UITheme.label(tr("Orders from the neighbours"), 18, UITheme.BRASS, true))
	for i in range(Sim.orders.size()):
		var o: Dictionary = Sim.orders[i]
		var t: Dictionary = Sim._order_template(o.id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG_SOFT, UITheme.BORDER, 8, 2, 10))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		card.add_child(v)
		v.add_child(UITheme.label(str(t.name), 16, UITheme.CREAM, true))
		v.add_child(UITheme.label(str(t.customer), 12, UITheme.MUTED))
		var need_labels := {}
		for id: String in t.needs:
			var row := HBoxContainer.new()
			var icon := TextureRect.new()
			icon.texture = Art.item(id)
			icon.custom_minimum_size = Vector2(20, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)
			var amount := UITheme.label("", 13)
			need_labels[id] = amount
			row.add_child(amount)
			v.add_child(row)
		var foot := HBoxContainer.new()
		foot.add_child(UITheme.label("¤%d  ★+%d" % [int(t.reward), int(t.rep)], 14, UITheme.BRASS))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(sp)
		var timer := UITheme.label("", 12, UITheme.MUTED)
		foot.add_child(timer)
		var b := Button.new()
		b.text = tr("Deliver")
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not Sim.has_items(t.needs)
		var idx: int = i
		UITheme.button_motion(b)
		var template_id: String = o.id
		b.pressed.connect(func() -> void:
			if idx < Sim.orders.size() and Sim.orders[idx].id == template_id:
				Sim.deliver(idx))
		foot.add_child(b)
		v.add_child(foot)
		_orders_box.add_child(card)
		_order_rows.append({"needs": t.needs, "labels": need_labels, "deliver": b, "timer": timer})
	_refresh_order_counts()
	_refresh_order_timers()

func _refresh_order_counts() -> void:
	for row in _order_rows:
		for id: String in row.needs:
			var label: Label = row.labels[id]
			var need: int = row.needs[id]
			var have: int = Sim.count(id)
			label.text = "%s  %d / %d" % [Data.item_name(id), mini(have, need), need]
			label.add_theme_color_override("font_color", UITheme.GOOD if have >= need else UITheme.CREAM)
		row.deliver.disabled = not Sim.has_items(row.needs)

func _refresh_order_timers() -> void:
	for i in mini(_order_rows.size(), Sim.orders.size()):
		var seconds := int(Sim.orders[i].remaining)
		_order_rows[i].timer.text = tr("%d:%02d left  ") % [seconds / 60, seconds % 60]

# ================================================================ actions
func select_build(_id: String) -> void:
	build_type = ""
	if view: view.set_build_type("")
	_inspect_dirty = true

func set_view_mode(mode: String) -> void:
	for k: String in _view_buttons: _view_buttons[k].button_pressed = k == mode
	if view and build_type == "": view.set_overlay(mode)
	_refresh_legend(mode)

func _refresh_legend(mode: String) -> void:
	if _legend == null: return
	for ch in _legend.get_children(): ch.queue_free()
	match mode:
		"life":
			var key := "生灵浓度　紫 < 0 · 青 0 · 绿 ≥ 1 · 金 ≥ 8" if Settings.language == "zh_CN" else "Life concentration: violet < 0 · teal 0 · green ≥ 1 · gold ≥ 8"
			var text := UITheme.label(key, 12, UITheme.MUTED)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.custom_minimum_size.x = 210
			_legend.add_child(text)
		"ember", "silence", "eternity":
			var ec := Color(str(Data.elements[mode].color))
			var h := HBoxContainer.new()
			h.add_child(UITheme.label("0", 11, UITheme.MUTED))
			for i in range(10):
				var sw := ColorRect.new()
				sw.custom_minimum_size = Vector2(16, 10)
				sw.color = Color("1c1a1e").lerp(ec, 0.15 + i / 9.0 * 0.85)
				h.add_child(sw)
			h.add_child(UITheme.label("100", 11, UITheme.MUTED))
			_legend.add_child(h)
			var d := UITheme.label(str(Data.elements[mode].description), 11, UITheme.MUTED)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(210, 0)
			_legend.add_child(d)
		"temperature":
			var g := GridContainer.new()
			g.columns = 2
			for t: String in ["freezing", "cold", "humid", "dry", "hot", "scorching"]:
				var row := HBoxContainer.new()
				var sw := ColorRect.new()
				sw.custom_minimum_size = Vector2(12, 12)
				sw.color = Color(str(Data.temperatures[t].color))
				row.add_child(sw)
				row.add_child(UITheme.label(str(Data.temperatures[t].name), 12))
				g.add_child(row)
			_legend.add_child(g)
		"effects":
			_legend.add_child(UITheme.label(tr("Plots tinted by their bound effect."), 11, UITheme.MUTED))
		_:
			_legend.add_child(UITheme.label(tr("Plot colour = land type."), 11, UITheme.MUTED))

func cycle_view_mode() -> void:
	var cur: int = 0
	for i in range(VIEW_MODES.size()):
		if _view_buttons[VIEW_MODES[i][0]].button_pressed: cur = i
	set_view_mode(VIEW_MODES[(cur + 1) % VIEW_MODES.size()][0])

func _set_speed(sp: float) -> void:
	if _tutorial_time_locked: return
	if sp == 0.0: Sim.paused = not Sim.paused
	else:
		Sim.paused = false
		Sim.time_scale = sp
	_refresh_top()

func _top_action(action: String) -> void:
	match action:
		"tide":
			if Land.tide_state.is_empty(): Land.start_tide()
		"glossary": Settings.open_glossary()
		"settings": Settings.open()
		"save": Sim.save_game()
		"load":
			if Sim.load_game(): travel_requested.emit(biome)
			else: show_toast(tr("No save found"), UITheme.BAD)
		"menu": menu_requested.emit()

func show_toast(text: String, color: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG, color.darkened(0.3), 4, 1, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 14, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 4: _toast_box.get_child(0).free()
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
