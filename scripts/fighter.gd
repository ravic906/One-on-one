class_name Fighter
extends Node2D
## A single fighter: state machine, physics, hit reactions and procedural skeleton drawing.
## Node position is the point between the feet; y == GameData.FLOOR means grounded.

const D := preload("res://scripts/game_data.gd")
const NEUTRAL := ["idle", "walk", "crouch"]
const OUTLINE := Color(0.05, 0.04, 0.08)

static var NULL_INPUT := InputState.new()

var ch: Dictionary
var side := 0
var input: InputState
var opp: Fighter
var arena: Node            ## Arena (untyped to avoid a script cycle)

var max_hp := 1000
var hp := 1000
var disp_hp := 1000.0      ## trailing "damage" bar in the HUD
var meter := 0.0           ## 0..100, full meter turns SPECIAL into SUPER
var vel := Vector2.ZERO
var facing := 1
var state := "idle"
var state_t := 0
var move: Dictionary = {}
var move_name := ""
var mf := 0                ## current frame of the move
var move_hit := false
var stun := 0
var invuln := 0
var flash := 0
var combo := 0             ## hits received in the current combo
var combo_n := 0           ## hits dealt in my current combo (for the HUD)
var combo_show := 0
var air_used := false
var locked := true
var hold_back := false
var hold_down := false
var block_count := 0.0
var walk_ph := 0.0
var dmg_dealt := 0
var rp: Dictionary         ## rendered pose (lerped towards the target pose)
var anim_t := 0.0
var trail: Array = []      ## world positions of the striking hand/foot (motion swoosh)
var ghosts: Array = []     ## after-images during dashes and supers


func setup(c: Dictionary, s: int, inp: InputState) -> void:
	ch = c
	side = s
	input = inp
	max_hp = int(c.hp)
	reset_round()


func reset_round() -> void:
	position = Vector2(300.0 if side == 0 else 660.0, D.FLOOR)
	vel = Vector2.ZERO
	facing = 1 if side == 0 else -1
	hp = max_hp
	disp_hp = hp
	state = "idle"
	state_t = 0
	move = {}
	move_name = ""
	mf = 0
	move_hit = false
	stun = 0
	invuln = 0
	flash = 0
	combo = 0
	combo_show = 0
	air_used = false
	locked = true
	block_count = 0.0
	rp = D.POSES.idle.duplicate()
	z_index = 0
	trail.clear()
	ghosts.clear()


func sz() -> float:
	return float(ch.scale)


func is_neutral() -> bool:
	return state in NEUTRAL


func grounded() -> bool:
	return position.y >= D.FLOOR


func set_state(s: String) -> void:
	state = s
	state_t = 0


func is_active() -> bool:
	return state == "attack" and mf > int(move.s) and mf <= int(move.s) + int(move.a)


# ------------------------------------------------------------------ simulation

func tick() -> void:
	var inp: InputState = NULL_INPUT if locked else input
	if invuln > 0:
		invuln -= 1
	if flash > 0:
		flash -= 1
	if combo_show > 0:
		combo_show -= 1
	block_count = maxf(0.0, block_count - 0.01)

	if grounded() and is_neutral():
		if opp.position.x != position.x:
			facing = 1 if opp.position.x > position.x else -1
	var fwd := inp.x == facing
	hold_back = inp.x != 0 and inp.x == -facing
	hold_down = inp.down
	if not (state in ["hit", "launched", "down", "ko"]):
		combo = 0
	state_t += 1

	match state:
		"idle", "walk", "crouch":
			_neutral(inp, fwd)
		"dash":
			vel.x *= 0.9
			if state_t > 6 and _try_attack(inp):
				pass
			elif state_t > 14:
				set_state("idle")
		"jump":
			if not air_used and (inp.buf.L > 0 or inp.buf.H > 0):
				inp.consume("L")
				inp.consume("H")
				air_used = true
				start_move("air")
		"attack":
			_update_attack(inp)
		"hit", "block":
			stun -= 1
			if stun <= 0:
				set_state("crouch" if hold_down else "idle")
		"down":
			if state_t > 40:
				set_state("idle")
				invuln = 14
		"land":
			if state_t > 4:
				set_state("idle")

	_physics()
	_update_pose()
	_update_motion_fx()
	queue_redraw()


