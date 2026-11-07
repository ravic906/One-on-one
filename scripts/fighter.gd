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


func _draw() -> void:
	var s := sz()
	# Ground shadow, shrinks with jump height.
	var h := clampf((D.FLOOR - position.y) / 200.0, 0.0, 0.7)
	draw_set_transform(Vector2(0, D.FLOOR - position.y), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 36.0 * s * (1.0 - h), Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var alpha := 1.0
	if invuln > 0 and invuln < 100 and state != "attack" and int(anim_t * 30.0) % 2 == 0:
		alpha = 0.55
	draw_body(self, rp, ch, facing, flash > 0, alpha, anim_t, Transform2D.IDENTITY)


static func _drop(u: float, l: float, th: float, sh: float) -> float:
	return cos(u) * th + cos(l) * sh


static func _seg(o: Vector2, a: float, l: float, fc: int) -> Vector2:
	return o + Vector2(sin(a) * l * fc, cos(a) * l)


static func _limb(ci: CanvasItem, pts: Array, w: float, col: Color, alpha: float) -> void:
	var out := Color(OUTLINE, alpha)
	var c := Color(col, alpha)
	for pass_i in 2:
		var cc: Color = out if pass_i == 0 else c
		var ww: float = w + 5.0 if pass_i == 0 else w
		for i in pts.size() - 1:
			ci.draw_line(pts[i], pts[i + 1], cc, ww, true)
		for p in pts:
			ci.draw_circle(p, ww * 0.5, cc)


## Draws a fighter skeleton. Shared by in-game fighters and menu portraits.
static func draw_body(ci: CanvasItem, p: Dictionary, c: Dictionary, fc: int, white: bool,
		alpha: float, t: float, base: Transform2D) -> void:
	var s := float(c.scale)
	var th := 34.0 * s
	var sh := 34.0 * s
	var ua := 26.0 * s
	var fa := 26.0 * s
	var to := 50.0 * s
	var hd := 13.0 * s
	var hip_h := maxf(maxf(_drop(p.lFu, p.lFl, th, sh), _drop(p.lBu, p.lBl, th, sh)), 18.0 * s)
	var rot: float = p.rot
	var xf := base
	if absf(rot) > 0.001:
		xf = base * Transform2D(rot * fc, Vector2(0, -8.0 * s * absf(sin(rot))))
	ci.draw_set_transform_matrix(xf)

	var lean: float = p.lean
	var hip := Vector2(0, -hip_h)
	var chest := hip + Vector2(sin(lean) * to * fc, -cos(lean) * to)
	var shoulder := hip.lerp(chest, 0.88)
	var head := chest + Vector2(sin(lean) * hd * 1.25 * fc, -cos(lean) * hd * 1.25)
	var kf := _seg(hip, p.lFu, th, fc)
	var ff := _seg(kf, p.lFl, sh, fc)
	var kb := _seg(hip, p.lBu, th, fc)
	var fb := _seg(kb, p.lBl, sh, fc)
	var ef := _seg(shoulder, p.aFu, ua, fc)
	var hf := _seg(ef, p.aFl, fa, fc)
	var eb := _seg(shoulder, p.aBu, ua, fc)
	var hb := _seg(eb, p.aBl, fa, fc)

	var col: Color = Color.WHITE if white else c.color
	var dk: Color = Color(0.85, 0.85, 0.85) if white else c.dark
	var acc: Color = Color.WHITE if white else c.accent

	# Back limbs (darker), torso, front limbs.
	_limb(ci, [shoulder, eb, hb], 10.0 * s, dk, alpha)
	ci.draw_circle(hb, 7.5 * s, Color(dk, alpha))
	_limb(ci, [hip, kb, fb], 12.0 * s, dk, alpha)
	_limb(ci, [hip, chest], 22.0 * s, col, alpha)
	ci.draw_line(hip + Vector2(-10.0 * s, 0), hip + Vector2(10.0 * s, 0), Color(acc, alpha), 6.0 * s, true)
	_limb(ci, [hip, kf, ff], 12.0 * s, col, alpha)

	# Head with headband and trailing tails.
	ci.draw_circle(head, hd + 2.5, Color(OUTLINE, alpha))
	ci.draw_circle(head, hd, Color(col, alpha))
	var band_y := -3.0 * s
	ci.draw_line(head + Vector2(-hd, band_y), head + Vector2(hd, band_y), Color(acc, alpha), 5.0 * s, true)
	var tail_root := head + Vector2(-hd * fc, band_y)
	var wave := sin(t * 9.0) * 4.0 * s
	ci.draw_line(tail_root, tail_root + Vector2(-16.0 * s * fc, 4.0 * s + wave), Color(acc, alpha), 4.0 * s, true)
	ci.draw_line(tail_root, tail_root + Vector2(-13.0 * s * fc, 10.0 * s - wave), Color(acc, alpha), 3.0 * s, true)
	ci.draw_circle(head + Vector2(5.0 * s * fc, -1.0 * s), 2.2 * s, Color(OUTLINE, alpha))

	_limb(ci, [shoulder, ef, hf], 10.0 * s, col, alpha)
	ci.draw_circle(hf, 8.5 * s, Color(OUTLINE, alpha))
	ci.draw_circle(hf, 6.5 * s, Color(col, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
