extends CanvasLayer
## In-game interface. Built in code so every number comes straight from Sim / Land / Data.

signal travel_requested(biome: String)
signal menu_requested

var view: Node3D                       # current BiomeView (set by game.gd)
var biome: String = "forest"
var build_type: String = ""
var _root: Control
var _money: Label
var _rep: Label
var _energy_text: Label
var _energy_bar_holder: Control
var _clock: Label
var _speed_buttons: Dictionary = {}
var _biome_buttons: Dictionary = {}
var _inv_box: VBoxContainer
var _inspect_box: VBoxContainer
var _orders_box: VBoxContainer
var _tabs: TabContainer
var _build_bar: HBoxContainer
var _build_cards: Dictionary = {}
var _view_buttons: Dictionary = {}
var _toast_box: VBoxContainer
var _title_card: Label
var _weather_label: Label
var _hint: Label
var _legend: VBoxContainer
var _inspect_dirty: bool = true
var _inspect_timer: float = 0.0
var _last_inspect_cell := Vector2i(-2, -2)

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
	Sim.inventory_changed.connect(_refresh_inventory)
	Sim.inventory_changed.connect(_on_inventory_changed)
	Sim.stats_changed.connect(_refresh_top)
	Sim.stats_changed.connect(_refresh_build_cards)
	Sim.orders_changed.connect(_refresh_orders)
	Sim.machines_changed.connect(func(_b: String) -> void: _inspect_dirty = true)
	Sim.weather_changed.connect(func(_b: String) -> void: _refresh_biome_tabs())
	Sim.toast.connect(show_toast)
	Land.tide_started.connect(func(edge: int) -> void: show_toast(tr("Tide arriving: %s") % [tr(["West", "East", "North", "South"][edge])], UITheme.BRASS))
	Land.parcels_changed.connect(func(b: String) -> void: if b == biome: _inspect_dirty = true)
	_refresh_inventory()
	_refresh_top()
	_refresh_orders()
	_refresh_build_cards()

# ================================================================ layout
func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p

func _build_top_bar() -> void:
	var p := _panel(_root)
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 10; p.offset_right = -10; p.offset_top = 8; p.offset_bottom = 70
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -4)
	logo.add_child(UITheme.label(tr("Project Archive"), 22, UITheme.BRASS, true))
	_clock = UITheme.label(tr("Day 1 · 00:00"), 12, UITheme.MUTED)
	logo.add_child(_clock)
	h.add_child(logo)
	h.add_child(VSeparator.new())
	_money = _stat(h, tr("Funds"), "¤ 0", UITheme.BRASS)
	_rep = _stat(h, tr("Reputation"), "0", Color("e49aa8"))
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	ev.add_child(UITheme.label(tr("Sap energy"), 11, UITheme.MUTED))
	_energy_bar_holder = Control.new()
	_energy_bar_holder.custom_minimum_size = Vector2(170, 12)
	ev.add_child(_energy_bar_holder)
	_energy_text = UITheme.label("", 12, Color("8ad0f0"))
	ev.add_child(_energy_text)
	h.add_child(ev)
	h.add_child(VSeparator.new())
	for s: Array in [["II", 0.0], ["1x", 1.0], ["3x", 3.0]]:
		var b := Button.new()
		b.text = s[0]
		b.custom_minimum_size = Vector2(40, 0)
		b.focus_mode = Control.FOCUS_NONE
		var sp: float = s[1]
		b.pressed.connect(func() -> void: _set_speed(sp))
		h.add_child(b)
		_speed_buttons[sp] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	var bh := HBoxContainer.new()
	for i in range(Data.biome_order.size()):
		var id: String = Data.biome_order[i]
		var b := Button.new()
		b.text = "%s  F%d" % [Data.biome_name(id), i + 1]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pressed.connect(func() -> void: travel_requested.emit(id))
		bh.add_child(b)
		_biome_buttons[id] = b
	bv.add_child(bh)
	_weather_label = UITheme.label("", 12, UITheme.MUTED)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_weather_label)
	h.add_child(bv)
	h.add_child(VSeparator.new())
	for s2: Array in [[tr("Tide"), "tide"], ["术语", "glossary"], [tr("Settings"), "settings"], [tr("Save"), "save"], [tr("Load"), "load"], [tr("Menu"), "menu"]]:
		var b := Button.new()
		b.text = s2[0]
		b.focus_mode = Control.FOCUS_NONE
		var action: String = s2[1]
		b.pressed.connect(func() -> void: _top_action(action))
		h.add_child(b)

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
	p.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	p.offset_left = 10; p.offset_right = 250; p.offset_top = 80; p.offset_bottom = -176
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UITheme.label(tr("Shared Larder"), 18, UITheme.BRASS, true))
	v.add_child(UITheme.label(tr("All four scenes share these goods."), 11, UITheme.MUTED))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_inv_box = VBoxContainer.new()
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_box.add_theme_constant_override("separation", 2)
	sc.add_child(_inv_box)
	v.add_child(HSeparator.new())
	v.add_child(UITheme.label(tr("Land view  (V)"), 14, UITheme.BRASS, true))
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
		b.pressed.connect(func() -> void: set_view_mode(id))
		g.add_child(b)
		_view_buttons[id] = b
	v.add_child(g)
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 2)
	v.add_child(_legend)
	_view_buttons["none"].button_pressed = true
	_refresh_legend("none")