func _neutral(inp: InputState, fwd: bool) -> void:
	if _try_attack(inp):
		return
	if inp.dash != 0 and not inp.down:
		set_state("dash")
		vel.x = inp.dash * 9.0 * float(ch.speed)
		inp.dash = 0
		return
	if inp.up:
		set_state("jump")
		vel.y = -16.5
		vel.x = inp.x * 4.2 * float(ch.speed)
		position.y -= 1.0
		air_used = false
		_sfx("jump")
		return
	if inp.down:
		if state != "crouch":
			set_state("crouch")
		vel.x = 0.0
		return
	if inp.x != 0:
		if state != "walk":
			set_state("walk")
		vel.x = inp.x * (3.8 if fwd else 3.0) * float(ch.speed)
		walk_ph += vel.x * facing * 0.12
	else:
		if state != "idle":
			set_state("idle")
		vel.x = 0.0


## Maps the input buffer to a move name for the current stance.
func _buffered_move(inp: InputState, consume: bool) -> String:
	var n := ""
	var b := ""
	if inp.buf.S > 0:
		b = "S"
		if meter >= 100.0:
			n = "super"
		elif not arena.has_proj(self):
			n = "special"
	elif inp.buf.G > 0:
		b = "G"
		n = "grab"
	elif inp.buf.H > 0:
		b = "H"
		n = "low" if inp.down else "heavy"
	elif inp.buf.L > 0:
		b = "L"
		n = "cjab" if inp.down else "jab"
	if consume and b != "":
		inp.consume(b)
	return n


func _try_attack(inp: InputState) -> bool:
	var n := _buffered_move(inp, true)
	if n == "":
		return false
	start_move(n)
	return true


func start_move(n: String) -> void:
	move = D.MOVES[n]
	move_name = n
	mf = 0
	move_hit = false
	set_state("attack")
	z_index = 1
	opp.z_index = 0
	if move.get("super", false):
		meter = 0.0
		invuln = int(move.s) + 4
		arena.on_super(self)
	if grounded():
		vel.x = facing * float(move.get("lunge", 0.0))


func _update_attack(inp: InputState) -> void:
	mf += 1
	var m := move
	var s := int(m.s)
	var a := int(m.a)
	if m.get("super", false):
		if mf > s and mf <= s + a and not move_hit:
			vel.x = facing * 13.0
		elif move_hit:
			vel.x *= 0.7
	if mf == s + 1:
		if m.get("proj", false):
			arena.spawn_projectile(self)
		elif m.has("hb"):
			_sfx("whiff")
	# Hit-confirm cancels: a connected move can be cut short by the next one.
	if move_hit and m.cancel.size() > 0:
		var nxt := _buffered_move(inp, false)
		if nxt != "" and nxt in m.cancel:
			_buffered_move(inp, true)
			start_move(nxt)
			return
	if mf >= s + a + int(m.r):
		if not grounded():
			state = "jump"
			state_t = 0
			air_used = true
		else:
			set_state("crouch" if inp.down else "idle")


func _physics() -> void:
	if position.y < D.FLOOR or vel.y < 0.0:
		vel.y += D.GRAV
		position += vel
		if position.y >= D.FLOOR:
			position.y = D.FLOOR
			vel.y = 0.0
			_on_land()
	else:
		position.x += vel.x
		if state in ["hit", "block", "down", "ko", "attack", "land", "win"]:
			vel.x *= 0.82
	position.x = clampf(position.x, D.STAGE_L, D.STAGE_R)


func _on_land() -> void:
	match state:
		"jump":
			set_state("land")
			vel.x = 0.0
		"attack":
			if move.get("airborne", false):
				set_state("land")
				vel.x = 0.0
		"launched":
			set_state("down")
			vel.x = 0.0
			arena.add_shake(4.0)
			arena.dust(position)
		"ko":
			vel.x = 0.0
			arena.add_shake(5.0)
			arena.dust(position)
		"hit":
			set_state("idle")


# ------------------------------------------------------------------ combat

func hurtbox() -> Rect2:
	var s := sz()
	var h := 150.0
	if not grounded():
		h = 125.0
	elif state == "crouch" or state == "land" or (state == "block" and hold_down) \
			or (state == "attack" and move.get("crouch", false)):
		h = 100.0
	return Rect2(position.x - 28.0 * s, position.y - h * s, 56.0 * s, h * s)


