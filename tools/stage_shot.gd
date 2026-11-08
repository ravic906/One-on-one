extends SceneTree
## Renders the stage with two posed fighters: xvfb-run godot --rendering-driver opengl3 --script res://tools/stage_shot.gd -- out.png
var frames := 0
var out := ""

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	var root := Node3D.new()
	get_root().add_child(root)
	root.add_child(Stage.new())
	var poses := [["Idle_Shield", 0.5], ["Punch_Cross", 0.32]]
	for i in 2:
		var f := FighterModel.new()
		root.add_child(f)
		f.build(Roster.FIGHTERS[i])
		f.position = Vector3(-0.9 + i * 1.6, 0, 0)
		f.rotation_degrees.y = 90 if i == 0 else -90
		f.play(poses[i][0])
		f.anim.seek(poses[i][1], true)
		f.anim.pause()
	var cam := Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.7, 6.2), Vector3(0, 1.15, 0))

func _process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		get_root().get_texture().get_image().save_png(out)
		return true
	return false
