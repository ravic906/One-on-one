extends SceneTree
## Finds each attack clip's impact moment: the time the striking hand/foot reaches furthest forward.
## godot --headless --script res://tools/impact.gd -- Clip:bone ...
func _initialize() -> void:
	var f := FighterModel.new()
	get_root().add_child(f)
	f.build(Roster.FIGHTERS[0])
	var sk := f.skeleton
	for spec in OS.get_cmdline_user_args():
		var p: PackedStringArray = spec.split(":")
		var clip := f.clip_name(p[0])
		var bones := [sk.find_bone(p[1])]
		var anim: Animation = f.anim.get_animation(clip)
		f.anim.play(clip)
		var best := -99.0
		var best_t := 0.0
		var t := 0.0
		var line := ""
		while t <= anim.length:
			f.anim.seek(t, true)
			sk.force_update_all_bone_transforms()
			var g: Transform3D = sk.get_bone_global_pose(bones[0])
			var reach := g.origin.z      # model faces +z
			if reach > best:
				best = reach
				best_t = t
			t += 1.0 / 60.0
		print("%-20s len=%.2fs impact=%.2fs (frame %d) reach=%.2fm height=%.2fm" % [p[0], anim.length, best_t, int(best_t * 60), best, sk.get_bone_global_pose(bones[0]).origin.y])
	quit()
