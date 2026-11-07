extends Node
## App shell: builds the menus in code, runs a CPU-vs-CPU demo behind them, and starts matches.

const D := preload("res://scripts/game_data.gd")

## Animated fighter portrait used on the select screen.
class Portrait extends Control:
	var ch: Dictionary
	var selected := false
	var t := 0.0
	var font: Font

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var pose: Dictionary = D.POSES.win if selected else D.POSES.idle
		var base := Transform2D(0.0, Vector2(0.78, 0.78), 0.0, Vector2(size.x * 0.5, 150))
		Fighter.draw_body(self, pose, ch, 1, false, 1.0, t, base)
		draw_string_outline(font, Vector2(0, 178), ch.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, 6, Color(0.05, 0.03, 0.08))
		draw_string(font, Vector2(0, 178), ch.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, ch.color.lightened(0.3))
		draw_string(font, Vector2(0, 196), ch.title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.8, 0.74, 1.0))
		var stats := [["POWER", float(ch.power) / 1.3], ["SPEED", float(ch.speed) / 1.3], ["HEALTH", float(ch.hp) / 1200.0]]
		for i in stats.size():
			var y := 208.0 + i * 13.0
			draw_string(font, Vector2(10, y + 8), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.7))
			draw_rect(Rect2(64, y, size.x - 76, 7), Color(0.07, 0.05, 0.12))
			draw_rect(Rect2(64, y, (size.x - 76) * clampf(stats[i][1], 0.0, 1.0), 7), Color(1.0, 0.85, 0.3))


var arena: Arena
var sfx: Sfx
var ui: CanvasLayer
var theme_main: Theme
var font: FontVariation
var screens := {}
var portraits: Array = []
var sel := 0
var level := "normal"
var cpu_pick := 1
var pause_btn: Button
var sound_btn: Button
var result_title: Label
var result_sub: Label
var result_stats: Label


func _ready() -> void:
	randomize()
	sfx = Sfx.new()
	add_child(sfx)
	arena = Arena.new()
	arena.sfx = sfx
	add_child(arena)
	arena.match_over.connect(_on_match_over)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_build_theme()
	_build_menu()
	_build_select()
	_build_howto()
	_build_pause()
	_build_result()
	_build_pause_button()
	_start_demo()
	show_screen("menu")
	_apply_dev_flags()


## Developer launch flags (after "--"): --showcase runs a CPU-vs-CPU match with the HUD,
## --slowmo=0.2 slows the whole game down (handy for capturing trailers and screenshots).
func _apply_dev_flags() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--showcase":
			arena.setup(randi() % D.ROSTER.size(), randi() % D.ROSTER.size(), "hard", true)
			arena.showcase = true
			show_screen("")
		elif arg.begins_with("--slowmo="):
			Engine.time_scale = clampf(float(arg.get_slice("=", 1)), 0.05, 1.0)


func _process(_delta: float) -> void:
	pause_btn.visible = not arena.demo and not arena.paused and arena.phase in ["intro", "fight", "ko"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not arena.demo and arena.phase in ["intro", "fight", "ko"]:
			_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_P, KEY_ESCAPE] and not arena.demo:
			if arena.paused:
				_resume()
			elif arena.phase in ["intro", "fight", "ko"]:
				_pause()


# ------------------------------------------------------------------ flow

func show_screen(n: String) -> void:
	for k in screens:
		screens[k].visible = k == n


func _start_demo() -> void:
	var a := randi() % D.ROSTER.size()
	var b := (a + 1 + randi() % (D.ROSTER.size() - 1)) % D.ROSTER.size()
	arena.setup(a, b, "normal", true)


func _start_match() -> void:
	cpu_pick = (sel + 1 + randi() % (D.ROSTER.size() - 1)) % D.ROSTER.size()
	arena.setup(sel, cpu_pick, level)
	show_screen("")


func _on_match_over(r: Dictionary) -> void:
	if arena.demo:
		_start_demo()
		return
	match r.outcome:
		"win":
			result_title.text = "YOU WIN"
			result_sub.text = "%s defeats %s" % [r.p1, r.p2]
		"lose":
			result_title.text = "YOU LOSE"
			result_sub.text = "%s defeats %s" % [r.p2, r.p1]
		_:
			result_title.text = "DRAW"
			result_sub.text = "Nobody walks away from this rooftop"
	result_stats.text = "Rounds %d - %d   ·   Best combo %d hits\nDamage dealt %d   ·   Damage taken %d   ·   CPU %s" % [
		r.wins[0], r.wins[1], r.max_combo, r.dealt, r.taken, level.to_upper()]
	show_screen("result")


