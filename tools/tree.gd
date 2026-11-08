extends SceneTree
## Prints the node tree (and animation names) of the scenes given after "--".
func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var s: Node = load(p).instantiate()
		print("== ", p)
		_dump(s, 0)
		s.free()
	quit()

func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is AnimationPlayer:
		extra = " anims=%d e.g. %s" % [n.get_animation_list().size(), str(n.get_animation_list().slice(0, 3))]
		var a: Animation = n.get_animation(n.get_animation_list()[1])
		extra += " track0=" + str(a.track_get_path(0))
	if n is MeshInstance3D:
		extra = " skel=%s mats=%d" % [n.skeleton, n.mesh.get_surface_count()]
	if n is Skeleton3D:
		extra = " bones=%d" % n.get_bone_count()
	if d < 4 or not (n is BoneAttachment3D):
		print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_dump(c, d + 1)
