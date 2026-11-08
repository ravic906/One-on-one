class_name CameraRig
extends Camera3D
## Side-on fight camera: frames both fighters, zooms with their distance, shakes and punches in.

var shake := 0.0
var punch_in := 0.0          ## 0..1, pulls the camera towards `focus_x`
var focus_x := 0.0
var _pos := Vector3(0, 1.7, 6.0)
var _look := Vector3(0, 1.15, 0)


func _ready() -> void:
	fov = 38.0


func follow(a_x: float, b_x: float, delta: float) -> void:
	var mid := (a_x + b_x) * 0.5
	var gap := absf(a_x - b_x)
	var dist := clampf(4.4 + gap * 0.75, 5.0, 8.0)
	var tx := lerpf(mid, focus_x, punch_in)
	dist = lerpf(dist, 3.2, punch_in)
	var target := Vector3(tx, lerpf(1.75, 1.3, punch_in), dist)
	var look := Vector3(tx, lerpf(1.15, 0.9, punch_in), 0)
	var k := 1.0 - exp(-delta * 6.0)
	_pos = _pos.lerp(target, k)
	_look = _look.lerp(look, k)
	var off := Vector3.ZERO
	if shake > 0.001:
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake
		shake *= exp(-delta * 14.0)
	look_at_from_position(_pos + off, _look + off * 0.5)


func kick(amount: float) -> void:
	shake = maxf(shake, amount)
