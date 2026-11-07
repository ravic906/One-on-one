extends Control
## Health bars (with trailing damage), super meters, timer, round pips, combo counters, announcements.

var arena: Node
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0, outline := 6) -> void:
	var w := width
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0.0:
		w = 800.0
		p.x -= 400.0
	draw_string_outline(font, p, s, align, w, size, outline, Color(0.05, 0.03, 0.08))
	draw_string(font, p, s, align, w, size, col)


func _draw() -> void:
	if arena == null or (arena.demo and not arena.showcase) or arena.phase == "idle" or arena.fighters.size() < 2:
		return
	var a: Fighter = arena.fighters[0]
	var b: Fighter = arena.fighters[1]
	var cx := size.x * 0.5
	var w := minf(380.0, cx - 70.0)
	var top := 16.0
	_bar(a, cx - 48.0 - w, top, w, false)
	_bar(b, cx + 48.0, top, w, true)

	# Timer.
	var secs := ceili(maxf(0.0, arena.timer_frames) / 60.0)
	draw_rect(Rect2(cx - 38, top - 6, 76, 52), Color(0.05, 0.03, 0.08, 0.85))
	draw_rect(Rect2(cx - 38, top - 6, 76, 52), Color(1, 0.85, 0.3), false, 2.0)
	_text(Vector2(cx, top + 34), str(secs), 34, Color(1, 0.3, 0.3) if secs <= 10 else Color.WHITE)

	# Names and round pips.
	_text(Vector2(cx - 48.0 - w, top + 48), a.ch.name, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 200.0, 5)
	_text(Vector2(cx + 48.0 + w - 200.0, top + 48), b.ch.name, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 5)
	for i in GameData.ROUNDS_TO_WIN:
		var filled_a: bool = arena.wins[0] > i
		var filled_b: bool = arena.wins[1] > i
		_pip(Vector2(cx - 58.0 - i * 18.0, top + 56), filled_a)
		_pip(Vector2(cx + 58.0 + i * 18.0, top + 56), filled_b)

	# Super meters.
	_meter(a, cx - 48.0 - w, top + 62, w * 0.55, false)
	_meter(b, cx + 48.0 + w * 0.45, top + 62, w * 0.55, true)

	# Combo counters.
	if a.combo_show > 0 and a.combo_n >= 2:
		_text(Vector2(cx - 48.0 - w, 170), "%d HITS" % a.combo_n, 34, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_LEFT, 300.0)
	if b.combo_show > 0 and b.combo_n >= 2:
		_text(Vector2(cx + 48.0 + w - 300.0, 170), "%d HITS" % b.combo_n, 34, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT, 300.0)

	# Centre announcement with a pop-in.
	var an: Dictionary = arena.ann
	if an.text != "" and an.t < 100:
		var t: int = an.t
		var pop := 1.0 + maxf(0.0, (10.0 - t) / 10.0) * 0.6
		var alpha := clampf((100.0 - t) / 20.0, 0.0, 1.0)
		var col := Color(1.0, 0.85, 0.3, alpha)
		if an.text == "K.O.":
			col = Color(1.0, 0.25, 0.25, alpha)
		_text(Vector2(cx, size.y * 0.42), an.text, int(72 * pop), col, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 12)
		if an.sub != "":
			_text(Vector2(cx, size.y * 0.42 + 50), an.sub, 32, Color(1, 1, 1, alpha))


func _bar(f: Fighter, x: float, y: float, w: float, rtl: bool) -> void:
	var h := 22.0
	draw_rect(Rect2(x - 3, y - 3, w + 6, h + 6), Color(0.05, 0.03, 0.08, 0.9))
	draw_rect(Rect2(x, y, w, h), Color(0.25, 0.08, 0.12))
	var r := clampf(float(f.hp) / f.max_hp, 0.0, 1.0)
	var rd := clampf(f.disp_hp / f.max_hp, 0.0, 1.0)
	var col := Color(1.0, 0.85, 0.25)
	if r < 0.3:
		col = Color(1.0, 0.35, 0.25)
	# P1 bar drains towards the left edge, P2 towards the right edge, i.e. both away from the timer.
	if rtl:
		draw_rect(Rect2(x, y, w * rd, h), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(x, y, w * r, h), col)
	else:
		draw_rect(Rect2(x + w * (1.0 - rd), y, w * rd, h), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(x + w * (1.0 - r), y, w * r, h), col)
	draw_rect(Rect2(x, y, w, h * 0.35), Color(1, 1, 1, 0.12))


func _meter(f: Fighter, x: float, y: float, w: float, rtl: bool) -> void:
	var h := 8.0
	var r := clampf(f.meter / 100.0, 0.0, 1.0)
	draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), Color(0.05, 0.03, 0.08, 0.9))
	var full := r >= 1.0
	var col := Color(0.4, 0.75, 1.0)
	if full:
		col = Color(1, 1, 1) if int(Time.get_ticks_msec() / 120) % 2 == 0 else Color(1.0, 0.85, 0.3)
	if rtl:
		draw_rect(Rect2(x + w * (1.0 - r), y, w * r, h), col)
	else:
		draw_rect(Rect2(x, y, w * r, h), col)
	if full:
		var tx := x + w + 8.0 if not rtl else x - 98.0
		_text(Vector2(tx, y + 10), "SUPER!", 14, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT, 90.0, 4)


func _pip(c: Vector2, filled: bool) -> void:
	draw_circle(c, 7.0, Color(0.05, 0.03, 0.08))
	draw_circle(c, 5.0, Color(1.0, 0.85, 0.3) if filled else Color(0.3, 0.25, 0.35))
