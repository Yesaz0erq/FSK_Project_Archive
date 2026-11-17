extends Node
## Rasterises the SVG art at runtime (crisp at any size, with mipmaps) and caches it.
## SVGs are read as raw files, so the export preset includes assets/**/*.svg.

const MACHINE_SCALE: float = 2.0
var _cache: Dictionary = {}

func machine(id: String) -> Texture2D:
	return _load("res://assets/machines/%s.svg" % id, MACHINE_SCALE, "res://assets/machines/_fallback.svg")

func item(id: String) -> Texture2D:
	return _load("res://assets/items/%s.svg" % id, 1.0, "res://assets/items/_fallback.svg")

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