func _build_right() -> void:
	_tabs = TabContainer.new()
	_root.add_child(_tabs)
	_tabs.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_tabs.offset_left = -360; _tabs.offset_right = -10; _tabs.offset_top = 80; _tabs.offset_bottom = -176
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

func _build_bottom() -> void:
	var p := _panel(_root)
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_left = 10; p.offset_right = -10; p.offset_top = -168; p.offset_bottom = -26
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UITheme.label(tr("Plant-machines"), 16, UITheme.BRASS, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.label(tr("Click a plot to place · Right-click / Esc to cancel · hover a card for details"), 12, UITheme.MUTED))
	v.add_child(head)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_build_bar = HBoxContainer.new()
	_build_bar.add_theme_constant_override("separation", 6)
	sc.add_child(_build_bar)
	var i: int = 0
	for id: String in Data.machine_order:
		i += 1
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 104)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = _machine_tooltip(id)
		var mid: String = id
		b.pressed.connect(func() -> void: select_build(mid if build_type != mid else ""))
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.texture = Art.machine(id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0, 58)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon)
		var name_l := UITheme.label(str(Data.machines[id].name), 12, UITheme.CREAM)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(name_l)
		var cost_l := UITheme.label("", 11, UITheme.BRASS)
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cost_l.custom_minimum_size = Vector2(104, 0)
		cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(cost_l)
		b.add_child(vb)
		var key := UITheme.label(str(i % 10), 11, UITheme.MUTED)
		key.position = Vector2(6, 2)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)
		_build_bar.add_child(b)
		_build_cards[id] = {"button": b, "cost": cost_l, "icon": icon}
	_hint = UITheme.label(tr("Q/E rotate · WASD / middle-drag pan · wheel zoom · Space pause · R recipe · Del dismantle · F5 save"), 12, UITheme.MUTED)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-330, -22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	_hint.offset_top = -22
	_hint.offset_bottom = -4

func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 82
	_toast_box.offset_left = -220
	_toast_box.offset_right = 220
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)
	_title_card = UITheme.label("", 44, UITheme.CREAM, true)
	_title_card.set_anchors_preset(Control.PRESET_CENTER)
	_title_card.offset_left = -400; _title_card.offset_right = 400; _title_card.offset_top = -260; _title_card.offset_bottom = -180
	_title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_card.add_theme_color_override("font_outline_color", Color("1a1416"))
	_title_card.add_theme_constant_override("outline_size", 10)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate.a = 0.0
	_root.add_child(_title_card)

# ================================================================ refresh
func _on_inventory_changed() -> void:
	_inspect_dirty = true
	_refresh_orders()
	_refresh_build_cards()

