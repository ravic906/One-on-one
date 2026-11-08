class_name FighterModel
extends Node3D
## Builds a 3D fighter (outfit + head + eyes + hair on one skeleton) and plays the
## Universal Animation Library clips on it with short cross-fades.

const ANIM_LIBS := ["res://assets/animations/UAL1_Standard.glb", "res://assets/animations/UAL2_Standard.glb"]

static var _libs: Array = []          ## [AnimationLibrary, AnimationLibrary] shared by all fighters
static var _base_cache := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var def: Dictionary
var _materials: Array[StandardMaterial3D] = []


static func libs() -> Array:
	if _libs.is_empty():
		for p in ANIM_LIBS:
			var s: Node = load(p).instantiate()
			_libs.append((s.get_node("AnimationPlayer") as AnimationPlayer).get_animation_library(""))
			s.free()
	return _libs


func build(d: Dictionary) -> void:
	def = d
	var outfit: Node3D = load("res://assets/outfits/%s.gltf" % d.outfit).instantiate()
	add_child(outfit)
	skeleton = outfit.get_node("Armature/Skeleton3D")
	var tex: Texture2D = load("res://assets/outfits/" + d.outfit_tex)
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			if c.name in d.hide:
				c.queue_free()
				continue
			_own_materials(c, tex)
	# Head (pre-cut by tools/build_heads.gd), eyes and eyebrows from the base character.
	var base: Node3D = load("res://assets/characters/Superhero_%s_FullBody.gltf" % d.sex).instantiate()
	var base_skel: Skeleton3D = base.get_node("Armature/Skeleton3D")
	var body: MeshInstance3D
	for c in base_skel.get_children():
		if c is MeshInstance3D and (body == null or c.mesh.get_faces().size() > body.mesh.get_faces().size()):
			body = c
	for c in base_skel.get_children():
		if c is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = load("res://assets/characters/Head_%s.res" % d.sex) if c == body else c.mesh
			m.skin = c.skin
			skeleton.add_child(m)
			m.skeleton = NodePath("..")
			_own_materials(m, null)
	base.free()
	for h in d.hair:
		_graft("res://assets/hair/%s.gltf" % h, d.get("hair_color", Color.WHITE))
	anim = AnimationPlayer.new()
	outfit.add_child(anim)
	var l: Array = libs()
	anim.add_animation_library("a", l[0])
	anim.add_animation_library("b", l[1])


func _graft(path: String, tint := Color.WHITE) -> void:
	var s: Node3D = load(path).instantiate()
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var m := MeshInstance3D.new()
		m.mesh = c.mesh
		m.skin = c.skin
		skeleton.add_child(m)
		m.skeleton = NodePath("..")
		_own_materials(m, null, tint)
	s.free()


## Per-fighter material copies so hit flashes don't leak between fighters.
func _own_materials(m: MeshInstance3D, albedo: Texture2D, tint := Color.WHITE) -> void:
	for i in m.mesh.get_surface_count():
		var src := m.get_active_material(i)
		if src is StandardMaterial3D:
			var mat: StandardMaterial3D = src.duplicate()
			if albedo and (src.albedo_texture and String(src.albedo_texture.resource_path).contains("_BaseColor") \
					and not String(src.albedo_texture.resource_path).contains("Regular")):
				mat.albedo_texture = albedo
			mat.albedo_color = src.albedo_color * tint
			m.set_surface_override_material(i, mat)
			_materials.append(mat)


func clip_name(n: String) -> String:
	return ("a/" + n) if anim.has_animation("a/" + n) else "b/" + n


func play(n: String, blend := 0.08, speed := 1.0, from_start := true) -> void:
	var c := clip_name(n)
	if from_start or anim.current_animation != c:
		anim.play(c, blend, speed)
		if from_start:
			anim.seek(0.0, true)


## Brief emissive flash when hit.
func flash(amount: float) -> void:
	for m in _materials:
		m.emission_enabled = amount > 0.0
		m.emission = Color(1.0, 0.55, 0.3)
		m.emission_energy_multiplier = amount
