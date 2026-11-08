class_name Fx
extends Node3D
## Impact effects: sparks, flash, dust, energy blast. CPU particles so they also run on the web build.

static var _glow_tex: GradientTexture2D
static var _spark_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D


static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


static func _additive(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.no_depth_test = true
	return m


func spark(at: Vector3, color: Color, big := false) -> void:
	if _spark_mat == null:
		_spark_mat = _additive(glow_texture())
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _spark_mat
	p.mesh = q
	p.amount = 56 if big else 30
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 10.0 if big else 7.0
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1), color, Color(color, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = grad
	p.position = at
	add_child(p)
	p.emitting = true
	_flash(at, color, 2.2 if big else 1.4)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


func _flash(at: Vector3, color: Color, size: float) -> void:
	var s := Sprite3D.new()
	s.texture = glow_texture()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.modulate = Color(color.lightened(0.5), 1.0)
	s.pixel_size = 0.01 * size
	s.position = at
	s.material_override = _additive(glow_texture())
	s.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	s.material_override.albedo_color = Color(color.lightened(0.4), 1.0)
	s.material_override.vertex_color_use_as_albedo = false
	add_child(s)
	var t := create_tween()
	t.tween_property(s, "scale", Vector3.ONE * 2.6, 0.18).from(Vector3.ONE * 0.5)
	t.parallel().tween_property(s.material_override, "albedo_color:a", 0.0, 0.18)
	t.tween_callback(s.queue_free)


func dust(at: Vector3) -> void:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.albedo_texture = glow_texture()
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	q.material = _dust_mat
	p.mesh = q
	p.amount = 16
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3(0, 0.4, 0)
	p.spread = 80.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.75, 0.68, 0.6, 0.55), Color(0.7, 0.64, 0.58, 0.0)])
	p.color_ramp = grad
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## A glowing energy ball that flies along x and calls on_hit when it reaches target_x.
func blast(from: Vector3, target_x: float, color: Color, on_hit: Callable) -> void:
	var b := Node3D.new()
	b.position = from
	add_child(b)
	var core := Sprite3D.new()
	core.texture = glow_texture()
	core.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	core.material_override = _additive(glow_texture())
	core.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core.material_override.vertex_color_use_as_albedo = false
	core.material_override.albedo_color = color.lightened(0.3)
	core.pixel_size = 0.012
	b.add_child(core)
	var trail := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	q.material = _spark_mat if _spark_mat else _additive(glow_texture())
	_spark_mat = q.material
	trail.mesh = q
	trail.amount = 30
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.8
	trail.spread = 180.0
	trail.gravity = Vector3.ZERO
	var grad := Gradient.new()
	grad.colors = PackedColorArray([color.lightened(0.5), Color(color, 0)])
	trail.color_ramp = grad
	b.add_child(trail)
	var dist := absf(target_x - from.x)
	var t := create_tween()
	t.tween_property(b, "position:x", target_x, dist / 9.0)
	t.tween_callback(func():
		on_hit.call()
		b.queue_free())
