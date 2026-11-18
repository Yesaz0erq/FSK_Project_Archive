extends Node
## Writes contact sheets from the catalog's actual machine portraits and the item sources.

func _ready() -> void:
	var machines: Array[Image] = []
	for id: String in Data.machine_order:
		var image := Image.new()
		var bytes := FileAccess.get_file_as_bytes("res://assets/machines/baked/%s_portrait.png" % id)
		if image.load_png_from_buffer(bytes) != OK:
			push_error("Missing machine portrait for %s" % id)
			get_tree().quit(1)
			return
		machines.append(image)
	var items: Array[Image] = []
	var files := DirAccess.get_files_at("res://assets/items")
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".svg"): continue
		var image := Image.new()
		var source := FileAccess.get_file_as_string("res://assets/items/" + filename)
		if image.load_svg_from_string(source, 1.5) != OK:
			push_error("Cannot rasterize %s" % filename)
			get_tree().quit(1)
			return
		items.append(image)
	var ok := _sheet(machines, 5, "res://docs/contact_sheet_machines.png", Color("17273b"))
	ok = _sheet(items, 10, "res://docs/contact_sheet_items.png", Color("2a2328")) and ok
	get_tree().quit(0 if ok else 1)

func _sheet(images: Array[Image], columns: int, out: String, background: Color) -> bool:
	if images.is_empty(): return false
	var size := Vector2i.ZERO
	for source: Image in images:
		source.convert(Image.FORMAT_RGBA8)
		size = size.max(source.get_size())
	var slot := size + Vector2i(8, 8)
	var rows := ceili(images.size() / float(columns))
	var sheet := Image.create(columns * slot.x, rows * slot.y, false, Image.FORMAT_RGBA8)
	sheet.fill(background)
	for i in images.size():
		var img := images[i]
		var cell := Vector2i(i % columns, floori(i / float(columns)))
		var origin := cell * slot + (slot - img.get_size()) / 2
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), origin)
	if sheet.save_png(ProjectSettings.globalize_path(out)) != OK: return false
	print(out, " — ", images.size(), " entries")
	return true