func _pause() -> void:
	arena.paused = true
	show_screen("pause")


func _resume() -> void:
	arena.paused = false
	show_screen("")


func _to_menu() -> void:
	_start_demo()
	show_screen("menu")


# ------------------------------------------------------------------ UI construction

func _build_theme() -> void:
	font = FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	theme_main = Theme.new()
	theme_main.default_font = font
	theme_main.default_font_size = 22
	var normal := _box(Color(0.17, 0.13, 0.25), Color(0.36, 0.29, 0.52))
	var hover := _box(Color(0.24, 0.18, 0.36), Color(1.0, 0.85, 0.3))
	var pressed := _box(Color(1.0, 0.55, 0.16), Color(1.0, 0.85, 0.5))
	theme_main.set_stylebox("normal", "Button", normal)
	theme_main.set_stylebox("hover", "Button", hover)
	theme_main.set_stylebox("pressed", "Button", pressed)
	theme_main.set_stylebox("hover_pressed", "Button", pressed)
	theme_main.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_main.set_color("font_color", "Button", Color.WHITE)
	theme_main.set_color("font_pressed_color", "Button", Color(0.1, 0.06, 0.16))
	theme_main.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.06, 0.16))
	theme_main.set_color("font_color", "Label", Color.WHITE)
	theme_main.set_color("font_outline_color", "Label", Color(0.05, 0.03, 0.08))
	theme_main.set_constant("outline_size", "Label", 6)
	var panel := _box(Color(0.13, 0.1, 0.2, 0.92), Color(0.3, 0.24, 0.45))
	panel.set_content_margin_all(14)
	theme_main.set_stylebox("panel", "PanelContainer", panel)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _screen(n: String, dim := 0.6) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme_main
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.08, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	cc.add_child(vb)
	ui.add_child(root)
	screens[n] = root
	return vb


