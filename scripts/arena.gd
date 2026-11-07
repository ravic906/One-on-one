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
var showcase := false        ## CPU vs CPU with the HUD visible (developer flag)
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

var cam := Vector2(D.W * 0.5, D.H * 0.5)   ## camera centre in world space
var zoom := 1.0
var white_flash := 0.0
var ko_focus: Fighter
var super_user: Fighter

var _acc := 0.0
var _parallax: Array = []    ## [node, factor] pairs moved with the camera
var _cloud_nodes: Array = []
var _antenna_light: Layer
var _light_on := false
var _dark_drawn := false
var _flash_drawn := false
var _dark_layer: Layer
var _fx_layer: Layer         ## normal blending: dust, motes
var _glow_layer: Layer       ## additive blending: sparks, trails, projectiles
var _flash_layer: Layer
var _skyline: Array = []
var _stars: Array = []
var _clouds: Array = []
var _motes: Array = []


func _init() -> void:
	_build_stage()
	_build_stage_nodes()
	_dark_layer = _make_layer(_draw_dark)
	for i in 2:
		var f := Fighter.new()
		f.arena = self
		fighters.append(f)
		add_child(f)
	fighters[0].opp = fighters[1]
	fighters[1].opp = fighters[0]
	_fx_layer = _make_layer(_draw_fx)
	_glow_layer = _make_layer(_draw_glow)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = add_mat
	_flash_layer = _make_layer(_draw_flash)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	hud_layer.add_child(_make_vignette())
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


func _make_vignette() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.03, 0.0, 0.06, 0.55)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.2, 0.5)
	tex.width = 256
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return tr


func _make_layer(cb: Callable, parent: Node = null) -> Layer:
	var l := Layer.new()
	l.cb = cb
	(parent if parent else self).add_child(l)
	return l


