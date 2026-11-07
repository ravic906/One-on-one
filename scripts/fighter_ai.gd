class_name FighterAI
extends RefCounted
## CPU opponent. It drives a normal InputState, so it plays by exactly the same rules as the player.
## It re-decides every `react` frames (the reaction time) and can queue button sequences (combos).

var f: Fighter
var o: Fighter
var arena: Node
var c: Dictionary
var rng := RandomNumberGenerator.new()
var queue: Array = []
var timer := 0
var hold := {"rx": 0, "down": false, "up": false, "frames": 0}


func _init(fighter: Fighter, opponent: Fighter, a: Node, level: String, seed_value := -1) -> void:
	f = fighter
	o = opponent
	arena = a
	c = GameData.AI_LEVELS[level]
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func reset() -> void:
	queue.clear()
	timer = 0
	_hold(0, false, false, 0)
	f.input.clear()


func _hold(rx: int, down: bool, up: bool, frames: int) -> void:
	hold = {"rx": rx, "down": down, "up": up, "frames": frames}


func _push(btn: String, wait: int, down := false) -> void:
	queue.append({"btn": btn, "wait": wait, "down": down})


func tick() -> void:
	var inp := f.input
	if queue.size() > 0:
		var q: Dictionary = queue[0]
		if q.wait > 0:
			q.wait -= 1
		else:
			if q.down:
				_hold(0, true, false, 10)
			inp.press(q.btn)
			queue.pop_front()
	if hold.frames > 0:
		hold.frames -= 1
	else:
		_hold(0, false, false, 0)
	inp.x = int(hold.rx) * f.facing
	inp.up = hold.up
	inp.down = hold.down

	timer -= 1
	if timer > 0 or queue.size() > 0:
		return
	var react := int(c.react)
	timer = react + rng.randi_range(0, react)
	_decide()


func _decide() -> void:
	var d := absf(o.position.x - f.position.x)
	var neutral := f.is_neutral() or f.state == "dash"

	# 1. Defence: see an attack coming -> block it (reading high/low depends on skill).
	if o.state == "attack" and o.move.has("hb") and o.mf <= int(o.move.s) + int(o.move.a) and d < 200.0:
		if rng.randf() < c.block:
			var lvl: String = o.move.get("level", "mid")
			var down := false
			if lvl == "low":
				down = rng.randf() < c.read_low
			elif lvl == "mid":
				down = rng.randf() < 0.3
			_hold(-1, down, false, 22)
			queue.clear()
			return

	# 2. Incoming projectile -> jump over it or block.
	for p in arena.projs:
		if p.owner == o and signf(f.position.x - p.pos.x) == signf(p.vx) and absf(f.position.x - p.pos.x) < 240.0:
			if rng.randf() < c.block:
				if neutral and rng.randf() < 0.45:
					_hold(1, false, true, 4)
					_push("H", 14)
				else:
					_hold(-1, false, false, 30)
				return

	# 3. Anti-air a jump-in.
	if not o.grounded() and o.position.y < GameData.FLOOR - 40.0 and d < 180.0 and o.vel.y > -6.0:
		if rng.randf() < c.anti_air:
			_push("H", 0)
			return

	if not neutral:
		return

	# 4. Super when the meter is full and the opponent is close.
	if f.meter >= 100.0 and d < 240.0 and rng.randf() < 0.6:
		_push("S", 0)
		return

	var r := rng.randf()
	if d > 320.0:
		if r < 0.3 and not arena.has_proj(f):
			_push("S", 0)
		elif r < 0.75:
			_hold(1, false, false, rng.randi_range(25, 45))
		elif r < 0.88:
			f.input.dash = f.facing
		else:
			_hold(1, false, true, 4)
			_push("H", rng.randi_range(12, 20))
	elif d > 120.0:
		if r < 0.4:
			_hold(1, false, false, rng.randi_range(15, 30))
		elif r < 0.55:
			f.input.dash = f.facing
		elif r < 0.7:
			_hold(1, false, true, 4)
			_push("L" if rng.randf() < 0.5 else "H", rng.randi_range(14, 22))
		elif r < 0.82 and not arena.has_proj(f):
			_push("S", 0)
		elif r < 0.92:
			_hold(-1, false, false, 18)
		else:
			_hold(0, true, false, 15)
	else:
		if r < c.aggr:
			if o.block_count >= 2.0 and rng.randf() < 0.5:
				_push("G", 0)
				o.block_count = 0.0
			else:
				var combos := [
					[["L", 0, false], ["L", 7, false], ["H", 7, false]],
					[["L", 0, true], ["L", 7, true], ["H", 7, true]],
					[["H", 0, false], ["S", 10, false]],
					[["L", 0, false], ["H", 7, false], ["S", 10, false]],
					[["H", 0, true]],
				]
				var cb: Array = combos[rng.randi_range(0, combos.size() - 1)]
				var n: int = 1 if rng.randf() < c.drop else cb.size()
				for i in n:
					_push(cb[i][0], cb[i][1], cb[i][2])
		elif r < c.aggr + 0.15:
			_hold(-1, false, false, 14)
		else:
			_hold(-1, rng.randf() < 0.4, false, 20)
