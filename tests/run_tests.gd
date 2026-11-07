extends SceneTree
## Headless rules tests:  godot --headless --script res://tests/run_tests.gd
## Exit code = number of failures.

var fails := 0
var passes := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  PASS  ", label)
	else:
		fails += 1
		printerr("  FAIL  ", label)


func arena_for(p1 := 0, p2 := 0) -> Arena:
	var a := Arena.new()
	a.manual = true
	root.add_child(a)
	a.setup(p1, p2, "normal")
	a.paused = true          # we step manually
	a.phase = "fight"
	for f in a.fighters:
		f.locked = false
	return a


func place(a: Arena, x0: float, x1: float) -> void:
	a.fighters[0].position = Vector2(x0, GameData.FLOOR)
	a.fighters[1].position = Vector2(x1, GameData.FLOOR)
	a.fighters[0].facing = 1
	a.fighters[1].facing = -1


func run(a: Arena, n: int) -> void:
	for i in n:
		a.tick()


func hold(inp: InputState, x: int, down := false, up := false) -> void:
	inp.x = x
	inp.down = down
	inp.up = up


func _initialize() -> void:
	print("One-on-One rules tests")

	# Standing jab connects at close range.
	var a := arena_for()
	var p1 := a.fighters[0]
	var p2 := a.fighters[1]
	place(a, 300, 360)
	a.player_input.press("L")
	run(a, 14)
	check(p2.hp < p2.max_hp, "jab hits at close range (p2 hp %d)" % p2.hp)
	a.queue_free()

	# Holding back blocks a mid attack, no damage.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 300, 360)
	hold(a.cpu_input, 1)                 # p2 faces left, so +1 is "back"
	run(a, 2)
	a.player_input.press("L")
	run(a, 14)
	check(p2.hp == p2.max_hp and p2.block_count > 0.0, "holding back blocks a jab")
	a.queue_free()

	# Low sweep beats a standing block...
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 300, 370)
	hold(a.cpu_input, 1)
	hold(a.player_input, 0, true)
	run(a, 2)
	a.player_input.press("H")
	run(a, 16)
	check(p2.hp < p2.max_hp, "sweep beats standing block")
	a.queue_free()

	# ...but a crouching block stops it.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 300, 370)
	hold(a.cpu_input, 1, true)
	hold(a.player_input, 0, true)
	run(a, 2)
	a.player_input.press("H")
	run(a, 16)
	check(p2.hp == p2.max_hp, "crouch block stops sweep")
	a.queue_free()

	# Cancel combo: jab > jab > kick > special.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 300, 355)
	var best := 0
	for btn in ["L", "L", "H", "S"]:
		a.player_input.press(btn)
		for i in 9:
			a.tick()
			best = maxi(best, p1.combo_n)
	run(a, 60)
	best = maxi(best, p1.combo_n)
	check(best >= 4, "4-hit cancel combo connects (best %d)" % best)
	check(p2.hp < p2.max_hp - 150, "combo damage applied with scaling (p2 hp %d)" % p2.hp)
	a.queue_free()

	# Throw beats a cornered, blocking opponent.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, GameData.STAGE_R - 50.0, GameData.STAGE_R)
	hold(a.cpu_input, 1)
	run(a, 2)
	a.player_input.press("G")
	run(a, 12)
	check(p2.hp < p2.max_hp and p2.state == "launched", "throw beats blocking")
	a.queue_free()

	# Projectile travels and hits at range; only one on screen at a time.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 200, 700)
	a.player_input.press("S")
	run(a, 20)
	var n1 := a.projs.size()
	a.player_input.press("S")
	run(a, 20)
	check(n1 == 1 and a.projs.size() == 1, "one projectile at a time")
	run(a, 90)
	check(p2.hp < p2.max_hp, "projectile hits at range")
	a.queue_free()

	# Super with full meter.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 300, 520)
	p1.meter = 100.0
	a.player_input.press("S")
	run(a, 70)
	check(p1.meter < 50.0 and p2.max_hp - p2.hp >= 200, "super rush spends meter and hits hard (dmg %d)" % (p2.max_hp - p2.hp))
	a.queue_free()

	# Pushboxes stop walking through the opponent.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 300, 400)
	hold(a.player_input, 1)
	run(a, 60)
	check(absf(p2.position.x - p1.position.x) >= 44.0, "pushbox keeps fighters apart")
	a.queue_free()

	# Jumping over the opponent switches sides.
	a = arena_for()
	p1 = a.fighters[0]
	p2 = a.fighters[1]
	place(a, 400, 470)
	hold(a.player_input, 1, false, true)
	run(a, 3)
	hold(a.player_input, 0)
	run(a, 60)
	check(p1.position.x > p2.position.x and p1.facing == -1, "cross-up jump switches sides")
	a.queue_free()

	# Full CPU-vs-CPU matches finish with a result, for every difficulty.
	for lv in ["easy", "normal", "hard"]:
		var m := Arena.new()
		root.add_child(m)
		var result := {}
		m.match_over.connect(func(r): result.merge(r))
		m.setup(randi() % 3, randi() % 3, lv, true, 42)
		m.paused = true
		var ticks := 0
		while m.phase != "over" and ticks < 60 * 60 * 8:
			m.tick()
			ticks += 1
		check(m.phase == "over" and result.has("outcome"),
			"CPU vs CPU match (%s) finishes: %s in %d rounds, %ds" % [lv, result.get("wins", "?"), result.get("rounds", 0), ticks / 60])
		m.queue_free()

	print("%d passed, %d failed" % [passes, fails])
	quit(fails)
