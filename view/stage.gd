class_name Stage
extends Node3D
## Medieval village street, assembled from the CC0 Quaternius Medieval Village MegaKit.
## Fighters stand on z = 0 and move along x; the camera looks down -z.

const KIT := "res://assets/stage/village/%s.gltf"
const BACK_Z := -3.6

var _cache := {}


func _ready() -> void:
	_build_env()
	_build_floor()
	_build_facades()
	_build_props()


func _piece(n: String, pos: Vector3, rot_y := 0.0, s := 1.0) -> Node3D:
	if not _cache.has(n):
		_cache[n] = load(KIT % n)
	var p: Node3D = _cache[n].instantiate()
	p.position = pos
	p.rotation_degrees.y = rot_y
	p.scale = Vector3.ONE * s
	add_child(p)
	return p


func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.42, 0.68)
	sm.sky_horizon_color = Color(0.98, 0.7, 0.48)
	sm.ground_horizon_color = Color(0.6, 0.45, 0.38)
	sm.ground_bottom_color = Color(0.2, 0.16, 0.14)
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	e.tonemap_white = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.95, 0.72, 0.55)
	e.fog_density = 0.006
	e.fog_sky_affect = 0.0
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 52, 0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.15
	# One shadow-casting light, kept short-range so it stays cheap on phones.
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 14.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 200, 0)
	fill.light_color = Color(0.55, 0.65, 1.0)
	fill.light_energy = 0.35
	add_child(fill)


func _build_floor() -> void:
	for x in range(-17, 18, 2):
		for z in range(-3, 8, 2):
			_piece("Floor_UnevenBrick", Vector3(x, 0, z))
	# The kit's paving is very light; darken it so the fighters read clearly against it.
	var tinted := {}
	for p in get_children():
		for m in p.find_children("*", "MeshInstance3D", true, false):
			for i in m.mesh.get_surface_count():
				var src: Material = m.mesh.surface_get_material(i)
				if src is StandardMaterial3D:
					if not tinted.has(src):
						var d: StandardMaterial3D = src.duplicate()
						d.albedo_color = Color(0.62, 0.58, 0.56)
						tinted[src] = d
					m.set_surface_override_material(i, tinted[src])


func _build_facades() -> void:
	var ground := ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Wide_Round", "Wall_UnevenBrick_Door_Round",
		"Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Wide_Round", "Wall_UnevenBrick_Straight"]
	var upper := ["Wall_Plaster_Straight", "Wall_Plaster_Window_Wide_Round", "Wall_Plaster_WoodGrid",
		"Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Straight", "Wall_Plaster_Window_Thin_Round"]
	var i := 0
	for x in range(-17, 18, 2):
		var g: String = ground[i % ground.size()]
		_piece(g, Vector3(x, 0, BACK_Z))
		if g.contains("Door"):
			_piece("Door_1_Round", Vector3(x, 0, BACK_Z))
		if g.contains("Window"):
			_piece("Window_Wide_Round1", Vector3(x, 0, BACK_Z))
		var u: String = upper[i % upper.size()]
		_piece(u, Vector3(x, 3.12, BACK_Z))
		if u.contains("Window_Wide"):
			_piece("Window_Wide_Round1", Vector3(x, 3.12, BACK_Z))
			_piece("WindowShutters_Wide_Round_Open", Vector3(x, 3.12, BACK_Z))
		elif u.contains("Window_Thin"):
			_piece("Window_Thin_Round1", Vector3(x, 3.12, BACK_Z))
		_piece("Wall_BottomCover", Vector3(x, 0, BACK_Z))
		i += 1
	# Dark interiors behind the windows and doors.
	var inside := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(38, 6.4, 0.2)
	inside.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.04, 0.05)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = m
	inside.position = Vector3(0, 3.1, BACK_Z - 0.9)
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inside)


func _build_props() -> void:
	_piece("Prop_Crate", Vector3(-7.2, 0, -2.4), 12)
	_piece("Prop_Crate", Vector3(-6.1, 0, -2.6), -8)
	_piece("Prop_Crate", Vector3(-6.7, 1.06, -2.5), 30, 0.85)
	_piece("Prop_Wagon", Vector3(7.5, 0, -2.2), 90)
	_piece("Prop_WoodenFence_Single", Vector3(-11, 0, -2.0))
	_piece("Prop_WoodenFence_Single", Vector3(11, 0, -2.0))
	_piece("Prop_Vine1", Vector3(-3, 5.4, BACK_Z + 0.12))
	_piece("Prop_Vine4", Vector3(4.6, 5.6, BACK_Z + 0.12))
