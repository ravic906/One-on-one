extends Control
## Multi-touch controls: a floating stick on the left half, four attack buttons bottom-right.
## Uses raw InputEventScreenTouch/Drag so several fingers work at once.

const STICK_R := 60.0

var arena: Node
var force_show := false
var stick_id := -1
var stick_center := Vector2.ZERO
var stick_vec := Vector2.ZERO
var tx := 0
var tup := false
var tdown := false
var finger_btn := {}     ## finger index -> button id
var font: Font

## Offsets are from the bottom-right corner (safe-area aware).
var buttons := [
	{"b": "L", "label": "PUNCH", "off": Vector2(-158, -62), "r": 44.0, "color": Color(0.25, 0.66, 0.96)},
	{"b": "H", "label": "KICK", "off": Vector2(-58, -76), "r": 44.0, "color": Color(0.91, 0.28, 0.28)},
	{"b": "S", "label": "SPECIAL", "off": Vector2(-66, -178), "r": 38.0, "color": Color(1.0, 0.78, 0.16)},
	{"b": "G", "label": "THROW", "off": Vector2(-158, -162), "r": 34.0, "color": Color(0.59, 0.43, 0.9)},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("(('ontouchstart' in window) || navigator.maxTouchPoints > 0) ? 1 : 0", true)
		force_show = r != null and int(r) == 1
		print("touch controls: js=", r, " show=", force_show)


## Show on touch devices (phones/tablets, or a browser on one).
func wanted() -> bool:
	if OS.has_feature("web"):
		return force_show
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _safe_corner() -> Vector2:
	# Keep clear of notches / home indicator.
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var inset := Vector2(16, 12)
	if win.x > 0 and safe.size.x > 0:
		var k := size.x / float(win.x)
		inset.x = maxf(inset.x, (win.x - safe.end.x) * k)
		inset.y = maxf(inset.y, (win.y - safe.end.y) * k)
	return size - inset


func _btn_pos(bt: Dictionary) -> Vector2:
	return _safe_corner() + bt.off


func _default_stick() -> Vector2:
	return Vector2(size.x - _safe_corner().x + 110.0, size.y - 110.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_release_all()


func _release_all() -> void:
	stick_id = -1
	stick_vec = Vector2.ZERO
	finger_btn.clear()
	_update_dir()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for bt in buttons:
				if p.distance_to(_btn_pos(bt)) < bt.r * 1.2:
					finger_btn[event.index] = bt.b
					arena.player_input.press(bt.b)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if stick_id == -1 and p.x < size.x * 0.5 and p.y > size.y * 0.22:
				stick_id = event.index
				stick_center = p
				stick_vec = Vector2.ZERO
				_update_dir()
				get_viewport().set_input_as_handled()
		else:
			if event.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
				_update_dir()
			finger_btn.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == stick_id:
		var v: Vector2 = event.position - stick_center
		if v.length() > STICK_R * 1.6:
			# Let the stick follow the thumb so it never "runs out".
			stick_center = event.position - v.normalized() * STICK_R * 1.6
			v = event.position - stick_center
		stick_vec = v.limit_length(STICK_R)
		_update_dir()
		get_viewport().set_input_as_handled()
		queue_redraw()


func _update_dir() -> void:
	var v := stick_vec
	tx = 0
	if v.x > STICK_R * 0.35:
		tx = 1
	elif v.x < -STICK_R * 0.35:
		tx = -1
	tup = v.y < -STICK_R * 0.5
	tdown = v.y > STICK_R * 0.5


func _draw() -> void:
	var c := stick_center if stick_id != -1 else _default_stick()
	draw_circle(c, STICK_R + 6.0, Color(1, 1, 1, 0.07))
	draw_arc(c, STICK_R + 6.0, 0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)
	draw_circle(c + stick_vec, 28.0, Color(1, 1, 1, 0.35 if stick_id != -1 else 0.2))
	draw_arc(c + stick_vec, 28.0, 0, TAU, 32, Color(1, 1, 1, 0.6), 2.0, true)
	var held := finger_btn.values()
	for bt in buttons:
		var p := _btn_pos(bt)
		var on: bool = bt.b in held
		var r: float = bt.r * (0.92 if on else 1.0)
		var col: Color = bt.color
		draw_circle(p, r, Color(col, 0.75 if on else 0.42))
		draw_arc(p, r, 0, TAU, 40, Color(1, 1, 1, 0.8 if on else 0.5), 3.0, true)
		var fs := 13 if bt.label.length() > 5 else 15
		draw_string_outline(font, p + Vector2(-r, fs * 0.35), bt.label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 4, Color(0, 0, 0, 0.7))
		draw_string(font, p + Vector2(-r, fs * 0.35), bt.label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
