extends Node
## Renders every machine / item SVG into docs/contact_sheet_*.png (headless OK).
func _ready() -> void:
	_sheet("res://assets/machines", 0.75, 6, "res://docs/contact_sheet_machines.png", Color("2a2328"))
	_sheet("res://assets/items", 1.5, 10, "res://docs/contact_sheet_items.png", Color("2a2328"))
	get_tree().quit()

func _sheet(dir: String, scale: float, cols: int, out: String, bg: Color) -> void:
	var files: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".svg"): files.append(f)
	if files.is_empty(): return
	files.sort()
	var imgs: Array = []
	var cw: int = 0
	var ch: int = 0
	for f in files:
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(dir.path_join(f)), scale)
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
		cw = maxi(cw, img.get_width()); ch = maxi(ch, img.get_height())
	var rows: int = int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * (cw + 8), rows * (ch + 8), false, Image.FORMAT_RGBA8)
	sheet.fill(bg)
	for i in imgs.size():
		var img: Image = imgs[i]
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * (cw + 8) + 4, (i / cols) * (ch + 8) + 4))
	sheet.save_png(ProjectSettings.globalize_path(out))
	print("sheet ", out, " ", files)
