extends SceneTree
## Prints the combined AABB of each glTF piece given after "--" (needs a renderer: xvfb-run ... --rendering-driver opengl3).
func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var s: Node3D = load("res://assets/stage/village/%s.gltf" % p).instantiate()
		var box := AABB()
		var first := true
		for m in s.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.transform * m.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("%-34s pos=%s size=%s" % [p, box.position.snapped(Vector3.ONE * 0.01), box.size.snapped(Vector3.ONE * 0.01)])
		s.free()
	quit()