func set_biome(id: String, new_view: Node3D) -> void:
	biome = id
	view = new_view
	view.hovered.connect(func(_c: Vector2i) -> void: _inspect_dirty = true)
	if build_type != "": view.set_build_type(build_type)
	var mode: String = "none"
	for k: String in _view_buttons:
		if _view_buttons[k].button_pressed: mode = k
	if build_type == "": view.set_overlay(mode)
	_refresh_biome_tabs()
	_inspect_dirty = true
	var sub: String = str(Data.biomes[id].get("subtitle", ""))
	_title_card.text = "%s\n%s" % [Data.biome_name(id), sub]
	_title_card.add_theme_font_size_override("font_size", 40)
	var tw := create_tween()
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

func _refresh_top() -> void:
	_money.text = "¤ %d" % Sim.money
	_rep.text = "%d" % Sim.reputation
	for ch in _energy_bar_holder.get_children(): ch.queue_free()
	var b := UITheme.bar(Sim.energy / Sim.energy_cap, Color("6fc0e0"), 170, 12)
	_energy_bar_holder.add_child(b)
	_energy_text.text = "%d / %d   +%.1f  −%.1f /s" % [int(Sim.energy), int(Sim.energy_cap), Sim.energy_in_rate, Sim.energy_out_rate]
	if Sim.power_ratio < 0.99: _energy_text.add_theme_color_override("font_color", UITheme.BAD)
	else: _energy_text.add_theme_color_override("font_color", Color("8ad0f0"))
	for sp: float in _speed_buttons:
		var active: bool = (Sim.paused and sp == 0.0) or (not Sim.paused and is_equal_approx(Sim.time_scale, sp))
		_speed_buttons[sp].modulate = Color(1.3, 1.15, 0.8) if active else Color.WHITE
	_refresh_biome_tabs()

