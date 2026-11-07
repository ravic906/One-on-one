class_name GameData
extends RefCounted
## Static tuning data: stage constants, roster, move frame data and poses.
## Everything is measured in 60 Hz frames and world pixels (960x540 stage).

const W := 960.0
const H := 540.0
const FLOOR := 470.0
const STAGE_L := 40.0
const STAGE_R := 920.0
const GRAV := 0.85
const ROUND_TIME := 60
const ROUNDS_TO_WIN := 2
const BUFFER_FRAMES := 7

## Fighter roster. speed/power are multipliers; scale changes body size and hitboxes.
static var ROSTER: Array = [
	{
		"id": "kade", "name": "KADE", "title": "The Steady Fist",
		"color": Color(0.25, 0.66, 0.96), "dark": Color(0.11, 0.37, 0.56), "accent": Color(1.0, 0.85, 0.29),
		"speed": 1.0, "power": 1.0, "hp": 1000, "scale": 1.0,
		"proj_speed": 7.5, "proj_color": Color(0.5, 0.85, 1.0), "proj_dmg": 70,
	},
	{
		"id": "vexa", "name": "VEXA", "title": "Storm Dancer",
		"color": Color(0.91, 0.37, 0.82), "dark": Color(0.54, 0.17, 0.48), "accent": Color(0.62, 1.0, 0.88),
		"speed": 1.22, "power": 0.86, "hp": 920, "scale": 0.95,
		"proj_speed": 10.0, "proj_color": Color(1.0, 0.62, 0.94), "proj_dmg": 55,
	},
	{
		"id": "gorr", "name": "GORR", "title": "Iron Mountain",
		"color": Color(0.95, 0.6, 0.17), "dark": Color(0.56, 0.33, 0.06), "accent": Color(1.0, 0.3, 0.3),
		"speed": 0.82, "power": 1.25, "hp": 1120, "scale": 1.1,
		"proj_speed": 5.5, "proj_color": Color(1.0, 0.76, 0.42), "proj_dmg": 95,
	},
]

## Frame data.
##  s/a/r  = startup / active / recovery frames
##  hs/bs  = hitstun / blockstun applied to the defender
##  hb     = hitbox [forward offset, centre height above feet, width, height]
##  level  = "high" (block standing), "mid" (block either way), "low" (block crouching)
##  cancel = moves this one can cancel into after it connects
static var MOVES: Dictionary = {
	"jab": {"s": 4, "a": 3, "r": 9, "dmg": 35, "hs": 15, "bs": 9, "push": 4.0,
		"hb": [20, 108, 58, 30], "level": "mid", "pose": "jab", "sfx": "light",
		"cancel": ["jab", "heavy", "cjab", "low", "special", "super"]},
	"heavy": {"s": 9, "a": 4, "r": 17, "dmg": 85, "hs": 21, "bs": 13, "push": 8.0, "lunge": 3.0,
		"hb": [20, 88, 72, 40], "level": "mid", "pose": "heavy", "sfx": "heavy",
		"cancel": ["special", "super"]},
	"cjab": {"s": 4, "a": 3, "r": 9, "dmg": 30, "hs": 14, "bs": 8, "push": 4.0, "crouch": true,
		"hb": [20, 80, 56, 28], "level": "mid", "pose": "cjab", "sfx": "light",
		"cancel": ["cjab", "jab", "low", "heavy", "special", "super"]},
	"low": {"s": 8, "a": 4, "r": 20, "dmg": 70, "hs": 22, "bs": 14, "push": 7.0, "crouch": true, "knockdown": true,
		"hb": [15, 14, 84, 26], "level": "low", "pose": "low", "sfx": "heavy",
		"cancel": ["special", "super"]},
	"air": {"s": 5, "a": 9, "r": 6, "dmg": 65, "hs": 18, "bs": 11, "push": 5.0, "airborne": true,
		"hb": [5, 30, 62, 44], "level": "high", "pose": "air", "sfx": "heavy",
		"cancel": []},
	"special": {"s": 12, "a": 1, "r": 24, "proj": true, "pose": "special", "cancel": []},
	"grab": {"s": 5, "a": 2, "r": 26, "dmg": 110, "grab": true, "knockdown": true,
		"hb": [0, 100, 58, 80], "level": "mid", "pose": "grab", "sfx": "grab", "cancel": []},
	"super": {"s": 16, "a": 24, "r": 22, "dmg": 250, "hs": 30, "bs": 16, "push": 10.0, "knockdown": true, "super": true,
		"hb": [-10, 100, 80, 110], "level": "mid", "pose": "super", "sfx": "super", "cancel": []},
}