func hitbox() -> Rect2:
	var s := sz()
	var hb: Array = move.hb
	var w: float = hb[2] * s
	var h: float = hb[3] * s
	var x0: float = hb[0] * s
	var left: float = position.x + x0 if facing > 0 else position.x - x0 - w
	return Rect2(left, position.y - hb[1] * s - h * 0.5, w, h)


func can_block(level: String) -> bool:
	if not (state in ["idle", "walk", "crouch", "block"]) or not hold_back or not grounded():
		return false
	if level == "low":
		return hold_down
	if level == "high":
		return not hold_down
	return true


func take_hit(a: Fighter, m: Dictionary, dir: int, at: Vector2) -> void:
	var scaling := maxf(0.35, 1.0 - 0.12 * combo)
	var dmg := int(round(float(m.dmg) * float(a.ch.power) * scaling))
	hp = maxi(0, hp - dmg)
	combo += 1
	a.combo_n = combo
	a.combo_show = 70
	a.dmg_dealt += dmg
	flash = 6
	a.meter = minf(100.0, a.meter + dmg * 0.12)
	meter = minf(100.0, meter + dmg * 0.06)
	var is_super: bool = m.get("super", false)
	if m.get("knockdown", false) or not grounded() or hp <= 0:
		launch(dir, 9.0 if is_super else 6.0, -11.0 if is_super else -9.0)
	else:
		set_state("hit")
		stun = int(m.hs)
		vel.x = dir * float(m.push)
		_wall_push(a, float(m.push))
	if hp <= 0:
		state = "ko"
	arena.on_hit(a, self, dmg, at, m)


func take_block(a: Fighter, m: Dictionary, dir: int, at: Vector2, chip: bool) -> void:
	if chip:
		var c := int(round(float(m.dmg) * 0.15 * float(a.ch.power)))
		hp = maxi(1, hp - c)
		a.dmg_dealt += c
	set_state("block")
	stun = int(m.bs)
	vel.x = dir * float(m.push) * 1.1
	block_count += 1.0
	a.meter = minf(100.0, a.meter + float(m.dmg) * 0.05)
	meter = minf(100.0, meter + float(m.dmg) * 0.04)
	_wall_push(a, float(m.push))
	arena.on_block(a, self, at)


func take_grab(a: Fighter, m: Dictionary, at: Vector2) -> void:
	var dmg := int(round(float(m.dmg) * float(a.ch.power)))
	hp = maxi(0, hp - dmg)
	a.dmg_dealt += dmg
	a.meter = minf(100.0, a.meter + dmg * 0.12)
	flash = 6
	combo = 1
	launch(a.facing, 7.0, -10.0)
	if hp <= 0:
		state = "ko"
	arena.on_hit(a, self, dmg, at, m)


func launch(dir: int, vx: float, vy: float) -> void:
	set_state("launched")
	vel = Vector2(dir * vx, vy)
	position.y = minf(position.y, D.FLOOR - 1.0)
	invuln = 9999


## When the defender is pinned in the corner the attacker is pushed back instead.
func _wall_push(a: Fighter, push: float) -> void:
	if position.x <= D.STAGE_L + 2.0 or position.x >= D.STAGE_R - 2.0:
		a.vel.x = -a.facing * push * 0.8


func _sfx(n: String) -> void:
	if arena:
		arena.play_sfx(n)


# ------------------------------------------------------------------ animation

func _target_pose() -> Dictionary:
	var P := D.POSES
	match state:
		"walk":
			return _walk_pose()
		"crouch", "land":
			return P.crouch
		"jump":
			return P.jump
		"dash":
			return P.dash
		"attack":
			if mf <= int(move.s) + int(move.a):
				return P[move.pose]
			if move.get("crouch", false):
				return P.crouch
			return P.jump if move.get("airborne", false) else P.idle
		"hit":
			return P.hit
		"block":
			return P.cblock if hold_down else P.block
		"launched":
			return P.launched
		"down":
			return P.down
		"ko":
			return P.launched if not grounded() else P.down
		"win":
			return P.win
	return P.idle


