extends Node3D
## Milestone 1 look test: a choreographed exchange on the village stage, showing the fighters,
## animation, hit reactions, impact effects, camera work and a K.O. (No controls yet.)
## Dev flags after "--": --movie-seconds=N quits after N seconds (for recording with --write-movie).

var fighters: Array[FighterModel] = []
var cam: CameraRig
var fx: Fx
var hud: Hud
var t := 0.0
var events: Array = []
var slowmo := 1.0
var _slowmo_until := 0.0
var _hitstop := 0.0
var _movers := []           ## [fighter, from_x, to_x, start, duration]
var _quit_at := -1.0
var _real := 0.0
var _dyn: Array = []          ## [time, callable] one-off events scheduled with _after
var _fired := {}
var _restart := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--movie-seconds="):
			_quit_at = float(a.get_slice("=", 1))
	add_child(Stage.new())
	fx = Fx.new()
	add_child(fx)
	cam = CameraRig.new()
	add_child(cam)
	cam.current = true
	for i in 2:
		var f := FighterModel.new()
		add_child(f)
		f.build(Roster.FIGHTERS[i])
		fighters.append(f)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.names = [Roster.FIGHTERS[0].name, Roster.FIGHTERS[1].name]
	_script_fight()
	_reset()


func _reset() -> void:
	t = 0.0
	_fired.clear()
	_dyn.clear()
	_movers.clear()
	slowmo = 1.0
	_hitstop = 0.0
	hud.hp = [1.0, 1.0]
	hud.trail = [1.0, 1.0]
	for i in 2:
		var f := fighters[i]
		f.position = Vector3(-1.7 if i == 0 else 1.7, 0, 0)
		f.rotation_degrees.y = 90 if i == 0 else -90
		f.play("Idle_Shield", 0.0)
	cam.punch_in = 0.0
	hud.announce("ROUND 1")


func _ev(time: float, cb: Callable) -> void:
	events.append([time, cb])


func _script_fight() -> void:
	var K := 0   # Kade (left)
	var V := 1   # Vexa (right)
	_ev(0.9, func(): hud.announce("FIGHT!", Color(1, 0.45, 0.25)))
	_ev(1.2, func(): _walk(K, 1.6, 1.15))
	_ev(2.35, func(): _attack(K, "Punch_Jab", 0.20, V, "Hit_Head", 1.45, 0.06, false, 0.22))
	_ev(2.8, func(): _attack(K, "Punch_Cross", 0.28, V, "Hit_Chest", 1.25, 0.08, false, 0.3))
	_ev(3.3, func(): _attack(K, "Melee_Hook", 0.22, V, "Hit_Knockback", 1.1, 0.14, true, 1.9))
	_ev(5.0, func(): fighters[V].play("LayToIdle", 0.15))
	_ev(6.4, func(): fighters[V].play("Idle_Shield", 0.2))
	_ev(6.5, func(): _walk(V, -0.6, 0.4))
	_ev(6.9, func():
		_attack(V, "Shield_Dash", 0.30, K, "Hit_Chest", 1.2, 0.1, false, 0.45))
	_ev(8.1, func(): _attack(V, "OverhandThrow", 0.38, K, "Hit_Head", 1.5, 0.12, false, 0.5))
	_ev(9.3, func(): fighters[K].play("Spell_Simple_Shoot", 0.08))
	_ev(9.53, func():
		var k := fighters[K]
		var v := fighters[V]
		fx.blast(k.position + Vector3(0.5, 1.3, 0), v.position.x - 0.2, Color(1.0, 0.6, 0.2), func(): _ko(K, V)))
	_ev(13.8, func(): fighters[K].play("Idle_Shield", 0.3))
	_ev(15.0, func(): _restart = true)


func _walk(i: int, dist: float, dur: float) -> void:
	fighters[i].play("Walk", 0.12)
	_move(i, dist, dur)
	_after(dur, func(): fighters[i].play("Idle_Shield", 0.15))


