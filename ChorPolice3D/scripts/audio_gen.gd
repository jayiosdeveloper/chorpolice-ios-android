## audio_gen — one-off: synthesizes all SFX + jetpack loop + 2 chiptune music tracks
## (ported from the iOS AudioManager) and saves them as .wav into res://assets/audio/.
## Runtime loading is then instant. Run headless:
##   Godot --headless --path PROJ --script res://scripts/audio_gen.gd
extends SceneTree

const SR := 44100.0

var _ns := 0x12345678

func _noise() -> float:
	_ns ^= (_ns << 13) & 0xFFFFFFFF
	_ns ^= (_ns >> 17)
	_ns ^= (_ns << 5) & 0xFFFFFFFF
	var v := _ns & 0xFFFFFFFF
	if v >= 0x80000000:
		v -= 0x100000000
	return float(v) / 2147483647.0

func _decay(t: float, dur: float, k := 5.0) -> float:
	return 0.0 if t >= dur else exp(-k * t / dur)

func _buf(duration: float) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(int(SR * duration))
	return f

func _save(f: PackedFloat32Array, name: String, loop := false) -> void:
	var bytes := PackedByteArray()
	bytes.resize(f.size() * 2)
	for i in f.size():
		bytes.encode_s16(i * 2, int(clampf(f[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = f.size()
	var dir := ProjectSettings.globalize_path("res://assets/audio/")
	DirAccess.make_dir_recursive_absolute(dir)
	w.save_to_wav(dir + name + ".wav")

func _initialize() -> void:
	_gen_sfx()
	_gen_extra()
	_gen_jet()
	_save(_menu_music(), "music_menu", true)
	_save(_battle_music(), "music_battle", true)
	print("[audio] written to ", ProjectSettings.globalize_path("res://assets/audio/"))
	quit()

# MARK: SFX (one-shots)

func _gen_sfx() -> void:
	var f: PackedFloat32Array

	f = _buf(0.09)
	for i in f.size():
		var t := i / SR
		var fr := 1600.0 - 1200.0 * (t / 0.09)
		f[i] = (sin(TAU * fr * t) * 0.5 + _noise() * 0.3) * _decay(t, 0.09, 6.0) * 0.55
	_save(f, "rifle")

	f = _buf(0.06)
	for i in f.size():
		var t := i / SR
		var fr := 1300.0 - 900.0 * (t / 0.06)
		f[i] = (sin(TAU * fr * t) * 0.5 + _noise() * 0.25) * _decay(t, 0.06, 6.0) * 0.45
	_save(f, "uzi")

	f = _buf(0.25)
	for i in f.size():
		var t := i / SR
		var boom := sin(TAU * 110.0 * t) * 0.5
		f[i] = (_noise() * 0.6 + boom) * _decay(t, 0.25, 7.0) * 0.7
	_save(f, "shotgun")

	f = _buf(0.16)
	for i in f.size():
		var t := i / SR
		var fr := 2200.0 - 1900.0 * (t / 0.16)
		f[i] = (sin(TAU * fr * t) * 0.45 + _noise() * 0.5) * _decay(t, 0.16, 8.0) * 0.7
	_save(f, "sniper")

	f = _buf(0.07)
	for i in f.size():
		var t := i / SR
		f[i] = sin(TAU * 620.0 * t) * _decay(t, 0.07, 6.0) * 0.4
	_save(f, "hit")

	f = _buf(0.55)
	for i in f.size():
		var t := i / SR
		var boom := sin(TAU * (70.0 - 30.0 * t) * t) * 0.6
		f[i] = (_noise() * 0.55 + boom) * _decay(t, 0.55, 5.0) * 0.8
	_save(f, "explosion")

	f = _buf(0.18)
	for i in f.size():
		var t := i / SR
		var fr := 660.0 if t < 0.09 else 990.0
		f[i] = sin(TAU * fr * t) * _decay(fmod(t, 0.09), 0.09, 3.0) * 0.4
	_save(f, "pickup")

	f = _buf(0.3)
	for i in f.size():
		var t := i / SR
		var step := int(t / 0.1)
		var fr: float = [659.0, 784.0, 1047.0][mini(step, 2)]
		f[i] = sin(TAU * fr * t) * _decay(fmod(t, 0.1), 0.1, 3.0) * 0.45
	_save(f, "capture")

	f = _buf(0.9)
	for i in f.size():
		var t := i / SR
		var step := int(t / 0.18)
		var fr: float = [523.0, 659.0, 784.0, 1047.0, 1319.0][mini(step, 4)]
		f[i] = sin(TAU * fr * t) * _decay(fmod(t, 0.18), 0.18, 2.5) * 0.5
	_save(f, "win")

	f = _buf(0.14)
	for i in f.size():
		var t := i / SR
		var rumble := sin(TAU * 95.0 * t) * 0.2
		f[i] = (_noise() * 0.35 + rumble) * _decay(t, 0.14, 3.0) * 0.4
	_save(f, "flame")

	f = _buf(0.5)
	for i in f.size():
		var t := i / SR
		var fr := 320.0 - 230.0 * (t / 0.5)
		f[i] = (_noise() * 0.5 + sin(TAU * fr * t) * 0.35) * _decay(t, 0.5, 4.0) * 0.7
	_save(f, "rocket")

	f = _buf(0.08)
	for i in f.size():
		var t := i / SR
		var fr := 480.0 + 1800.0 * t
		f[i] = sin(TAU * fr * t) * _decay(t, 0.08, 5.0) * 0.35
	_save(f, "nade_throw")

## Extra foley for the 3D game: magazine reload (out-click, in-clack, bolt), footstep,
## empty-chamber click, weapon swap.
func _gen_extra() -> void:
	var f: PackedFloat32Array
	f = _buf(1.1)
	for i in f.size():
		var t := i / SR
		var v := 0.0
		if t < 0.08:
			v = (_noise() * 0.6 + sin(TAU * 900.0 * t) * 0.3) * _decay(t, 0.08, 7.0)          # mag release click
		elif t > 0.55 and t < 0.68:
			var tt := t - 0.55
			v = (_noise() * 0.5 + sin(TAU * 420.0 * tt) * 0.5) * _decay(tt, 0.13, 6.0)        # mag seats
		elif t > 0.85 and t < 0.98:
			var tt := t - 0.85
			v = (_noise() * 0.4 + sin(TAU * 1400.0 * tt) * 0.4) * _decay(tt, 0.13, 8.0)       # bolt
		f[i] = v * 0.7
	_save(f, "reload")

	f = _buf(0.09)
	for i in f.size():
		var t := i / SR
		f[i] = (_noise() * 0.5 + sin(TAU * 90.0 * t) * 0.5) * _decay(t, 0.09, 8.0) * 0.35     # soft thud
	_save(f, "step")

	f = _buf(0.05)
	for i in f.size():
		var t := i / SR
		f[i] = (sin(TAU * 2200.0 * t) * 0.6 + _noise() * 0.2) * _decay(t, 0.05, 9.0) * 0.5
	_save(f, "click")

	f = _buf(0.16)
	for i in f.size():
		var t := i / SR
		f[i] = (_noise() * 0.5 + sin(TAU * (600.0 + 900.0 * t) * t) * 0.3) * _decay(t, 0.16, 5.0) * 0.4
	_save(f, "swap")

func _gen_jet() -> void:
	var f := _buf(0.6)
	for i in f.size():
		var t := i / SR
		var rumble := sin(TAU * 85.0 * t) * 0.3
		var hiss := _noise() * 0.4
		var wobble := 0.75 + 0.25 * sin(TAU * 9.0 * t)
		f[i] = (rumble + hiss) * wobble * 0.6
	_save(f, "jet", true)

# MARK: music helpers

func _osc(wave: int, phase: float) -> float:
	match wave:
		1: return 0.5 if sin(phase) > 0.0 else -0.5                       # square
		2: return sin(phase) * 0.55 + (0.32 if sin(phase) > 0.0 else -0.32)  # lead
		_: return sin(phase)                                              # sine

func _note(f: PackedFloat32Array, start: float, dur: float, freq: float, vol: float,
		wave: int, attack := 0.012, vibrato := 0.0, decayk := 2.8) -> void:
	var s := int(start * SR)
	var n := int(dur * SR)
	for j in n:
		var idx := s + j
		if idx >= f.size():
			break
		var t := j / SR
		var vib := (1.0 + 0.004 * sin(TAU * vibrato * t)) if vibrato > 0.0 else 1.0
		var env := exp(-decayk * t / dur) * minf(1.0, t / attack)
		f[idx] += _osc(wave, TAU * freq * vib * t) * env * vol

func _kick(f: PackedFloat32Array, start: float) -> void:
	var s := int(start * SR)
	var n := int(0.11 * SR)
	var phase := 0.0
	for j in n:
		var idx := s + j
		if idx >= f.size():
			break
		var t := j / SR
		var fr := 42.0 + 95.0 * exp(-30.0 * t)
		phase += TAU * fr / SR
		f[idx] += sin(phase) * exp(-9.0 * t) * 0.5

func _snare(f: PackedFloat32Array, start: float) -> void:
	var s := int(start * SR)
	var n := int(0.1 * SR)
	for j in n:
		var idx := s + j
		if idx >= f.size():
			break
		var t := j / SR
		f[idx] += (_noise() * 0.5 + sin(TAU * 185.0 * t) * 0.18) * exp(-16.0 * t) * 0.5

func _hat(f: PackedFloat32Array, start: float, vol: float) -> void:
	var s := int(start * SR)
	var n := int(0.025 * SR)
	for j in n:
		var idx := s + j
		if idx >= f.size():
			break
		f[idx] += _noise() * vol * exp(-float(j) / (0.012 * SR))

func _menu_music() -> PackedFloat32Array:
	var beat := 60.0 / 112.0
	var bar := beat * 4.0
	var f := _buf(bar * 8.0)
	var bass := [110.00, 87.31, 130.81, 98.00]
	var pads := [[220.00, 261.63, 329.63], [174.61, 220.00, 261.63],
		[261.63, 329.63, 392.00], [196.00, 246.94, 293.66]]
	var melody := [
		[0, 0.0, 0.75, 440.00], [0, 0.75, 0.25, 493.88], [0, 1.0, 0.75, 523.25],
		[0, 1.75, 0.25, 587.33], [0, 2.0, 1.4, 659.25], [0, 3.5, 0.5, 587.33],
		[1, 0.0, 1.0, 523.25], [1, 1.0, 1.0, 440.00], [1, 2.0, 1.9, 349.23],
		[2, 0.0, 0.75, 392.00], [2, 0.75, 0.25, 440.00], [2, 1.0, 0.75, 493.88],
		[2, 1.75, 0.25, 523.25], [2, 2.0, 1.4, 659.25], [2, 3.5, 0.5, 698.46],
		[3, 0.0, 1.0, 587.33], [3, 1.0, 1.0, 493.88], [3, 2.0, 1.9, 392.00]]
	for b in 8:
		var bs := float(b) * bar
		var ch := b % 4
		for fr in pads[ch]:
			_note(f, bs, bar * 0.98, fr, 0.030, 1, 0.18, 0.0, 1.1)
			_note(f, bs, bar * 0.98, fr * 1.004, 0.024, 1, 0.18, 0.0, 1.1)
		for e in 8:
			var ef: float = bass[ch] * 2.0 if e % 4 == 2 else bass[ch]
			_note(f, bs + float(e) * beat / 2.0, beat * 0.42, ef, 0.15, 1, 0.012, 0.0, 3.5)
		for d in 4:
			_kick(f, bs + float(d) * beat)
			if d == 1 or d == 3:
				_snare(f, bs + float(d) * beat)
		var hstep := beat / 4.0 if b >= 4 else beat / 2.0
		var ht := bs
		while ht < bs + bar - 0.01:
			_hat(f, ht, 0.042 if b >= 4 else 0.05)
			ht += hstep
		if b >= 4:
			var tones = pads[ch]
			var at := bs
			var k := 0
			while at < bs + bar - 0.01:
				_note(f, at, beat * 0.22, tones[k % 3] * (4.0 if k % 4 == 3 else 2.0), 0.035, 0, 0.012, 0.0, 4.0)
				k += 1
				at += beat / 4.0
	for rep in 2:
		var off := float(rep) * bar * 4.0
		for m in melody:
			var st: float = off + float(m[0]) * bar + float(m[1]) * beat
			var dur: float = float(m[2]) * beat
			var fr: float = m[3]
			_note(f, st, dur, fr, 0.115 if rep == 0 else 0.085, 2, 0.012, 5.5)
			_note(f, st + beat * 0.75, dur * 0.8, fr, 0.035, 2, 0.012, 5.5)
			if rep == 1:
				_note(f, st, dur, fr * 2.0, 0.07, 2, 0.012, 5.5)
	return f

func _battle_music() -> PackedFloat32Array:
	var beat := 60.0 / 132.0
	var total := beat * 4.0 * 4.0
	var f := _buf(total)
	var bassn := [55.0, 55.0, 65.41, 73.42]
	for bar in 4:
		var root: float = bassn[bar]
		for b in 4:
			_note(f, (float(bar) * 4.0 + float(b)) * beat, beat * 0.9, root, 0.30, 1, 0.01, 0.0, 3.5)
	var arp := [220.0, 261.63, 329.63, 440.0, 329.63, 261.63]
	var k := 0
	var t8 := 0.0
	while t8 < total - beat / 2.0:
		_note(f, t8, beat * 0.42, arp[k % arp.size()] * 2.0, 0.13, 0, 0.01, 0.0, 3.5)
		k += 1
		t8 += beat / 2.0
	var th := 0.0
	while th < total:
		_hat(f, th, 0.07)
		th += beat / 2.0
	return f