## Skeleton poses: absolute joint angles in radians, 0 = pointing down, + = towards facing.
## aF/aB = front/back arm (upper, lower), lF/lB = front/back leg, lean = torso, rot = whole body.
static func _pose(lean: float, afu: float, afl: float, abu: float, abl: float,
		lfu: float, lfl: float, lbu: float, lbl: float, rot := 0.0) -> Dictionary:
	return {"lean": lean, "aFu": afu, "aFl": afl, "aBu": abu, "aBl": abl,
		"lFu": lfu, "lFl": lfl, "lBu": lbu, "lBl": lbl, "rot": rot}

static var POSES: Dictionary = {
	"idle":     _pose(0.12, 0.7, 2.5, 0.35, 2.3, 0.32, 0.05, -0.32, -0.32),
	"crouch":   _pose(0.4, 0.9, 2.6, 0.6, 2.4, 1.25, -0.15, 0.55, -1.1),
	"jump":     _pose(0.15, 1.0, 2.4, 0.6, 2.0, 1.3, 0.2, 0.4, -0.6),
	"dash":     _pose(0.35, 0.9, 2.4, 0.2, 1.6, 0.7, 0.1, -0.6, -0.5),
	"jab":      _pose(0.25, 1.57, 1.57, 0.45, 2.4, 0.45, 0.1, -0.45, -0.45),
	"heavy":    _pose(-0.35, 0.9, 2.6, 0.4, 2.0, 1.75, 1.95, -0.15, -0.1),
	"cjab":     _pose(0.35, 1.6, 1.6, 0.6, 2.4, 1.25, -0.15, 0.55, -1.1),
	"low":      _pose(0.2, 1.0, 2.2, 0.5, 1.8, 1.2, 1.45, 0.9, -1.3),
	"air":      _pose(0.1, 1.1, 2.2, 0.5, 1.6, 1.1, 1.0, 0.3, -0.9),
	"special":  _pose(0.2, 1.57, 1.57, 1.45, 1.6, 0.5, 0.1, -0.5, -0.5),
	"grab":     _pose(0.3, 1.35, 1.5, 1.2, 1.5, 0.45, 0.1, -0.45, -0.45),
	"super":    _pose(0.5, 1.57, 1.57, 0.2, 0.6, 0.8, 0.3, -0.6, -0.4),
	"hit":      _pose(-0.45, 0.2, 0.9, -0.2, 0.5, 0.25, 0.1, -0.3, -0.3),
	"block":    _pose(-0.05, 1.1, 2.9, 0.9, 2.8, 0.3, 0.05, -0.35, -0.35),
	"cblock":   _pose(0.25, 1.2, 2.9, 1.0, 2.8, 1.25, -0.15, 0.55, -1.1),
	"launched": _pose(-0.6, -0.4, -0.2, -0.8, -0.5, 0.8, 0.4, 0.2, 0.1, -0.5),
	"down":     _pose(0.0, -0.3, 0.0, 0.3, 0.2, 0.1, 0.0, -0.1, 0.0, -1.5708),
	"win":      _pose(0.0, 2.9, 3.1, 0.3, 1.2, 0.2, 0.0, -0.2, -0.2),
}

## CPU difficulty profiles.
static var AI_LEVELS: Dictionary = {
	"easy":   {"react": 24, "block": 0.15, "anti_air": 0.10, "aggr": 0.35, "read_low": 0.20, "drop": 0.50},
	"normal": {"react": 13, "block": 0.45, "anti_air": 0.35, "aggr": 0.55, "read_low": 0.45, "drop": 0.25},
	"hard":   {"react": 6,  "block": 0.78, "anti_air": 0.70, "aggr": 0.70, "read_low": 0.75, "drop": 0.05},
}