func _refresh_inventory() -> void:
	for ch in _inv_box.get_children(): ch.queue_free()
	var ids: Array = Data.items.keys()
	var shown: int = 0
	for id: String in ids:
		var n: int = Sim.count(id)
		if n <= 0: continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = Art.item(id)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name_l := UITheme.label(Data.item_name(id), 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(UITheme.label(str(n), 15, UITheme.BRASS))
		_inv_box.add_child(row)
	if shown == 0: _inv_box.add_child(UITheme.label(tr("Empty larder."), 13, UITheme.MUTED))

func _refresh_build_cards() -> void:
	for id: String in _build_cards:
		var card: Dictionary = _build_cards[id]
		var def: Dictionary = Data.machines[id]
		var unlocked: bool = Sim.is_unlocked(id)
		var mats: String = Data.counts_text(def.get("materials", {}))
		if not unlocked:
			card.cost.text = tr("★ %d rep") % int(def.unlock_rep)
			card.cost.add_theme_color_override("font_color", UITheme.MUTED)
			card.icon.modulate = Color(0.35, 0.32, 0.32)
		else:
			var affordable: bool = Sim.money >= int(def.cost) and Sim.has_items(def.get("materials", {}))
			card.cost.text = "¤%d + %s" % [int(def.cost), _short_counts(def.get("materials", {}))]
			card.cost.add_theme_color_override("font_color", UITheme.BRASS if affordable else UITheme.BAD)
			card.icon.modulate = Color.WHITE
		card.button.button_pressed = build_type == id

func _process(delta: float) -> void:
	if not Sim.running: return
	var t: int = int(Sim.game_time)
	_clock.text = tr("Day %d · %02d:%02d") % [t / 600 + 1, (t % 600) / 60 * 2 + 6, (t % 60)]
	_inspect_timer -= delta
	if _inspect_timer <= 0.0 or _inspect_dirty:
		_inspect_timer = 0.3
		var c: Vector2i = _inspect_cell()
		if _inspect_dirty or c != _last_inspect_cell or _has_live_machine(c):
			_refresh_inspector()
		_inspect_dirty = false
	if Engine.get_process_frames() % 30 == 0:
		_refresh_order_timers()
		_refresh_biome_tabs()

func _has_live_machine(c: Vector2i) -> bool:
	return Land.in_grid(c) and not Sim.machine_at(biome, c).is_empty()

func _inspect_cell() -> Vector2i:
	if view == null: return Vector2i(-1, -1)
	if build_type == "" and Land.in_grid(view.selected_cell): return view.selected_cell
	return view.hover_cell if Land.in_grid(view.hover_cell) else view.selected_cell

# ================================================================ inspector
func _refresh_inspector() -> void:
	var c: Vector2i = _inspect_cell()
	_last_inspect_cell = c
	for ch in _inspect_box.get_children(): ch.queue_free()
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
		_inspect_box.add_child(UITheme.label("潮汐：%s · 补正（生灵/余烬）：%s/%s" % [rule.tide, rule.correction[0], rule.correction[1]], 12))
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
		_inspect_box.add_child(UITheme.label("活体建造所需生灵：%d" % Land.life_cost(biome, c), 12))
	var energy_actions := HBoxContainer.new()
	for kind: String in ["life", "ember"]:
		var button := Button.new()
		button.text = "凝聚" + str(Data.elements[kind].name)
		button.tooltip_text = "将20点地块自然能量浓度凝聚为1份可用能量。"
		button.disabled = float(p.elements[kind]) < 20
		button.pressed.connect(func() -> void: Sim.condense(biome, c, kind); _inspect_dirty = true)
		energy_actions.add_child(button)
	_inspect_box.add_child(energy_actions)
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
	var m: Dictionary = Sim.machine_at(biome, c)
	if not m.is_empty():
		_machine_section(m, p)
	elif build_type != "":
		_preview_section(build_type, p, c)

func _section(text: String) -> void:
	var l := UITheme.label(text, 14, UITheme.BRASS, true)
	_inspect_box.add_child(HSeparator.new())
	_inspect_box.add_child(l)

func _stat_rows(machine_id: String, st: Dictionary) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	for s: String in Data.stat_ids:
		var info: Dictionary = Data.stat_info[s]
		var v: float = float(st[s])
		var better: bool = (v >= 1.0) == bool(info.higher_is_better)
		var col: Color = UITheme.CREAM if absf(v - 1.0) < 0.02 else (UITheme.GOOD if better else UITheme.BAD)
		var nl := UITheme.label(str(info.name), 13)
		nl.custom_minimum_size = Vector2(64, 0)
		g.add_child(nl)
		var vl := UITheme.label("×%.2f  ⓘ" % v, 13, col)
		var tip: String = "%s — %s\n" % [info.name, info.description]
		for line: Array in st.breakdown.get(s, []):
			if line[2]: tip += "\n  %s:  %+.0f%%" % [line[0], float(line[1]) * 100.0]
			else: tip += "\n  %s:  ×%.2f" % [line[0], float(line[1])]
		vl.tooltip_text = tip
		vl.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(vl)
	_inspect_box.add_child(g)

func _machine_section(m: Dictionary, p: Dictionary) -> void:
	var def: Dictionary = Data.machines[m.type]
	_section(str(def.name))
	var st_col: Color = UITheme.GOOD if str(m.status) == tr("Working") or str(m.status) == tr("Radiating") else UITheme.BRASS
	if m.jammed: st_col = UITheme.BAD
	_inspect_box.add_child(UITheme.label(str(m.status), 14, st_col))
	var recipes: Array = def.get("recipes", [])
	if not recipes.is_empty():
		var r: Dictionary = Sim.recipe_of(m)
		var rh := HBoxContainer.new()
		if recipes.size() > 1:
			var prev := Button.new()
			prev.text = "◀"
			prev.focus_mode = Control.FOCUS_NONE
			prev.pressed.connect(func() -> void: Sim.cycle_recipe(m.uid, -1))
			rh.add_child(prev)
		var rl := UITheme.label(str(r.name), 14, UITheme.CREAM)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rh.add_child(rl)
		if recipes.size() > 1:
			var nxt := Button.new()
			nxt.text = "▶"
			nxt.focus_mode = Control.FOCUS_NONE
			nxt.pressed.connect(func() -> void: Sim.cycle_recipe(m.uid, 1))
			rh.add_child(nxt)
		_inspect_box.add_child(rh)
		var outputs: Dictionary = r.get("outputs", {})
		if def.kind == "extractor": outputs = {str(p.deposit): 1}
		var ins: String = Data.counts_text(r.get("inputs", {})) if not r.get("inputs", {}).is_empty() else "free"
		var outs: PackedStringArray = []
		if not outputs.is_empty(): outs.append(Data.counts_text(outputs))
		if float(r.get("energy_out", 0)) > 0: outs.append(tr("%d energy") % int(r.energy_out))
		var io: String = "%s  →  %s" % [ins, " + ".join(outs)]
		var iol := UITheme.label(io + "   (%.0fs)" % float(r.duration), 12, UITheme.MUTED)
		iol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		iol.custom_minimum_size = Vector2(300, 0)
		_inspect_box.add_child(iol)
		var pr := HBoxContainer.new()
		pr.add_child(UITheme.label(tr("Progress"), 12, UITheme.MUTED))
		pr.add_child(UITheme.bar(float(m.progress), Color("ffcf6b"), 200, 9))
		_inspect_box.add_child(pr)
	else:
		var aura: Dictionary = Data.effects.get(str(def.get("aura", "")), {})
		_inspect_box.add_child(UITheme.label(tr("Aura: %s — %s") % [aura.get("name", "?"), _element_text(aura.get("elements", {}))], 13, Color(str(aura.get("color", "#ffffff")))))
	var st: Dictionary = Sim.machine_stats(m)
	_stat_rows(m.type, st)
	var wr := HBoxContainer.new()
	wr.add_child(UITheme.label(tr("Wear"), 12, UITheme.MUTED))
	wr.add_child(UITheme.bar(float(m.wear) / 100.0, UITheme.BAD if float(m.wear) > 75 else Color("c9a070"), 200, 9))
	wr.add_child(UITheme.label("%d" % int(m.wear), 12))
	_inspect_box.add_child(wr)
	var bh := HBoxContainer.new()
	var rep := Button.new()
	rep.text = tr("Repair ¤%d") % Sim.repair_cost(m)
	rep.focus_mode = Control.FOCUS_NONE
	rep.disabled = float(m.wear) <= 0.0
	rep.pressed.connect(func() -> void: Sim.repair(m.uid))
	bh.add_child(rep)
	var tg := Button.new()
	tg.text = tr("Resume") if not m.enabled else tr("Pause")
	tg.focus_mode = Control.FOCUS_NONE
	tg.pressed.connect(func() -> void: Sim.toggle_enabled(m.uid))
	bh.add_child(tg)
	var dm := Button.new()
	dm.text = tr("Dismantle")
	dm.focus_mode = Control.FOCUS_NONE
	dm.pressed.connect(func() -> void: Sim.remove_machine(m.uid))
	bh.add_child(dm)
	_inspect_box.add_child(bh)

func _preview_section(id: String, p: Dictionary, c: Vector2i) -> void:
	var def: Dictionary = Data.machines[id]
	_section(tr("Place %s here?") % def.name)
	var reason: String = Sim.can_place(id, biome, c)
	if reason != "": _inspect_box.add_child(UITheme.label(reason, 13, UITheme.BAD))
	if def.kind != "support":
		_stat_rows(id, StatMath.machine_stats(id, p))
	else:
		var aura: Dictionary = Data.effects.get(str(def.get("aura", "")), {})
		_inspect_box.add_child(UITheme.label(tr("Will bind %s to the 3x3 around it: %s") % [aura.get("name", "?"), _element_text(aura.get("elements", {}))], 13, Color(str(aura.get("color", "#ffffff")))))

func _short_counts(d: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in d: parts.append("%d %s" % [int(d[id]), Data.item_name(id).split(" ")[0]])
	return ", ".join(parts)

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

func _machine_tooltip(id: String) -> String:
	var def: Dictionary = Data.machines[id]
	var t: String = "%s\n%s\n" % [def.name, def.description]
	t += tr("\nCost: ¤%d + %s") % [int(def.cost), Data.counts_text(def.get("materials", {}))]
	if float(def.get("power", 0)) > 0: t += tr("\nDraws %.1f energy/s while working") % float(def.power)
	if def.kind == "extractor": t += tr("\nMust stand on a deposit")
	for r: Dictionary in def.get("recipes", []):
		var outs: String = tr("deposit") if def.kind == "extractor" else Data.counts_text(r.get("outputs", {}))
		var line: String = "\n• %s: %s → %s" % [r.name, Data.counts_text(r.get("inputs", {})), outs]
		if float(r.get("energy_out", 0)) > 0: line += tr(" + %d energy") % int(r.energy_out)
		t += line + " (%.0fs)" % float(r.duration)
	var aff: Dictionary = def.get("affinity", {})
	if not aff.is_empty():
		var loves: PackedStringArray = []
		var hates: PackedStringArray = []
		for e: String in aff:
			if float(aff[e]) >= 1.4: loves.append(Data.elements[e].name)
			elif float(aff[e]) < 0: hates.append(Data.elements[e].name)
		if not loves.is_empty(): t += tr("\nThrives on: ") + ", ".join(loves)
		if not hates.is_empty(): t += tr("\nReversed by: ") + ", ".join(hates)
	for k: String in def.get("temperature", {}):
		var v: float = float(def.temperature[k])
		t += tr("\n%s plots: %s") % [Data.temperatures[k].name, tr("stops") if v <= 0.0 else tr("speed ×%.2f") % v]
	if def.has("aura"): t += tr("\nAura: %s (%s)") % [Data.effects[def.aura].name, _element_text(Data.effects[def.aura].get("elements", {}))]
	if def.get("living", false): t += tr("\nLiving: yield follows plot fertility")
	if int(def.get("unlock_rep", 0)) > 0: t += tr("\nUnlocks at %d reputation") % int(def.unlock_rep)
	return t

# ================================================================ orders
func _refresh_orders() -> void:
	for ch in _orders_box.get_children(): ch.queue_free()
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
		for id: String in t.needs:
			var row := HBoxContainer.new()
			var icon := TextureRect.new()
			icon.texture = Art.item(id)
			icon.custom_minimum_size = Vector2(20, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)
			var have: int = Sim.count(id)
			var need: int = int(t.needs[id])
			row.add_child(UITheme.label("%s  %d / %d" % [Data.item_name(id), mini(have, need), need], 13, UITheme.GOOD if have >= need else UITheme.CREAM))
			v.add_child(row)
		var foot := HBoxContainer.new()
		foot.add_child(UITheme.label("¤%d  ★+%d" % [int(t.reward), int(t.rep)], 14, UITheme.BRASS))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(sp)
		var timer := UITheme.label("", 12, UITheme.MUTED)
		timer.name = "Timer"
		timer.set_meta("index", i)
		foot.add_child(timer)
		var b := Button.new()
		b.text = tr("Deliver")
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not Sim.has_items(t.needs)
		var idx: int = i
		b.pressed.connect(func() -> void: Sim.deliver(idx))
		foot.add_child(b)
		v.add_child(foot)
		_orders_box.add_child(card)
	_refresh_order_timers()

func _refresh_order_timers() -> void:
	for card in _orders_box.get_children():
		var timer: Node = card.find_child("Timer", true, false)
		if timer == null: continue
		var i: int = int(timer.get_meta("index"))
		if i < Sim.orders.size():
			var r: int = int(Sim.orders[i].remaining)
			timer.text = tr("%d:%02d left  ") % [r / 60, r % 60]

# ================================================================ actions
func select_build(id: String) -> void:
	if id != "" and not Sim.is_unlocked(id):
		show_toast(tr("%s unlocks at %d reputation") % [Data.machines[id].name, int(Data.machines[id].unlock_rep)], UITheme.MUTED)
		id = ""
	build_type = id
	if view: view.set_build_type(id)
	if id != "":
		for ch in _legend.get_children(): ch.queue_free()
		_legend.add_child(UITheme.label(tr("Green = suits this machine, red = poor,\ndark = can't place."), 11, UITheme.MUTED))
	_refresh_build_cards()
	_inspect_dirty = true
	if id == "" and view:
		var mode: String = "none"
		for k: String in _view_buttons:
			if _view_buttons[k].button_pressed: mode = k
		view.set_overlay(mode)
		_refresh_legend(mode)

func set_view_mode(mode: String) -> void:
	for k: String in _view_buttons: _view_buttons[k].button_pressed = k == mode
	if view and build_type == "": view.set_overlay(mode)
	_refresh_legend(mode)

func _refresh_legend(mode: String) -> void:
	if _legend == null: return
	for ch in _legend.get_children(): ch.queue_free()
	match mode:
		"life", "ember", "silence", "eternity":
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
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.08, 0.09, 0.92), color.darkened(0.3), 8, 2, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 14, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 4: _toast_box.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