## Background layers: each is drawn once and then only moved (parallax) by the camera.
func _build_stage_nodes() -> void:
	_parallax.append([_make_layer(_draw_sky), 0.0])
	var sun := Node2D.new()
	add_child(sun)
	var glow := Sprite2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.6, 0.38, 0.55), Color(1.0, 0.55, 0.35, 0.32), Color(1.0, 0.5, 0.35, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	glow.texture = tex
	glow.position = SUN_POS
	glow.scale = Vector2.ONE * (300.0 / 64.0)
	sun.add_child(glow)
	_make_layer(_draw_sun, sun)
	_parallax.append([sun, 0.08])
	var clouds := Node2D.new()
	add_child(clouds)
	for c in _clouds:
		var cl := _make_layer(_draw_cloud.bind(c), clouds)
		_cloud_nodes.append(cl)
	_parallax.append([clouds, 0.15])
	_parallax.append([_make_layer(_draw_skyline.bind(0)), 0.28])
	_parallax.append([_make_layer(_draw_skyline.bind(1)), 0.52])
	var ant := _make_layer(_draw_antenna)
	_antenna_light = _make_layer(_draw_antenna_light, ant)
	_parallax.append([ant, 0.55])
	_make_layer(_draw_floor)
	_parallax.append([_make_layer(_draw_reflection), 0.08])


## Starts a match. p2_ai is always on; p1_ai turns the match into a CPU-vs-CPU demo.
func setup(p1: int, p2: int, level: String, p1_ai := false, seed_value := -1) -> void:
	difficulty = level
	demo = p1_ai
	showcase = false
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
	white_flash = 0.0
	ko_focus = null
	var final: bool = wins[0] == D.ROUNDS_TO_WIN - 1 and wins[1] == D.ROUNDS_TO_WIN - 1
	announce("FINAL ROUND" if final else "ROUND %d" % round_n)


func announce(text: String, sub := "") -> void:
	ann = {"text": text, "t": 0, "sub": sub}


func _process(delta: float) -> void:
	_update_camera(delta)
	touch.visible = not demo and phase in ["intro", "fight", "ko"] and touch.wanted()


## Fight camera: frames both fighters, zooms in as they close the gap and punches in on a K.O.
func _update_camera(delta: float) -> void:
	var vp := get_viewport_rect().size
	var a := fighters[0]
	var b := fighters[1]
	var gap := absf(a.position.x - b.position.x)
	var focus_x := (a.position.x + b.position.x) * 0.5
	var tz := clampf(1.0 + (380.0 - gap) / 380.0 * 0.2, 1.0, 1.2)
	var rate := 3.5
	if phase == "ko" and ko_focus and phase_t < 80:
		tz = 1.32
		focus_x = ko_focus.position.x
		rate = 7.0
	if phase == "idle":
		tz = 1.0
	var k := 1.0 - exp(-delta * rate)
	zoom = lerpf(zoom, tz, k)
	var hw := vp.x / (2.0 * zoom)
	var lo := D.STAGE_L - 140.0 + hw
	var hi := D.STAGE_R + 140.0 - hw
	var tx := D.W * 0.5 if lo > hi else clampf(focus_x, lo, hi)
	var highest := minf(a.position.y, b.position.y)
	var lift := clampf((D.FLOOR - 110.0 - highest) * 0.4, 0.0, 70.0)
	var ty := D.FLOOR - 200.0 / zoom - lift
	cam = cam.lerp(Vector2(tx, ty), k)
	var off := Vector2.ZERO
	if shake > 0.1:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	scale = Vector2(zoom, zoom)
	position = vp * 0.5 - cam * zoom + off
	for pl in _parallax:
		pl[0].position = _par(pl[1])


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
	ko_focus = loser
	white_flash = 0.42
	add_shake(14.0)
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
	sparks(at, a.ch.accent, 16 if dmg >= 80 else 9, 8.0)
	sparks(at, Color(1, 1, 1), 5, 5.0)
	ring(at, Color.WHITE)
	star(at, a.ch.accent, 46.0 if is_super else (36.0 if dmg >= 80 else 24.0))
	if is_super:
		white_flash = maxf(white_flash, 0.28)
	elif dmg >= 80:
		white_flash = maxf(white_flash, 0.12)
	play_sfx(m.get("sfx", "heavy"))
	if a.side == 0 and not demo:
		stats.max_combo = maxi(stats.max_combo, a.combo_n)
	if not demo and (a.side == 0 or d.side == 0):
		Input.vibrate_handheld(35 if dmg >= 80 else 15)
	if d.hp <= 0:
		on_ko(d, a)


func on_block(_a: Fighter, _d: Fighter, at: Vector2) -> void:
	hitstop = 4
	sparks(at, Color(0.55, 0.8, 1.0), 7, 4.5)
	star(at, Color(0.5, 0.75, 1.0), 16.0)
	play_sfx("block")


func on_super(f: Fighter) -> void:
	super_flash = 32
	super_user = f
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


func star(at: Vector2, color: Color, size: float) -> void:
	parts.append({"pos": at, "vel": Vector2.ZERO, "life": 9, "max": 9, "color": color, "size": size,
		"kind": "star", "rot": randf() * TAU})


func dust(at: Vector2) -> void:
	for i in 10:
		parts.append({"pos": at + Vector2(randf_range(-34, 34), -4), "vel": Vector2(randf_range(-1.8, 1.8), randf_range(-1.4, -0.2)),
			"life": 28, "max": 28, "color": Color(0.75, 0.68, 0.85, 0.55), "size": randf_range(6.0, 11.0), "kind": "dust"})


func _update_fx() -> void:
	shake *= 0.85
	white_flash *= 0.74
	if super_flash > 0:
		super_flash -= 1
	ann.t += 1
	for p in parts:
		p.pos += p.vel
		if p.kind == "spark":
			p.vel *= 0.86
			p.vel.y += 0.15
		elif p.kind == "dust":
			p.vel *= 0.94
		p.life -= 1
	parts = parts.filter(func(p): return p.life > 0)
	for i in _clouds.size():
		var c: Dictionary = _clouds[i]
		var cx: float = fposmod(c.x + frame * c.speed + 900.0, D.W + 1800.0) - 900.0
		_cloud_nodes[i].position = Vector2(cx, c.y)
	var on := (frame / 40) % 2 == 0
	if on != _light_on:
		_light_on = on
		_antenna_light.queue_redraw()
	for m in _motes:
		var mp: Vector2 = m.pos
		mp += m.vel + Vector2(sin(frame * 0.02 + m.ph) * 0.15, 0)
		if mp.x > D.W + 200.0:
			mp.x = -200.0
		if mp.y < 120.0:
			mp.y = D.FLOOR - 4.0
		m.pos = mp
	for f in fighters:
		if f.flash == 0 and f.disp_hp > f.hp:
			f.disp_hp = maxf(f.hp, f.disp_hp - maxf(2.0, (f.disp_hp - f.hp) * 0.06))
		elif f.disp_hp < f.hp:
			f.disp_hp = f.hp
	_fx_layer.queue_redraw()
	_glow_layer.queue_redraw()
	# Full-screen overlays only redraw while active (plus one frame to clear).
	if super_flash > 0 or _dark_drawn:
		_dark_layer.queue_redraw()
		_dark_drawn = super_flash > 0
	if white_flash > 0.01 or _flash_drawn:
		_flash_layer.queue_redraw()
		_flash_drawn = white_flash > 0.01


## Normal-blended effects: dust clouds and floating motes.
func _draw_fx(ci: CanvasItem) -> void:
	for m in _motes:
		var a := 0.25 + 0.2 * sin(frame * 0.05 + m.ph)
		var r: float = m.r
		ci.draw_rect(Rect2(m.pos.x - r, m.pos.y - r, r * 2.0, r * 2.0), Color(1.0, 0.8, 0.6, a))
	for p in parts:
		if p.kind == "dust":
			var k: float = float(p.life) / p.max
			var c: Color = p.color
			ci.draw_circle(p.pos, p.size * (1.3 - k * 0.5), Color(c, c.a * k))


## Additive (glowing) effects: projectiles, attack trails, sparks, impact stars.
func _draw_glow(ci: CanvasItem) -> void:
	for f in fighters:
		var tr: Array = f.trail
		var n := tr.size()
		var acc: Color = f.ch.accent
		for i in range(1, n):
			var k := float(i) / n
			ci.draw_line(tr[i - 1], tr[i], Color(acc, 0.35 * k), (6.0 + 18.0 * k) * f.sz(), true)
			ci.draw_line(tr[i - 1], tr[i], Color(1, 1, 1, 0.5 * k), (2.0 + 6.0 * k) * f.sz(), true)
	for p in projs:
		var c: Color = p.color
		var r: float = p.r
		var t: float = p.t
		var pulse := 1.0 + sin(t * 0.6) * 0.12
		ci.draw_circle(p.pos, r * 2.6 * pulse, Color(c, 0.08))
		ci.draw_circle(p.pos, r * 1.8 * pulse, Color(c, 0.18))
		ci.draw_circle(p.pos, r * 1.2 * pulse, Color(c, 0.45))
		ci.draw_circle(p.pos, r * 0.75, Color(1, 1, 1, 0.9))
		for j in 3:
			var a0 := t * 0.35 + j * TAU / 3.0
			ci.draw_arc(p.pos, r * 1.15, a0, a0 + 1.3, 10, Color(1, 1, 1, 0.55), 2.5, true)
	for p in parts:
		var k: float = float(p.life) / p.max
		var c: Color = p.color
		match p.kind:
			"spark":
				ci.draw_line(p.pos, p.pos - p.vel * 3.5, Color(c, k), p.size, true)
				ci.draw_line(p.pos, p.pos - p.vel * 1.5, Color(1, 1, 1, k * 0.8), p.size * 0.5, true)
			"ring":
				ci.draw_arc(p.pos, p.size + (1.0 - k) * 56.0, 0, TAU, 28, Color(c, k * 0.8), 5.0 * k + 1.0, true)
			"star":
				var rr: float = p.size * (0.6 + (1.0 - k) * 0.7)
				var pts := PackedVector2Array()
				for q in 16:
					var ang: float = p.rot + q * TAU / 16.0
					var rad: float = rr if q % 2 == 0 else rr * 0.22
					pts.append(p.pos + Vector2(cos(ang), sin(ang)) * rad)
				ci.draw_colored_polygon(pts, Color(c, k * 0.9))
				ci.draw_circle(p.pos, rr * 0.3, Color(1, 1, 1, k))


func _draw_dark(ci: CanvasItem) -> void:
	if super_flash > 0:
		var k := minf(1.0, super_flash / 10.0)
		ci.draw_rect(Rect2(-800, -600, D.W + 1600, D.H + 1200), Color(0.05, 0.0, 0.12, 0.62 * k))
		if super_user:
			var c := super_user.position + Vector2(0, -90.0 * super_user.sz())
			var acc: Color = super_user.ch.accent
			for i in 28:
				var ang := i * TAU / 28.0 + frame * 0.07
				var d := Vector2(cos(ang), sin(ang))
				ci.draw_line(c + d * 110.0, c + d * 900.0, Color(acc, 0.07 * k), 4.0)


func _draw_flash(ci: CanvasItem) -> void:
	if white_flash > 0.01:
		ci.draw_rect(Rect2(-800, -600, D.W + 1600, D.H + 1200), Color(1, 0.97, 0.9, white_flash))


# ------------------------------------------------------------------ stage

func _build_stage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for layer in 2:
		var x := -520.0
		while x < D.W + 520.0:
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
			var roof := rng.randi_range(0, 3)
			_skyline.append({"layer": layer, "x": x, "w": w, "h": h, "wins": wins_arr, "roof": roof})
			x += w + rng.randf_range(2, 14)
	for i in 70:
		_stars.append(Vector2(rng.randf_range(-520, D.W + 520), rng.randf_range(-300, 220)))
	for i in 7:
		_clouds.append({"x": rng.randf_range(-600, D.W + 600), "y": rng.randf_range(40, 230),
			"w": rng.randf_range(90, 200), "speed": rng.randf_range(0.08, 0.25)})
	for i in 14:
		_motes.append({"pos": Vector2(rng.randf_range(-200, D.W + 200), rng.randf_range(150, D.FLOOR)),
			"vel": Vector2(rng.randf_range(0.1, 0.35), rng.randf_range(-0.25, -0.05)),
			"r": rng.randf_range(1.0, 2.4), "ph": rng.randf() * TAU})


## Offset that makes a background layer move at `f` times the camera speed.
func _par(f: float) -> Vector2:
	return (cam - Vector2(D.W * 0.5, D.H * 0.5)) * (1.0 - f)


const SUN_POS := Vector2(640, 340)
const HORIZON := 420.0
const BG_L := -900.0
const BG_R := D.W + 900.0
const SKY := [Color(0.06, 0.04, 0.14), Color(0.17, 0.08, 0.28), Color(0.5, 0.16, 0.36), Color(0.96, 0.46, 0.3), Color(1.0, 0.62, 0.36)]


func _draw_sky(ci: CanvasItem) -> void:
	var ys := [-500.0, 110.0, 250.0, 370.0, 430.0]
	for i in SKY.size() - 1:
		var pts := PackedVector2Array([Vector2(BG_L, ys[i]), Vector2(BG_R, ys[i]), Vector2(BG_R, ys[i + 1]), Vector2(BG_L, ys[i + 1])])
		ci.draw_polygon(pts, PackedColorArray([SKY[i], SKY[i], SKY[i + 1], SKY[i + 1]]))
	for st in _stars:
		var a := clampf((260.0 - st.y) / 200.0, 0.0, 1.0) * (0.5 + 0.4 * fposmod(st.x * 0.37, 1.0))
		ci.draw_rect(Rect2(st.x - 1.0, st.y - 1.0, 2.2, 2.2), Color(1, 1, 1, a))


func _draw_sun(ci: CanvasItem) -> void:
	ci.draw_circle(SUN_POS, 64, Color(1.0, 0.72, 0.42))
	ci.draw_circle(SUN_POS + Vector2(0, -10), 52, Color(1.0, 0.84, 0.55))
	for i in 5:
		var by := SUN_POS.y + 8.0 + i * 11.0
		ci.draw_rect(Rect2(SUN_POS.x - 70, by, 140, 2.0 + i * 1.3), SKY[3])


func _draw_cloud(ci: CanvasItem, c: Dictionary) -> void:
	var cw: float = c.w
	for j in 4:
		var o := Vector2((j - 1.5) * cw * 0.3, absf(j - 1.5) * 6.0)
		ci.draw_set_transform(o, 0.0, Vector2(1.0, 0.38))
		ci.draw_circle(Vector2.ZERO, cw * 0.32, Color(0.55, 0.22, 0.42, 0.35))
		ci.draw_circle(Vector2(0, 10), cw * 0.26, Color(1.0, 0.55, 0.45, 0.18))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_skyline(ci: CanvasItem, layer: int) -> void:
	for b in _skyline:
		if b.layer != layer:
			continue
		var col := Color(0.36, 0.14, 0.34) if layer == 0 else Color(0.12, 0.06, 0.17)
		var bx: float = b.x
		var bw: float = b.w
		var bh: float = b.h
		ci.draw_rect(Rect2(bx, HORIZON - bh, bw, bh + 40.0), col)
		if layer == 1:
			ci.draw_rect(Rect2(bx + bw - 3.0, HORIZON - bh, 3.0, bh), Color(1.0, 0.5, 0.35, 0.18))
			match int(b.roof):
				1:
					ci.draw_rect(Rect2(bx + bw * 0.3, HORIZON - bh - 14.0, bw * 0.3, 14.0), col)
				2:
					ci.draw_line(Vector2(bx + bw * 0.5, HORIZON - bh), Vector2(bx + bw * 0.5, HORIZON - bh - 30.0), col, 3.0)
			for wv in b.wins:
				ci.draw_rect(Rect2(bx + wv.x, HORIZON - bh + wv.y, 6, 9), Color(1.0, 0.83, 0.45, 0.6))
	if layer == 0:
		ci.draw_rect(Rect2(BG_L, HORIZON - 30.0, BG_R - BG_L, 70.0), Color(1.0, 0.45, 0.4, 0.1))


func _draw_antenna(ci: CanvasItem) -> void:
	var dk := Color(0.1, 0.05, 0.14)
	ci.draw_line(Vector2(140, 440), Vector2(140, 250), dk, 4)
	ci.draw_line(Vector2(120, 300), Vector2(160, 300), dk, 3)
	ci.draw_line(Vector2(126, 330), Vector2(154, 330), dk, 3)


func _draw_antenna_light(ci: CanvasItem) -> void:
	if _light_on:
		ci.draw_circle(Vector2(140, 248), 5, Color(1, 0.2, 0.2))
		ci.draw_circle(Vector2(140, 248), 14, Color(1, 0.2, 0.2, 0.25))


## Warm sun reflection streaking across the roof; moves with the sun layer.
func _draw_reflection(ci: CanvasItem) -> void:
	var bottom := D.H + 500.0
	var sx := SUN_POS.x
	var refl := PackedVector2Array([Vector2(sx - 45, HORIZON + 18), Vector2(sx + 45, HORIZON + 18), Vector2(sx + 180, bottom), Vector2(sx - 180, bottom)])
	ci.draw_polygon(refl, PackedColorArray([Color(1, 0.6, 0.4, 0.16), Color(1, 0.6, 0.4, 0.16), Color(1, 0.6, 0.4, 0.0), Color(1, 0.6, 0.4, 0.0)]))


func _draw_floor(ci: CanvasItem) -> void:
	var bottom := D.H + 500.0
	var floor_pts := PackedVector2Array([Vector2(BG_L, HORIZON), Vector2(BG_R, HORIZON), Vector2(BG_R, bottom), Vector2(BG_L, bottom)])
	var f_top := Color(0.22, 0.17, 0.27)
	var f_bot := Color(0.06, 0.05, 0.1)
	ci.draw_polygon(floor_pts, PackedColorArray([f_top, f_top, f_bot, f_bot]))
	ci.draw_rect(Rect2(BG_L, HORIZON, BG_R - BG_L, 14), Color(0.36, 0.28, 0.4))
	ci.draw_rect(Rect2(BG_L, HORIZON, BG_R - BG_L, 3), Color(1.0, 0.62, 0.45, 0.6))
	ci.draw_rect(Rect2(BG_L, HORIZON + 14, BG_R - BG_L, 4), Color(0.06, 0.04, 0.09))
	for i in range(-16, 30):
		var x0 := i * 60.0
		ci.draw_line(Vector2(x0, HORIZON + 18), Vector2(D.W * 0.5 + (x0 - D.W * 0.5) * 2.2, bottom), Color(0.26, 0.2, 0.31, 0.7), 2)
	for j in 5:
		var ly := HORIZON + 18.0 + pow(j / 5.0, 1.6) * (bottom - HORIZON)
		ci.draw_line(Vector2(BG_L, ly), Vector2(BG_R, ly), Color(0.26, 0.2, 0.31, 0.5), 1.5)
	# Corner pillars (stage edges) with a warm rim.
	for wx in [D.STAGE_L - 38.0, D.STAGE_R + 8.0]:
		ci.draw_rect(Rect2(wx, D.FLOOR - 70, 30, 74), Color(0.2, 0.16, 0.25))
		ci.draw_rect(Rect2(wx, D.FLOOR - 70, 30, 7), Color(0.42, 0.34, 0.48))
		ci.draw_rect(Rect2(wx + 26, D.FLOOR - 63, 4, 67), Color(1.0, 0.6, 0.42, 0.25))
