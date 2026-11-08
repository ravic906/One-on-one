extends SceneTree
## Renders a quick look-test image. Usage (needs a display, e.g. xvfb-run):
## godot --rendering-driver opengl3 --script res://tools/lookdev.gd -- <out.png> <anim> <time> <scene>...
var frames := 0
var out := "user://lookdev.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var anim: String = args[1]
	var t := float(args[2])
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.32)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var lib1: AnimationLibrary = _lib("res://assets/animations/UAL1_Standard.glb")
	var lib2: AnimationLibrary = _lib("res://assets/animations/UAL2_Standard.glb")
	var scenes := args.slice(3)
	for i in scenes.size():
		var c: Node3D = load(scenes[i]).instantiate()
		c.position = Vector3((i - (scenes.size() - 1) * 0.5) * 1.1, 0, 0)
		root.add_child(c)
		var ap := AnimationPlayer.new()
		c.add_child(ap)
		ap.add_animation_library("a", lib1)
		ap.add_animation_library("b", lib2)
		var name := ("a/" + anim) if lib1.has_animation(anim) else ("b/" + anim)
		ap.play(name)
		ap.seek(t, true)
		ap.pause()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.2 + scenes.size() * 0.4)
	cam.fov = 45
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))

func _lib(p: String) -> AnimationLibrary:
	var s: Node = load(p).instantiate()
	var ap: AnimationPlayer = s.get_node("AnimationPlayer")
	var lib: AnimationLibrary = ap.get_animation_library("")
	return lib

func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		get_root().get_texture().get_image().save_png(out)
		return true
	return false