func _label(text: String, size: int, color := Color.WHITE, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	return l


func _button(text: String, cb: Callable, big := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250 if big else 220, 58 if big else 48)
	if big:
		b.add_theme_font_size_override("font_size", 28)
		b.add_theme_stylebox_override("normal", _box(Color(0.85, 0.2, 0.25), Color(1.0, 0.82, 0.5)))
		b.add_theme_stylebox_override("hover", _box(Color(0.95, 0.3, 0.3), Color(1, 1, 1)))
	b.pressed.connect(_on_button.bind(cb))
	return b


func _on_button(cb: Callable) -> void:
	sfx.play("ui")
	cb.call()


func _row(children: Array, sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


func _build_menu() -> void:
	var vb := _screen("menu", 0.5)
	vb.add_child(_label("ONE · ON · ONE", 78, Color(1.0, 0.82, 0.3), 14))
	vb.add_child(_label("Two fighters. One rooftop. No mercy.", 20, Color(0.8, 0.74, 1.0)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	vb.add_child(sp)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.add_child(_button("FIGHT", func(): show_screen("select"), true))
	col.add_child(_button("HOW TO PLAY", func(): show_screen("howto")))
	sound_btn = _button("SOUND: ON", _toggle_sound)
	col.add_child(sound_btn)
	vb.add_child(_row([col]))


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	sound_btn.text = "SOUND: ON" if sfx.enabled else "SOUND: OFF"


func _build_select() -> void:
	var vb := _screen("select", 0.7)
	vb.add_child(_label("CHOOSE YOUR FIGHTER", 32, Color(1.0, 0.85, 0.3)))
	var group := ButtonGroup.new()
	var cards: Array = []
	for i in D.ROSTER.size():
		var card := Button.new()
		card.toggle_mode = true
		card.button_group = group
		card.custom_minimum_size = Vector2(176, 252)
		card.button_pressed = i == sel
		var pr := Portrait.new()
		pr.ch = D.ROSTER[i]
		pr.font = font
		pr.selected = i == sel
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(pr)
		portraits.append(pr)
		card.pressed.connect(_on_card.bind(i))
		var on_box := _box(Color(0.22, 0.16, 0.34), Color(1.0, 0.85, 0.3))
		on_box.set_border_width_all(4)
		card.add_theme_stylebox_override("pressed", on_box)
		card.add_theme_stylebox_override("hover_pressed", on_box)
		cards.append(card)
	vb.add_child(_row(cards, 14))

	var dgroup := ButtonGroup.new()
	var drow: Array = [_label("CPU:", 20, Color(0.8, 0.74, 1.0))]
	for lv in ["easy", "normal", "hard"]:
		var b := Button.new()
		b.text = lv.to_upper()
		b.toggle_mode = true
		b.button_group = dgroup
		b.button_pressed = lv == level
		b.custom_minimum_size = Vector2(120, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_level.bind(lv))
		drow.append(b)
	vb.add_child(_row(drow, 8))
	vb.add_child(_row([_button("BACK", func(): show_screen("menu")), _button("START", _start_match, true)]))


func _on_card(i: int) -> void:
	sel = i
	sfx.play("ui")
	for j in portraits.size():
		portraits[j].selected = j == sel


func _on_level(lv: String) -> void:
	level = lv
	sfx.play("ui")


func _rematch() -> void:
	arena.setup(sel, cpu_pick, level)
	show_screen("")


func _change_fighter() -> void:
	_start_demo()
	show_screen("select")


func _build_howto() -> void:
	var vb := _screen("howto", 0.85)
	vb.add_child(_label("HOW TO PLAY", 32, Color(1.0, 0.85, 0.3)))
	var texts := [
		["MOVE", "Left thumb: drag anywhere on the left half. That's your stick.\n\nUp = jump, down = crouch, flick forward twice = dash.\n\nHold AWAY from your opponent to block. Crouch-block stops sweeps; stand-block stops jump attacks."],
		["ATTACK", "PUNCH is fast. KICK hits hard. Down + KICK sweeps.\n\nSPECIAL fires an energy blast. With a full meter it becomes a SUPER rush.\n\nTHROW grabs an opponent up close. Blocking can't stop it."],
		["COMBOS", "Land a hit and the next button cancels into it:\n\nPUNCH > PUNCH > KICK > SPECIAL\n\nv PUNCH > v PUNCH > v KICK\n\nWin 2 rounds to take the match."],
	]
	var panels: Array = []
	for t in texts:
		var pc := PanelContainer.new()
		var inner := VBoxContainer.new()
		inner.add_child(_label(t[0], 20, Color(1.0, 0.85, 0.3)))
		var body := _label(t[1], 15, Color(0.92, 0.89, 1.0), 0)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(250, 0)
		inner.add_child(body)
		pc.add_child(inner)
		panels.append(pc)
	vb.add_child(_row(panels, 12))
	vb.add_child(_label("Keyboard: arrows/WASD move · J punch · K kick · L special · I throw · P pause", 13, Color(0.6, 0.55, 0.75), 0))
	vb.add_child(_row([_button("GOT IT", func(): show_screen("menu"))]))


func _build_pause() -> void:
	var vb := _screen("pause", 0.7)
	vb.add_child(_label("PAUSED", 48, Color(1.0, 0.85, 0.3), 10))
	vb.add_child(_row([_button("RESUME", _resume, true)]))
	vb.add_child(_row([_button("QUIT TO MENU", _to_menu)]))


func _build_result() -> void:
	var vb := _screen("result", 0.7)
	result_title = _label("YOU WIN", 72, Color(1.0, 0.82, 0.3), 14)
	vb.add_child(result_title)
	result_sub = _label("", 22, Color(0.8, 0.74, 1.0))
	vb.add_child(result_sub)
	result_stats = _label("", 17, Color(0.92, 0.89, 1.0), 4)
	vb.add_child(result_stats)
	vb.add_child(_row([_button("REMATCH", _rematch, true), _button("CHANGE FIGHTER", _change_fighter)]))
	vb.add_child(_row([_button("MENU", _to_menu)]))


func _build_pause_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.theme = theme_main
	pause_btn.add_theme_font_size_override("font_size", 16)
	var bx := _box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.3))
	bx.content_margin_left = 12
	bx.content_margin_right = 12
	bx.content_margin_top = 2
	bx.content_margin_bottom = 2
	pause_btn.add_theme_stylebox_override("normal", bx)
	pause_btn.custom_minimum_size = Vector2(48, 32)
	pause_btn.anchor_left = 0.5
	pause_btn.anchor_right = 0.5
	pause_btn.offset_left = -26
	pause_btn.offset_right = 26
	pause_btn.offset_top = 84
	pause_btn.offset_bottom = 116
	pause_btn.pressed.connect(_pause)
	layer.add_child(pause_btn)