func _walk_pose() -> Dictionary:
	var p: Dictionary = D.POSES.idle.duplicate()
	var sw := sin(walk_ph)
	p.lFu = 0.32 + sw * 0.38
	p.lBu = -0.32 - sw * 0.38
	p.lFl = p.lFu - 0.25 * maxf(0.0, cos(walk_ph))
	p.lBl = p.lBu - 0.25 * maxf(0.0, -cos(walk_ph))
	return p


func _update_pose() -> void:
	anim_t += 1.0 / 60.0
	var tp := _target_pose()
	var k := 0.3
	if state == "attack":
		if mf <= int(move.s):
			k = 1.0 - pow(0.15, 1.0 / maxf(1.0, float(move.s)))
		else:
			k = 0.6
	elif state in ["launched", "down", "ko"]:
		k = 0.22
	for key in rp:
		rp[key] = lerpf(rp[key], tp[key], k)


func _update_motion_fx() -> void:
	# Swoosh trail follows the striking limb through the active frames.
	if state == "attack" and move.has("strike") and mf >= int(move.s) - 1 and mf <= int(move.s) + int(move.a) + 1:
		var sk := skeleton(rp, ch, facing)
		trail.append(position + sk[move.strike])
		if trail.size() > 7:
			trail.pop_front()
	elif trail.size() > 0:
		trail.pop_front()
	# After-images while dashing or during the super rush.
	var fast: bool = state == "dash" or (state == "attack" and move.get("super", false) and mf > int(move.s))
	if fast and state_t % 2 == 0:
		ghosts.append({"pos": position, "pose": rp.duplicate(), "fc": facing, "life": 8})
	for g in ghosts:
		g.life -= 1
	ghosts = ghosts.filter(func(g): return g.life > 0)


