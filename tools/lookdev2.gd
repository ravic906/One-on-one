extends SceneTree
## Renders the assembled roster: xvfb-run godot --rendering-driver opengl3 --script res://tools/lookdev2.gd -- out.png Anim t
var frames := 0
var out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.22, 0.24, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.66)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	# Remaining args: Anim:time pairs, one fighter each (cycling through the roster).
	var shots := args.slice(1)
	var n: int = shots.size()
	for i in n:
		var f := FighterModel.new()
		root.add_child(f)
		f.build(Roster.FIGHTERS[i % Roster.FIGHTERS.size()])
		f.position = Vector3((i - (n - 1) * 0.5) * 1.25, 0, 0)
		f.rotation_degrees.y = 90
		var parts: PackedStringArray = shots[i].split(":")
		f.play(parts[0])
		f.anim.seek(float(parts[1]), true)
		f.anim.pause()
		var lbl := Label3D.new()
		lbl.text = parts[0]
		lbl.position = Vector3((i - (n - 1) * 0.5) * 1.25, 2.1, 0)
		lbl.pixel_size = 0.004
		root.add_child(lbl)
	var cam := Camera3D.new()
	var cam_pos := Vector3(0, 1.3, 1.2 + n * 0.95)
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(cam_pos, Vector3(0, 1.0, 0))

func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		get_root().get_texture().get_image().save_png(out)
		return true
	return false
