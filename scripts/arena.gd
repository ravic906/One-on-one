class_name Arena
extends Node2D
## The fight itself: fixed 60 Hz simulation, round flow, hit detection, projectiles, effects and stage.
## World space is 960x540; the node is centred in whatever viewport size the device has.

signal match_over(result: Dictionary)

const D := preload("res://scripts/game_data.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const TOUCH_SCRIPT := preload("res://scripts/touch_controls.gd")

## Draws a callback from the arena at a given place in the node order.
class Layer extends Node2D:
	var cb: Callable
	func _draw() -> void:
		cb.call(self)

var fighters: Array[Fighter] = []
var ais: Array = [null, null]
var player_input := InputState.new()
var cpu_input := InputState.new()
var sfx: Sfx
var hud: Control
var touch: Control
var demo := false            ## CPU vs CPU attract mode behind the menu
var manual := false          ## tests drive inputs themselves
var paused := false

var phase := "idle"          ## idle | intro | fight | ko | over
var phase_t := 0
var round_n := 1
var wins := [0, 0]
var timer_frames := 0
var hitstop := 0
var time_scale := 1.0
var shake := 0.0
var super_flash := 0
var frame := 0
var projs: Array = []
var parts: Array = []
var ann := {"text": "", "t": 0, "sub": ""}
var stats := {"max_combo": 0}
var difficulty := "normal"

var _acc := 0.0
var _bg_layer: Layer
var _dark_layer: Layer
var _fx_layer: Layer
var _skyline: Array = []
var _stars: Array = []


func _init() -> void:
	_build_stage()
	_bg_layer = _make_layer(_draw_bg)
	_dark_layer = _make_layer(_draw_dark)
	for i in 2:
		var f := Fighter.new()
		f.arena = self
		fighters.append(f)
		add_child(f)
	fighters[0].opp = fighters[1]
	fighters[1].opp = fighters[0]
	_fx_layer = _make_layer(_draw_fx)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	hud = HUD_SCRIPT.new()
	hud.arena = self
	hud_layer.add_child(hud)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 2
	add_child(touch_layer)
	touch = TOUCH_SCRIPT.new()
	touch.arena = self
	touch_layer.add_child(touch)
	touch.visible = false


func _make_layer(cb: Callable) -> Layer:
	var l := Layer.new()
	l.cb = cb
	add_child(l)
	return l


## Starts a match. p2_ai is always on; p1_ai turns the match into a CPU-vs-CPU demo.
func setup(p1: int, p2: int, level: String, p1_ai := false, seed_value := -1) -> void:
	difficulty = level
	demo = p1_ai
	player_input.clear()
	cpu_input.clear()
	fighters[0].setup(D.ROSTER[p1], 0, player_input)
	fighters[1].setup(D.ROSTER[p2], 1, cpu_input)
	fighters[0].meter = 0.0
	fighters[1].meter = 0.0
	fighters[0].dmg_dealt = 0
	fighters[1].dmg_dealt = 0
	ais = [null, null]
	if not manual:
		ais[1] = FighterAI.new(fighters[1], fighters[0], self, level, seed_value)
		if p1_ai:
			ais[0] = FighterAI.new(fighters[0], fighters[1], self, "normal", seed_value + 1 if seed_value >= 0 else -1)
	wins = [0, 0]
	round_n = 1
	stats = {"max_combo": 0}
	paused = false
	start_round()


func start_round() -> void:
	for f in fighters:
		f.reset_round()
	for a in ais:
		if a:
			a.reset()
	projs.clear()
	parts.clear()
	timer_frames = D.ROUND_TIME * 60
	phase = "intro"
	phase_t = 0
	time_scale = 1.0
	hitstop = 0
	super_flash = 0
	var final: bool = wins[0] == D.ROUNDS_TO_WIN - 1 and wins[1] == D.ROUNDS_TO_WIN - 1
	announce("FINAL ROUND" if final else "ROUND %d" % round_n)


func announce(text: String, sub := "") -> void:
	ann = {"text": text, "t": 0, "sub": sub}


func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	var off := Vector2.ZERO
	if shake > 0.1:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	position = Vector2(round((vp.x - D.W) * 0.5), round((vp.y - D.H) * 0.5)) + off
	touch.visible = not demo and phase in ["intro", "fight", "ko"] and touch.wanted()


func _physics_process(_delta: float) -> void:
	if paused or phase == "idle" or phase == "over":
		return
	_acc += time_scale
	while _acc >= 1.0:
		_acc -= 1.0
		tick()


# ------------------------------------------------------------------ simulation step

func tick() -> void:
	frame += 1
	if not manual and not demo:
		_read_player_input()
	if hitstop > 0:
		hitstop -= 1
		_update_fx()
		return
	if phase == "fight":
		for a in ais:
			if a:
				a.tick()
	for f in fighters:
		f.tick()
	_separate(fighters[0], fighters[1])
	_check_hit(fighters[0], fighters[1])
	_check_hit(fighters[1], fighters[0])
	_update_projs()
	for f in fighters:
		f.input.tick()
	_update_fx()
	_update_round()


func _read_player_input() -> void:
	var x := 0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	if touch and touch.stick_id != -1:
		x = touch.tx
		up = touch.tup
		down = touch.tdown
	player_input.set_dir(x, up, down, frame)


func _unhandled_input(event: InputEvent) -> void:
	if demo or phase == "idle" or phase == "over":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var b := ""
		match event.physical_keycode:
			KEY_J, KEY_Z: b = "L"
			KEY_K, KEY_X: b = "H"
			KEY_L, KEY_C: b = "S"
			KEY_I, KEY_V: b = "G"
		if b != "":
			player_input.press(b)
			get_viewport().set_input_as_handled()


func _update_round() -> void:
	phase_t += 1
	match phase:
		"intro":
			if phase_t == 60:
				announce("FIGHT!")
				play_sfx("fight")
			if phase_t >= 90:
				phase = "fight"
				phase_t = 0
				for f in fighters:
					f.locked = false
		"fight":
			timer_frames -= 1
			if timer_frames <= 600 and timer_frames > 0 and timer_frames % 60 == 0:
				play_sfx("tick")
			if timer_frames <= 0:
				_time_up()
		"ko":
			if phase_t == 45:
				time_scale = 1.0
			if phase_t == 90:
				for f in fighters:
					if f.hp > 0 and f.grounded() and f.state in ["idle", "walk", "crouch", "block", "hit", "land"]:
						f.set_state("win")
			if phase_t >= 190:
				_next_round_or_end()


func on_ko(loser: Fighter, winner: Fighter) -> void:
	if phase != "fight":
		return
	phase = "ko"
	phase_t = 0
	time_scale = 0.3
	wins[winner.side] += 1
	var perfect := winner.hp == winner.max_hp
	announce("K.O.", "PERFECT" if perfect else "")
	play_sfx("ko")
	for f in fighters:
		f.locked = true
	loser.invuln = 9999


func _time_up() -> void:
	phase = "ko"
	phase_t = 0
	var a := float(fighters[0].hp) / fighters[0].max_hp
	var b := float(fighters[1].hp) / fighters[1].max_hp
	if a > b:
		wins[0] += 1
	elif b > a:
		wins[1] += 1
	else:
		wins[0] += 1
		wins[1] += 1
	announce("TIME", "DRAW" if a == b else "")
	for f in fighters:
		f.locked = true


func _next_round_or_end() -> void:
	if wins[0] >= D.ROUNDS_TO_WIN or wins[1] >= D.ROUNDS_TO_WIN:
		phase = "over"
		var outcome := "draw"
		if wins[0] > wins[1]:
			outcome = "win"
		elif wins[1] > wins[0]:
			outcome = "lose"
		match_over.emit({
			"outcome": outcome,
			"wins": wins.duplicate(),
			"p1": fighters[0].ch.name, "p2": fighters[1].ch.name,
			"max_combo": stats.max_combo,
			"dealt": fighters[0].dmg_dealt, "taken": fighters[1].dmg_dealt,
			"rounds": round_n,
		})
	else:
		round_n += 1
		start_round()


# ------------------------------------------------------------------ combat

func _check_hit(a: Fighter, d: Fighter) -> void:
	if a.state != "attack" or a.move_hit or not a.is_active() or not a.move.has("hb"):
		return
	if d.invuln > 0 or d.state in ["ko", "down", "launched"]:
		return
	var hb := a.hitbox()
	var hu := d.hurtbox()
	if not hb.intersects(hu):
		return
	var at := hb.intersection(hu).get_center()
	var m := a.move
	if m.get("grab", false):
		if not d.grounded() or d.state in ["hit", "block"]:
			return
		a.move_hit = true
		d.take_grab(a, m, at)
		return
	a.move_hit = true
	if d.can_block(m.level):
		d.take_block(a, m, a.facing, at, m.get("super", false))
	else:
		d.take_hit(a, m, a.facing, at)


func on_hit(a: Fighter, d: Fighter, dmg: int, at: Vector2, m: Dictionary) -> void:
	var is_super: bool = m.get("super", false)
	hitstop = 14 if is_super else (8 if dmg >= 80 else 5)
	add_shake(10.0 if is_super else (6.0 if dmg >= 80 else 3.0))
	sparks(at, a.ch.accent, 14 if dmg >= 80 else 8, 7.0)
	ring(at, Color.WHITE)
	play_sfx(m.get("sfx", "heavy"))
	if a.side == 0 and not demo:
		stats.max_combo = maxi(stats.max_combo, a.combo_n)
	if not demo and (a.side == 0 or d.side == 0):
		Input.vibrate_handheld(35 if dmg >= 80 else 15)
	if d.hp <= 0:
		on_ko(d, a)


func on_block(_a: Fighter, _d: Fighter, at: Vector2) -> void:
	hitstop = 4
	sparks(at, Color(0.55, 0.8, 1.0), 6, 4.0)
	play_sfx("block")


func on_super(f: Fighter) -> void:
	super_flash = 32
	play_sfx("super")
	ring(f.position + Vector2(0, -90), f.ch.accent)


func has_proj(f: Fighter) -> bool:
	for p in projs:
		if p.owner == f:
			return true
	return false


func spawn_projectile(f: Fighter) -> void:
	var s := f.sz()
	projs.append({
		"pos": f.position + Vector2(f.facing * 55.0 * s, -108.0 * s),
		"vx": f.facing * float(f.ch.proj_speed),
		"owner": f, "r": 15.0 * s, "life": 220, "t": 0,
		"color": f.ch.proj_color, "dmg": f.ch.proj_dmg,
	})
	play_sfx("proj")


func _update_projs() -> void:
	for p in projs:
		var pos: Vector2 = p.pos
		pos.x += p.vx
		p.pos = pos
		p.life -= 1
		p.t += 1
		if p.t % 2 == 0:
			parts.append({"pos": pos, "vel": Vector2(-p.vx * 0.1, randf_range(-0.6, 0.6)),
				"life": 14, "max": 14, "color": p.color, "size": 7.0, "kind": "dust"})
	# Projectiles cancel each other out.
	for i in projs.size():
		for j in range(i + 1, projs.size()):
			var p: Dictionary = projs[i]
			var q: Dictionary = projs[j]
			if p.owner != q.owner and p.life > 0 and q.life > 0 and p.pos.distance_to(q.pos) < p.r + q.r:
				p.life = 0
				q.life = 0
				sparks((p.pos + q.pos) * 0.5, Color.WHITE, 12, 6.0)
				play_sfx("block")
	for p in projs:
		if p.life <= 0:
			continue
		var d: Fighter = p.owner.opp
		if d.invuln > 0 or d.state in ["ko", "down", "launched"]:
			continue
		var hu := d.hurtbox()
		var r: float = p.r
		var box := Rect2(p.pos - Vector2(r, r), Vector2(r, r) * 2.0)
		if not box.intersects(hu):
			continue
		p.life = 0
		if d.state == "attack" and d.move.get("super", false):
			sparks(p.pos, p.color, 10, 5.0)  # supers plough straight through projectiles
			continue
		var m := {"dmg": p.dmg, "hs": 18, "bs": 12, "push": 6.0, "level": "mid", "sfx": "heavy"}
		var dir := 1 if p.vx > 0 else -1
		if d.can_block("mid"):
			d.take_block(p.owner, m, dir, p.pos, true)
		else:
			d.take_hit(p.owner, m, dir, p.pos)
	projs = projs.filter(func(p): return p.life > 0 and p.pos.x > -60.0 and p.pos.x < D.W + 60.0)


## Pushboxes: fighters can't overlap on the ground, but can jump over each other.
func _separate(a: Fighter, b: Fighter) -> void:
	if a.state == "ko" or b.state == "ko" or a.state == "down" or b.state == "down":
		return
	var s := (a.sz() + b.sz()) * 0.5
	var min_d := 46.0 * s
	if absf(a.position.y - b.position.y) > 110.0 * s:
		return
	var dx := b.position.x - a.position.x
	if absf(dx) >= min_d:
		return
	var dir := signf(dx) if dx != 0.0 else float(a.facing)
	var over := (min_d - absf(dx)) * 0.5
	a.position.x = clampf(a.position.x - dir * over, D.STAGE_L, D.STAGE_R)
	b.position.x = clampf(b.position.x + dir * over, D.STAGE_L, D.STAGE_R)
	if absf(b.position.x - a.position.x) < min_d - 0.5:
		if a.position.x <= D.STAGE_L or a.position.x >= D.STAGE_R:
			b.position.x = clampf(a.position.x + dir * min_d, D.STAGE_L, D.STAGE_R)
		else:
			a.position.x = clampf(b.position.x - dir * min_d, D.STAGE_L, D.STAGE_R)


# ------------------------------------------------------------------ effects

func play_sfx(n: String) -> void:
	if sfx and not manual and not demo:
		sfx.play(n)


func add_shake(v: float) -> void:
	shake = maxf(shake, v)


func sparks(at: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := randf_range(0.4, 1.0) * speed
		parts.append({"pos": at, "vel": Vector2(cos(ang), sin(ang)) * sp, "life": 18, "max": 18,
			"color": color, "size": randf_range(2.0, 4.0), "kind": "spark"})


func ring(at: Vector2, color: Color) -> void:
	parts.append({"pos": at, "vel": Vector2.ZERO, "life": 12, "max": 12, "color": color, "size": 10.0, "kind": "ring"})


func dust(at: Vector2) -> void:
	for i in 8:
		parts.append({"pos": at + Vector2(randf_range(-30, 30), -4), "vel": Vector2(randf_range(-1.5, 1.5), randf_range(-1.2, -0.2)),
			"life": 24, "max": 24, "color": Color(0.8, 0.75, 0.9, 0.6), "size": randf_range(5.0, 9.0), "kind": "dust"})


func _update_fx() -> void:
	shake *= 0.85
	if super_flash > 0:
		super_flash -= 1
	ann.t += 1
	for p in parts:
		p.pos += p.vel
		if p.kind == "spark":
			p.vel *= 0.86
		p.life -= 1
	parts = parts.filter(func(p): return p.life > 0)
	for f in fighters:
		if f.flash == 0 and f.disp_hp > f.hp:
			f.disp_hp = maxf(f.hp, f.disp_hp - maxf(2.0, (f.disp_hp - f.hp) * 0.06))
		elif f.disp_hp < f.hp:
			f.disp_hp = f.hp
	_fx_layer.queue_redraw()
	_dark_layer.queue_redraw()
	_bg_layer.queue_redraw()


func _draw_fx(ci: CanvasItem) -> void:
	for p in projs:
		var c: Color = p.color
		var r: float = p.r
		var pulse := 1.0 + sin(p.t * 0.6) * 0.12
		ci.draw_circle(p.pos, r * 1.9 * pulse, Color(c, 0.18))
		ci.draw_circle(p.pos, r * 1.25 * pulse, Color(c, 0.45))
		ci.draw_circle(p.pos, r * 0.8, Color(1, 1, 1, 0.95))
	for p in parts:
		var k: float = float(p.life) / p.max
		var c: Color = p.color
		match p.kind:
			"spark":
				ci.draw_line(p.pos, p.pos - p.vel * 3.0, Color(c, k), p.size, true)
			"ring":
				ci.draw_arc(p.pos, p.size + (1.0 - k) * 50.0, 0, TAU, 24, Color(c, k), 4.0 * k + 1.0, true)
			"dust":
				ci.draw_circle(p.pos, p.size * (0.5 + k * 0.5), Color(c, c.a * k))


func _draw_dark(ci: CanvasItem) -> void:
	if super_flash > 0:
		var k := minf(1.0, super_flash / 10.0)
		ci.draw_rect(Rect2(-600, -400, D.W + 1200, D.H + 800), Color(0.05, 0.0, 0.12, 0.6 * k))


# ------------------------------------------------------------------ stage

func _build_stage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for layer in 2:
		var x := -420.0
		while x < D.W + 420.0:
			var w := rng.randf_range(40, 95) * (1.0 if layer == 0 else 1.3)
			var h := rng.randf_range(80, 220) * (0.75 if layer == 0 else 1.0)
			var wins_arr: Array = []
			if layer == 1:
				var wy := 12.0
				while wy < h - 10.0:
					var wx := 8.0
					while wx < w - 10.0:
						if rng.randf() < 0.35:
							wins_arr.append(Vector2(wx, wy))
						wx += 14.0
					wy += 18.0
			_skyline.append({"layer": layer, "x": x, "w": w, "h": h, "wins": wins_arr})
			x += w + rng.randf_range(2, 14)
	for i in 50:
		_stars.append(Vector2(rng.randf_range(-420, D.W + 420), rng.randf_range(-200, 200)))


func _draw_bg(ci: CanvasItem) -> void:
	var top := -400.0
	var bottom := D.H + 400.0
	# Sky gradient (dusk).
	var bands := [Color(0.08, 0.05, 0.16), Color(0.2, 0.09, 0.3), Color(0.55, 0.18, 0.35), Color(0.95, 0.45, 0.3)]
	var ys := [top, 120.0, 260.0, 380.0]
	for i in bands.size() - 1:
		var pts := PackedVector2Array([Vector2(-600, ys[i]), Vector2(D.W + 600, ys[i]), Vector2(D.W + 600, ys[i + 1]), Vector2(-600, ys[i + 1])])
		ci.draw_polygon(pts, PackedColorArray([bands[i], bands[i], bands[i + 1], bands[i + 1]]))
	ci.draw_rect(Rect2(-600, 380, D.W + 1200, 40), bands[3])
	for s in _stars:
		ci.draw_circle(s, 1.2, Color(1, 1, 1, 0.5 + 0.3 * sin(frame * 0.05 + s.x)))
	# Setting sun.
	ci.draw_circle(Vector2(640, 330), 90, Color(1.0, 0.65, 0.35, 0.25))
	ci.draw_circle(Vector2(640, 330), 62, Color(1.0, 0.78, 0.45))
	# Skyline silhouettes.
	var horizon := 420.0
	for b in _skyline:
		var col := Color(0.3, 0.13, 0.32) if b.layer == 0 else Color(0.13, 0.07, 0.18)
		var bx: float = b.x
		var bw: float = b.w
		var bh: float = b.h
		ci.draw_rect(Rect2(bx, horizon - bh, bw, bh), col)
		for wv in b.wins:
			ci.draw_rect(Rect2(bx + wv.x, horizon - bh + wv.y, 6, 9), Color(1.0, 0.85, 0.45, 0.55))
	# Antenna with a blinking light.
	ci.draw_line(Vector2(140, 420), Vector2(140, 250), Color(0.1, 0.05, 0.14), 4)
	ci.draw_line(Vector2(120, 300), Vector2(160, 300), Color(0.1, 0.05, 0.14), 3)
	if (frame / 40) % 2 == 0:
		ci.draw_circle(Vector2(140, 248), 5, Color(1, 0.2, 0.2))
		ci.draw_circle(Vector2(140, 248), 12, Color(1, 0.2, 0.2, 0.25))
	# Rooftop floor.
	ci.draw_rect(Rect2(-600, horizon, D.W + 1200, bottom - horizon), Color(0.16, 0.13, 0.2))
	ci.draw_rect(Rect2(-600, horizon, D.W + 1200, 14), Color(0.32, 0.27, 0.38))
	ci.draw_rect(Rect2(-600, horizon + 14, D.W + 1200, 4), Color(0.08, 0.06, 0.1))
	for i in range(-12, 25):
		var x0 := i * 60.0
		ci.draw_line(Vector2(x0, horizon + 18), Vector2(D.W * 0.5 + (x0 - D.W * 0.5) * 1.8, bottom), Color(0.22, 0.18, 0.27), 2)
	ci.draw_line(Vector2(-600, D.FLOOR), Vector2(D.W + 600, D.FLOOR), Color(0.24, 0.2, 0.3), 2)
	# Corner walls (stage edges).
	for wx in [D.STAGE_L - 34.0, D.STAGE_R + 6.0]:
		ci.draw_rect(Rect2(wx, D.FLOOR - 60, 28, 60), Color(0.24, 0.2, 0.3))
		ci.draw_rect(Rect2(wx, D.FLOOR - 60, 28, 6), Color(0.4, 0.34, 0.46))
