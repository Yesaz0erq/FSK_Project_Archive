extends Control
## Pixel insignia: a seed floating over two open archive folios.

var _phase := 0.0
var _last_level := -1
var _glyph := [
	"       o       ",
	"      oSo      ",
	"     oSSSo     ",
	"    ooSSSSo    ",
	"    jooSSjo    ",
	"     joojJ     ",
	"      jjJ      ",
	" aa    j    aa ",
	" aAa       aAa ",
	" aAAaa   aaAAa ",
	"  aaAAa aAAaa  ",
	"    aaAaAaa    ",
	" aa   aaa   aa ",
	"   aa     aa   ",
	"     aa aa     ",
	"       a       ",
]
const INK := {"o": Color("a6f0cd"), "S": Color("7dd7b6"), "j": Color("438d91"), "J": Color("325675"), "a": Color("aa997f"), "A": Color("efc997")}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 2.0)
	var level := roundi(sin(_phase) * 4.0)
	if level != _last_level:
		_last_level = level
		queue_redraw()

func _draw() -> void:
	var unit := maxf(1.0, floorf(minf(size.x / 17.0, size.y / 18.0)))
	var origin := ((size - Vector2(15, 16) * unit) * 0.5).floor()
	for y in _glyph.size():
		for x in _glyph[y].length():
			var symbol: String = _glyph[y][x]
			if symbol == " ": continue
			var color: Color = INK[symbol]
			if y < 7: color = color.lightened(0.08 + _last_level * 0.02)
			draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2.ONE * unit), color)
