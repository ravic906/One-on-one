class_name Hud
extends Control
## Health bars, names, round timer and centre announcements.

var names := ["", ""]
var hp := [1.0, 1.0]          ## 0..1
var trail := [1.0, 1.0]       ## delayed "damage" bar
var timer := 60
var ann := ""
var ann_t := 99.0
var ann_col := Color(1, 0.85, 0.35)
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 1.0
	font = fv


func announce(text: String, col := Color(1, 0.85, 0.35)) -> void:
	ann = text
	ann_t = 0.0
	ann_col = col


func _process(delta: float) -> void:
	for i in 2:
		if trail[i] > hp[i]:
			trail[i] = maxf(hp[i], trail[i] - delta * 0.6)
		else:
			trail[i] = hp[i]
	ann_t += delta
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var w := minf(460.0, cx - 90.0)
	var y := 22.0
	_bar(Rect2(cx - 60 - w, y, w, 26), hp[0], trail[0], false)
	_bar(Rect2(cx + 60, y, w, 26), hp[1], trail[1], true)
	_text(Vector2(cx - 60 - w, y + 56), names[0], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, w)
	_text(Vector2(cx + 60, y + 56), names[1], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, w)
	draw_rect(Rect2(cx - 44, y - 8, 88, 60), Color(0.05, 0.04, 0.07, 0.85))
	draw_rect(Rect2(cx - 44, y - 8, 88, 60), Color(1, 0.8, 0.4, 0.9), false, 2.0)
	_text(Vector2(cx - 44, y + 36), str(timer), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 88)
	if ann != "" and ann_t < 1.2:
		var pop := 1.0 + maxf(0.0, 0.12 - ann_t) * 4.0
		var a := clampf((1.2 - ann_t) / 0.25, 0.0, 1.0)
		_text(Vector2(0, size.y * 0.42), ann, int(96 * pop), Color(ann_col, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14)


func _bar(r: Rect2, v: float, tr: float, rtl: bool) -> void:
	draw_rect(r.grow(3), Color(0.04, 0.03, 0.06, 0.9))
	draw_rect(r, Color(0.3, 0.06, 0.08))
	var tw := r.size.x * tr
	var vw := r.size.x * v
	var col := Color(1.0, 0.8, 0.25) if v > 0.3 else Color(1.0, 0.35, 0.2)
	if rtl:
		draw_rect(Rect2(r.position.x, r.position.y, tw, r.size.y), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(r.position.x, r.position.y, vw, r.size.y), col)
	else:
		draw_rect(Rect2(r.end.x - tw, r.position.y, tw, r.size.y), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(r.end.x - vw, r.position.y, vw, r.size.y), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(1, 1, 1, 0.15))


func _text(p: Vector2, s: String, sz: int, c: Color, align: HorizontalAlignment, width: float, outline := 6) -> void:
	draw_string_outline(font, p, s, align, width, sz, outline, Color(0.04, 0.02, 0.06, c.a))
	draw_string(font, p, s, align, width, sz, c)