func _draw() -> void:
	var s := sz()
	# Ground contact shadow, shrinks with jump height.
	var h := clampf((D.FLOOR - position.y) / 200.0, 0.0, 0.7)
	draw_set_transform(Vector2(0, D.FLOOR - position.y), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 40.0 * s * (1.0 - h), Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, 28.0 * s * (1.0 - h), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for g in ghosts:
		var k: float = g.life / 8.0
		draw_body(self, g.pose, ch, g.fc, false, 0.45 * k, anim_t,
			Transform2D(0.0, g.pos - position), Color(ch.accent, 1.0))
	var alpha := 1.0
	if invuln > 0 and invuln < 100 and state != "attack" and int(anim_t * 30.0) % 2 == 0:
		alpha = 0.55
	draw_body(self, rp, ch, facing, flash > 0, alpha, anim_t, Transform2D.IDENTITY)


static func _drop(u: float, l: float, th: float, sh: float) -> float:
	return cos(u) * th + cos(l) * sh


static func _seg(o: Vector2, a: float, l: float, fc: int) -> Vector2:
	return o + Vector2(sin(a) * l * fc, cos(a) * l)


## Joint positions in local space (feet at the origin) for a pose.
static func skeleton(p: Dictionary, c: Dictionary, fc: int) -> Dictionary:
	var s := float(c.scale)
	var th := 34.0 * s
	var sh := 34.0 * s
	var ua := 26.0 * s
	var fa := 26.0 * s
	var to := 50.0 * s
	var hd := 13.0 * s
	var hip_h := maxf(maxf(_drop(p.lFu, p.lFl, th, sh), _drop(p.lBu, p.lBl, th, sh)), 18.0 * s)
	var lean: float = p.lean
	var hip := Vector2(0, -hip_h)
	var chest := hip + Vector2(sin(lean) * to * fc, -cos(lean) * to)
	var shoulder := hip.lerp(chest, 0.86)
	var head := chest + Vector2(sin(lean) * hd * 1.25 * fc, -cos(lean) * hd * 1.25)
	var kf := _seg(hip, p.lFu, th, fc)
	var ff := _seg(kf, p.lFl, sh, fc)
	var kb := _seg(hip, p.lBu, th, fc)
	var fb := _seg(kb, p.lBl, sh, fc)
	var ef := _seg(shoulder, p.aFu, ua, fc)
	var hf := _seg(ef, p.aFl, fa, fc)
	var eb := _seg(shoulder, p.aBu, ua, fc)
	var hb := _seg(eb, p.aBl, fa, fc)
	return {"hip": hip, "chest": chest, "shoulder": shoulder, "head": head,
		"kf": kf, "ff": ff, "kb": kb, "fb": fb, "ef": ef, "hf": hf, "eb": eb, "hb": hb,
		"hand": hf, "foot": ff}


const LIGHT := Vector2(0.55, -0.83)          ## sunset light direction (upper right)
const RIM := Color(1.0, 0.72, 0.45)


## Unit half-circle in a frame where +x points along the capsule (precomputed once).
static var _HALF: Array = _make_half()


static func _make_half() -> Array:
	var out := []
	for i in 7:
		var t := -PI * 0.5 + PI * i / 6.0
		out.append(Vector2(cos(t), sin(t)))
	return out


## Outline of a tapered capsule from a (radius ra) to b (radius rb).
static func _capsule(a: Vector2, b: Vector2, ra: float, rb: float) -> PackedVector2Array:
	var d := b - a
	var l := d.length()
	d = d / l if l > 0.001 else Vector2(0, 1)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	pts.resize(14)
	for i in 7:
		var u: Vector2 = _HALF[i]
		pts[i] = b + (d * u.x + n * u.y) * rb
		pts[7 + i] = a + (-d * u.x - n * u.y) * ra
	return pts


## A shaded body part: outline, shadow side, lit side, warm rim light.
static func _part(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, col: Color,
		alpha: float, tint: bool) -> void:
	if a.distance_to(b) < absf(ra - rb) + 1.0:
		_ball(ci, b, maxf(ra, rb), col, alpha, tint)
		return
	if tint:
		ci.draw_colored_polygon(_capsule(a, b, ra, rb), Color(col, alpha))
		return
	ci.draw_colored_polygon(_capsule(a, b, ra + 2.6, rb + 2.6), Color(OUTLINE, alpha))
	ci.draw_colored_polygon(_capsule(a, b, ra, rb), Color(col.darkened(0.38), alpha))
	var sh := LIGHT * 0.24
	ci.draw_colored_polygon(_capsule(a + sh * ra, b + sh * rb, ra * 0.76, rb * 0.76), Color(col, alpha))
	var n := (b - a).orthogonal().normalized()
	if n.dot(LIGHT) < 0.0:
		n = -n
	if n.dot(LIGHT) > 0.15:
		ci.draw_line(a + n * ra * 0.72, b + n * rb * 0.72, Color(RIM, 0.55 * alpha * n.dot(LIGHT)), maxf(1.5, minf(ra, rb) * 0.3), true)


static func _ball(ci: CanvasItem, p: Vector2, r: float, col: Color, alpha: float, tint: bool) -> void:
	if tint:
		ci.draw_circle(p, r, Color(col, alpha))
		return
	ci.draw_circle(p, r + 2.6, Color(OUTLINE, alpha))
	ci.draw_circle(p, r, Color(col.darkened(0.38), alpha))
	ci.draw_circle(p + LIGHT * r * 0.2, r * 0.78, Color(col, alpha))
	ci.draw_circle(p + LIGHT * r * 0.45, r * 0.25, Color(1, 1, 1, 0.35 * alpha))


## Draws a fighter. Shared by in-game fighters, after-images and menu portraits.
## tint (alpha > 0) draws a flat-coloured silhouette instead of the shaded body.
static func draw_body(ci: CanvasItem, p: Dictionary, c: Dictionary, fc: int, white: bool,
		alpha: float, t: float, base: Transform2D, tint := Color(0, 0, 0, 0)) -> void:
	var s := float(c.scale)
	var rot: float = p.rot
	var xf := base
	if absf(rot) > 0.001:
		xf = base * Transform2D(rot * fc, Vector2(0, -8.0 * s * absf(sin(rot))))
	ci.draw_set_transform_matrix(xf)
	var k := skeleton(p, c, fc)
	var flat := tint.a > 0.0

	var col: Color = c.color
	var pants: Color = c.dark.lerp(Color(0.1, 0.08, 0.16), 0.4)
	var glove: Color = c.accent
	var acc: Color = c.accent
	var boot := Color(0.16, 0.13, 0.2)
	if white:
		col = Color(1, 1, 1)
		pants = Color(0.92, 0.92, 0.95)
		glove = Color(1, 1, 1)
		acc = Color(1, 1, 1)
		boot = Color(0.9, 0.9, 0.9)
	if flat:
		col = tint
		pants = tint
		glove = tint
		acc = tint
		boot = tint
	var back_col := col.darkened(0.3)
	var back_pants := pants.darkened(0.3)
	var back_glove := glove.darkened(0.3)
	var back_boot := boot.darkened(0.2)

	# Back arm and leg (in shadow).
	_part(ci, k.shoulder, k.eb, 6.5 * s, 5.5 * s, back_col, alpha, flat)
	_part(ci, k.eb, k.hb, 5.5 * s, 5.0 * s, back_col, alpha, flat)
	_ball(ci, k.hb, 7.5 * s, back_glove, alpha, flat)
	_part(ci, k.hip, k.kb, 8.5 * s, 6.5 * s, back_pants, alpha, flat)
	_part(ci, k.kb, k.fb, 6.5 * s, 5.0 * s, back_pants, alpha, flat)
	_foot(ci, k.kb, k.fb, fc, s, back_boot, alpha, flat)

	# Torso: hips to a broader chest, with a belt.
	_part(ci, k.hip, k.chest, 10.5 * s, 14.0 * s, col, alpha, flat)
	if not flat:
		var bdir: Vector2 = (k.chest - k.hip).normalized().orthogonal()
		ci.draw_line(k.hip - bdir * 11.0 * s, k.hip + bdir * 11.0 * s, Color(acc, alpha), 5.0 * s, true)

	# Front leg.
	_part(ci, k.hip, k.kf, 8.5 * s, 6.5 * s, pants, alpha, flat)
	_part(ci, k.kf, k.ff, 6.5 * s, 5.0 * s, pants, alpha, flat)
	_foot(ci, k.kf, k.ff, fc, s, boot, alpha, flat)

	# Head with headband and trailing tails.
	var hd := 13.0 * s
	_ball(ci, k.head, hd, col, alpha, flat)
	if not flat:
		var band_y := -3.0 * s
		ci.draw_line(k.head + Vector2(-hd, band_y), k.head + Vector2(hd, band_y), Color(OUTLINE, alpha), 7.5 * s, true)
		ci.draw_line(k.head + Vector2(-hd + 1, band_y), k.head + Vector2(hd - 1, band_y), Color(acc, alpha), 5.0 * s, true)
		var root: Vector2 = k.head + Vector2(-hd * fc, band_y)
		var wave := sin(t * 9.0) * 4.0 * s
		var t1 := root + Vector2(-17.0 * s * fc, 4.0 * s + wave)
		var t2 := root + Vector2(-14.0 * s * fc, 11.0 * s - wave)
		ci.draw_polyline(PackedVector2Array([root, t1]), Color(OUTLINE, alpha), 6.0 * s, true)
		ci.draw_polyline(PackedVector2Array([root, t2]), Color(OUTLINE, alpha), 5.0 * s, true)
		ci.draw_line(root, t1, Color(acc, alpha), 4.0 * s, true)
		ci.draw_line(root, t2, Color(acc.darkened(0.15), alpha), 3.0 * s, true)
		# Eye.
		ci.draw_line(k.head + Vector2(3.0 * s * fc, -1.5 * s), k.head + Vector2(8.0 * s * fc, -1.0 * s), Color(OUTLINE, alpha), 2.6 * s, true)

	# Front arm on top.
	_part(ci, k.shoulder, k.ef, 6.5 * s, 5.5 * s, col, alpha, flat)
	_part(ci, k.ef, k.hf, 5.5 * s, 5.0 * s, col, alpha, flat)
	_ball(ci, k.hf, 8.5 * s, glove, alpha, flat)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _foot(ci: CanvasItem, knee: Vector2, ankle: Vector2, fc: int, s: float, col: Color,
		alpha: float, flat: bool) -> void:
	var d := (ankle - knee).normalized()
	var toe := ankle + d.rotated(-PI * 0.5 * fc) * 10.0 * s + d * 2.0 * s
	_part(ci, ankle, toe, 5.0 * s, 4.2 * s, col, alpha, flat)
