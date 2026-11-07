class_name InputState
extends RefCounted
## One fighter's controller state. Written by touch/keyboard (player) or FighterAI (CPU).
## Button presses are buffered for a few frames so slightly early inputs still come out.

var x := 0            ## -1 left, 0 neutral, 1 right (absolute, not relative to facing)
var up := false
var down := false
var dash := 0         ## set for one frame when a double-tap dash is detected (-1 / 1)
var buf := {"L": 0, "H": 0, "S": 0, "G": 0}

var _prev_x := 0
var _last_tap := 0
var _last_tap_frame := -99


func set_dir(nx: int, nup: bool, ndown: bool, frame: int) -> void:
	if nx != 0 and _prev_x == 0:
		if nx == _last_tap and frame - _last_tap_frame <= 12:
			dash = nx
			_last_tap_frame = -99
		else:
			_last_tap = nx
			_last_tap_frame = frame
	_prev_x = nx
	x = nx
	up = nup
	down = ndown


func press(b: String) -> void:
	buf[b] = GameData.BUFFER_FRAMES


func consume(b: String) -> void:
	buf[b] = 0


func tick() -> void:
	for k in buf:
		if buf[k] > 0:
			buf[k] -= 1
	dash = 0


func clear() -> void:
	x = 0
	up = false
	down = false
	dash = 0
	for k in buf:
		buf[k] = 0
