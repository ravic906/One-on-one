extends SceneTree
## Cuts the head + neck out of the base character body meshes (by bone weights) and saves them as
## assets/characters/Head_<Male|Female>.res, so they can sit on top of an outfit.
## Needs a real renderer: xvfb-run godot --rendering-driver opengl3 --script res://tools/build_heads.gd
const KEEP := ["Head", "neck_01"]

func _initialize() -> void:
	for sex in ["Male", "Female"]:
		var scene: Node = load("res://assets/characters/Superhero_%s_FullBody.gltf" % sex).instantiate()
		var skel: Skeleton3D = scene.get_node("Armature/Skeleton3D")
		var body: MeshInstance3D
		for c in skel.get_children():   # the body is the biggest mesh
			if c is MeshInstance3D and (body == null or c.mesh.get_faces().size() > body.mesh.get_faces().size()):
				body = c
		var mesh: ArrayMesh = body.mesh
		var skin: Skin = body.skin
		var keep_binds := {}
		for i in skin.get_bind_count():
			var bname := skin.get_bind_name(i)
			if bname == "":
				bname = skel.get_bone_name(skin.get_bind_bone(i))
			if bname in KEEP:
				keep_binds[i] = true
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := bones.size() / verts.size()
		var head_w := PackedFloat32Array()
		head_w.resize(verts.size())
		for v in verts.size():
			var w := 0.0
			for k in stride:
				if keep_binds.has(bones[v * stride + k]):
					w += weights[v * stride + k]
			head_w[v] = w
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var out_idx := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			if head_w[a] + head_w[b] + head_w[c] >= 1.2:
				out_idx.append_array([a, b, c])
		arrays[Mesh.ARRAY_INDEX] = out_idx
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh.surface_get_format(0) & ~Mesh.ARRAY_FORMAT_INDEX | Mesh.ARRAY_FORMAT_INDEX)
		out.surface_set_material(0, mesh.surface_get_material(0) if mesh.surface_get_material(0) else body.get_active_material(0))
		var err := ResourceSaver.save(out, "res://assets/characters/Head_%s.res" % sex)
		print(sex, ": kept ", out_idx.size() / 3, " of ", idx.size() / 3, " triangles, binds ", keep_binds.keys(), " save=", err)
		scene.free()
	quit()