func _move(i: int, dx: float, dur: float) -> void:
	var f := fighters[i]
	_movers.append([f, f.position.x, f.position.x + dx, t, dur])


func _attack(a: int, clip: String, impact: float, d: int, react: String, height: float, stop: float, heavy: bool, push: float) -> void:
	var att := fighters[a]
	att.play(clip, 0.06)
	# Step into range during the wind-up so the blow actually lands.
	var gap := absf(fighters[d].position.x - att.position.x)
	if gap > 1.1:
		_move(a, signf(fighters[d].position.x - att.position.x) * (gap - 1.05), maxf(impact, 0.12))
	_after(impact, func():
		var def := fighters[d]
		var dir := signf(def.position.x - att.position.x)
		var at := Vector3(def.position.x - dir * 0.18, height, 0.1)
		def.play(react, 0.03)
		fx.spark(at, att.def.accent, heavy)
		def.flash(0.35)
		_after(0.05, func(): def.flash(0.0))
		_hitstop = stop
		cam.kick(0.09 if heavy else 0.04)
		hud.hp[d] = maxf(0.0, hud.hp[d] - (0.2 if heavy else 0.09))
		_move(d, dir * push, 0.3 if not heavy else 0.55)
		if heavy:
			_slow(0.35, 0.5)
			_after(0.55, func(): fx.dust(Vector3(def.position.x, 0.05, 0)))
		_after(0.5 if not heavy else 99.0, func():
			if def.anim.current_animation.ends_with(react):
				def.play("Idle_Shield", 0.2)))
	_after(clamp(impact + 0.45, 0.6, 1.2), func(): att.play("Idle_Shield", 0.15))


func _ko(a: int, d: int) -> void:
	var def := fighters[d]
	def.play("Death01", 0.05)
	fx.spark(Vector3(def.position.x - 0.15, 1.3, 0.1), Color(1.0, 0.6, 0.2), true)
	def.flash(0.5)
	_after(0.07, func(): def.flash(0.0))
	hud.hp[d] = 0.0
	_hitstop = 0.15
	cam.kick(0.14)
	cam.focus_x = def.position.x
	_slow(0.3, 1.2)
	var tw := create_tween()
	tw.tween_property(cam, "punch_in", 0.75, 0.35)
	tw.tween_interval(1.6)
	tw.tween_property(cam, "punch_in", 0.0, 0.8)
	hud.announce("K.O.", Color(1, 0.3, 0.25))
	_move(d, 0.8, 0.8)
	_after(1.2, func(): fx.dust(Vector3(def.position.x, 0.05, 0)))
	_after(2.2, func(): fighters[a].play("Yes", 0.25))


func _after(sec: float, cb: Callable) -> void:
	_dyn.append([t + sec, cb])


func _slow(scale: float, dur: float) -> void:
	slowmo = scale
	_slowmo_until = t + dur * scale


func _process(delta: float) -> void:
	_real += delta
	if _quit_at > 0.0 and _real >= _quit_at:
		get_tree().quit()
		return
	if _restart:
		_restart = false
		_reset()
	var dt := delta
	if _hitstop > 0.0:
		_hitstop -= delta
		dt = 0.0
	elif t > _slowmo_until:
		slowmo = 1.0
	dt *= slowmo
	for f in fighters:
		f.anim.speed_scale = 0.0 if _hitstop > 0.0 else slowmo
	t += dt
	_run_events()
	for m in _movers:
		var k := clampf((t - m[3]) / m[4], 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 2.0)
		m[0].position.x = lerpf(m[1], m[2], k)
	_movers = _movers.filter(func(m): return t - m[3] < m[4])
	cam.follow(fighters[0].position.x, fighters[1].position.x, delta)
	hud.timer = maxi(0, 60 - int(t))


func _run_events() -> void:
	for i in events.size():
		if events[i][0] <= t and not _fired.has(i):
			_fired[i] = true
			events[i][1].call()
	var due := _dyn.filter(func(e): return e[0] <= t)
	_dyn = _dyn.filter(func(e): return e[0] > t)
	for e in due:
		e[1].call()
