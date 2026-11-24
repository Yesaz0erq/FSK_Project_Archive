extends Node
## Imported machine renders and rasterized inventory icons share one texture cache.

const Layout := preload("res://scripts/world/machine_sprites.gd")
const MACHINE_PATH := "res://assets/machines/baked/"
var _cache: Dictionary = {}

func machine(id: String) -> Texture2D:
	return _baked(id, true)

func machine_sheet(id: String) -> Texture2D:
	return _baked(id, false)

func _baked(id: String, portrait: bool) -> Texture2D:
	if not Data.machines.has(id): return _missing_machine(portrait)
	var path := MACHINE_PATH + id + ("_portrait.png" if portrait else ".png")
	if _cache.has(path): return _cache[path]
	if id.is_valid_identifier() and ResourceLoader.exists(path):
		_cache[path] = load(path)
		return _cache[path]
	return _missing_machine(portrait)

func _missing_machine(portrait: bool) -> Texture2D:
	var key := "missing_machine_portrait" if portrait else "missing_machine_sheet"
	if _cache.has(key): return _cache[key]
	# A small amber question mark identifies an unrecognized machine in an older save.
	var glyph := ["01110", "10001", "00001", "00110", "00100", "00000", "00100"]
	var frame := Image.create(Layout.FRAME.x, Layout.FRAME.y, false, Image.FORMAT_RGBA8)
	var ink := Color("29384c")
	var gold := Color("e4b67f")
	for y in glyph.size():
		for x in glyph[y].length():
			if glyph[y][x] != "1": continue
			var block := Rect2i(Layout.FRAME.x / 2 - 15 + x * 6, Layout.FRAME.y / 2 - 18 + y * 6, 6, 6)
			frame.fill_rect(block.grow(2), ink)
	for y in glyph.size():
		for x in glyph[y].length():
			if glyph[y][x] == "1":
				frame.fill_rect(Rect2i(Layout.FRAME.x / 2 - 15 + x * 6, Layout.FRAME.y / 2 - 18 + y * 6, 6, 6), gold)
	if portrait:
		_cache[key] = ImageTexture.create_from_image(frame.get_region(frame.get_used_rect().grow(4)))
	else:
		var atlas := Image.create(Layout.FRAME.x * Layout.POSES, Layout.FRAME.y * Layout.DIRECTIONS, false, Image.FORMAT_RGBA8)
		for row in Layout.DIRECTIONS:
			for col in Layout.POSES:
				atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(col, row) * Layout.FRAME)
		_cache[key] = ImageTexture.create_from_image(atlas)
	return _cache[key]

func item(id: String) -> Texture2D:
	var path := "res://assets/items/%s.svg" % id
	if _cache.has(path): return _cache[path]
	if not id.is_valid_identifier() or not ResourceLoader.exists(path):
		path = "res://assets/items/_fallback.svg"
	_cache[path] = load(path) as Texture2D
	return _cache[path]

func svg(path: String, scale: float = 1.0) -> Texture2D:
	return _load(path, scale, "")

func _load(path: String, scale: float, fallback: String) -> Texture2D:
	var key: String = "%s@%.2f" % [path, scale]
	if _cache.has(key): return _cache[key]
	var p: String = path if FileAccess.file_exists(path) else fallback
	if p == "" or not FileAccess.file_exists(p): return null
	var img := Image.new()
	if img.load_svg_from_string(FileAccess.get_file_as_string(p), scale) != OK: return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
