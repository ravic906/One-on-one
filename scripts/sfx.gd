class_name Sfx
extends Node
## Tiny synthesizer: every sound effect is generated as PCM at startup, so the game ships no audio files.

const RATE := 22050

var enabled := true
var streams := {}
var players: Array[AudioStreamPlayer] = []
var _idx := 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		players.append(p)
	_build()


func play(n: String) -> void:
	if not enabled or not streams.has(n):
		return
	var p := players[_idx]
	_idx = (_idx + 1) % players.size()
	p.stream = streams[n]
	p.play()


func _build() -> void:
	streams["light"] = _make([_noise(0.07, 2400.0, "band", 0.5), _tone(0.06, 300.0, 120.0, "square", 0.08)])
	streams["heavy"] = _make([_noise(0.14, 1000.0, "low", 0.7), _tone(0.15, 180.0, 50.0, "sine", 0.55)])
	streams["block"] = _make([_tone(0.05, 1200.0, 900.0, "square", 0.1), _noise(0.04, 4000.0, "high", 0.25)])
	streams["whiff"] = _make([_noise(0.08, 1800.0, "high", 0.12)])
	streams["proj"] = _make([_tone(0.25, 220.0, 880.0, "saw", 0.1)])
	streams["super"] = _make([_tone(0.5, 110.0, 1400.0, "saw", 0.12), _noise(0.5, 600.0, "low", 0.2)])
	streams["grab"] = _make([_noise(0.2, 500.0, "low", 0.6), _tone(0.25, 120.0, 40.0, "sine", 0.5)])
	streams["ko"] = _make([_tone(0.9, 160.0, 30.0, "sine", 0.6), _noise(0.6, 400.0, "low", 0.5)])
	streams["fight"] = _make([_tone(0.15, 440.0, 880.0, "square", 0.1), _delay(_tone(0.25, 660.0, 1320.0, "square", 0.1), 0.12)])
	streams["tick"] = _make([_tone(0.04, 800.0, 800.0, "square", 0.06)])
	streams["jump"] = _make([_noise(0.06, 900.0, "band", 0.15)])
	streams["ui"] = _make([_tone(0.05, 600.0, 900.0, "square", 0.06)])


func _tone(dur: float, f0: float, f1: float, wave: String, gain: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var fr := f0 * pow(f1 / f0, t)
		ph += fr / RATE
		var x := 0.0
		match wave:
			"sine": x = sin(ph * TAU)
			"square": x = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw": x = fmod(ph, 1.0) * 2.0 - 1.0
		out[i] = x * gain * pow(0.001, t)
	return out


func _noise(dur: float, cutoff: float, mode: String, gain: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_lo := 1.0 - exp(-TAU * cutoff * 0.6 / RATE)
	var a_hi := 1.0 - exp(-TAU * cutoff * 1.5 / RATE)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	var y_lo := 0.0
	var y_hi := 0.0
	for i in n:
		var t := float(i) / n
		var x := randf() * 2.0 - 1.0
		var v := 0.0
		match mode:
			"low":
				y += a * (x - y)
				v = y * 2.0
			"high":
				y += a * (x - y)
				v = x - y
			"band":
				y_lo += a_lo * (x - y_lo)
				y_hi += a_hi * (x - y_hi)
				v = (y_hi - y_lo) * 3.0
		out[i] = v * gain * pow(0.001, t)
	return out


func _delay(buf: PackedFloat32Array, secs: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(secs * RATE))
	pad.append_array(buf)
	return pad


func _make(layers: Array) -> AudioStreamWAV:
	var n := 0
	for l in layers:
		n = maxi(n, l.size())
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := 0.0
		for l in layers:
			if i < l.size():
				v += l[i]
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
