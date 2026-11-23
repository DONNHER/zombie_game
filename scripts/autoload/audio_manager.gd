extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 12
const COMBAT_BASS_NOTES := [40, 40, 40, 43, 40, 40, 46, 43, 38, 38, 41, 38, 43, 43, 46, 41]

var _players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _muted: bool = false
var _volume: float = 0.55
var _vibration: bool = true
var _cache: Dictionary = {}
var _combat_player: AudioStreamPlayer
var _combat_music_requested := false


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_combat_player = AudioStreamPlayer.new()
	add_child(_combat_player)
	_apply_settings(SaveManager.settings)
	SaveManager.settings_changed.connect(_apply_settings)


func _apply_settings(s: Dictionary) -> void:
	_muted = bool(s.get("muted", false))
	_volume = clampf(float(s.get("volume", 0.55)), 0.0, 1.0)
	_vibration = bool(s.get("vibration", true))
	_update_combat_music()


func start_combat_music() -> void:
	_combat_music_requested = true
	_update_combat_music()


func stop_combat_music() -> void:
	_combat_music_requested = false
	_update_combat_music()


func _update_combat_music() -> void:
	if not _combat_music_requested:
		_combat_player.stop()
		return
	_combat_player.volume_db = linear_to_db(_volume * 0.4) if _volume > 0.01 and not _muted else -80.0
	if _combat_player.playing or _volume <= 0.01 or _muted:
		return
	if _combat_player.stream == null:
		_combat_player.stream = _build_combat_loop()
	_combat_player.play()


func _build_combat_loop() -> AudioStreamWAV:
	var samples_per_step := 6615
	var count := samples_per_step * COMBAT_BASS_NOTES.size()
	var frequencies := PackedFloat32Array()
	for note in COMBAT_BASS_NOTES:
		frequencies.append(440.0 * pow(2.0, (note - 69.0) / 12.0))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 1279
	var filtered_noise := 0.0
	for i in range(count):
		@warning_ignore("integer_division")
		var step := i / samples_per_step
		var t := float(i % samples_per_step) / SAMPLE_RATE
		var phase := TAU * frequencies[step] * t
		var bass_env := minf(t * 90.0, 1.0) * maxf(1.0 - t / 0.27, 0.0)
		var bass := (sin(phase) + 0.35 * sin(2.0 * phase) + 0.20 * sin(3.0 * phase)) * bass_env
		var roll := noise.randf_range(-1.0, 1.0)
		filtered_noise = lerpf(filtered_noise, roll, 0.22)
		var hat := (roll - filtered_noise) * minf(t * 500.0, 1.0) * exp(-t * 70.0)
		var drum := 0.0
		if step % 4 == 0 or step % 8 == 3:
			drum = sin(TAU * (46.0 * t + 2.5 * (1.0 - exp(-t * 38.0)))) * exp(-t * 26.0)
		elif step % 4 == 2:
			drum = filtered_noise * minf(t * 350.0, 1.0) * exp(-t * 22.0)
		var sample := bass * 0.30 + drum * 0.36 + hat * 0.13
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var wav := _pcm_wav(bytes)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


func trigger_haptic(duration_ms: int = 35) -> void:
	if not _vibration:
		return
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)


func _play_tone(cache_key: String, freq_start: float, freq_end: float, duration: float, wave: String, gain: float) -> void:
	if _muted or _volume <= 0.01:
		return
	var stream: AudioStreamWAV
	if _cache.has(cache_key):
		stream = _cache[cache_key]
	else:
		stream = _build_wav(freq_start, freq_end, duration, wave, gain)
		_cache[cache_key] = stream
	_play_stream(stream)


func _play_stream(stream: AudioStreamWAV) -> void:
	var player := _players[_next_idx]
	_next_idx = (_next_idx + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = linear_to_db(clampf(_volume, 0.01, 1.0))
	player.play()


func _build_wav(freq_start: float, freq_end: float, duration: float, wave: String, gain: float) -> AudioStreamWAV:
	var count := maxi(128, int(float(SAMPLE_RATE) * duration))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		var freq := lerpf(freq_start, freq_end, t)
		phase += (TAU * freq) / float(SAMPLE_RATE)
		var sample_val := 0.0
		match wave:
			"square":
				sample_val = 1.0 if sin(phase) >= 0.0 else -1.0
			"sawtooth":
				var norm := fmod(phase / TAU, 1.0)
				sample_val = norm * 2.0 - 1.0
			"triangle":
				var norm := fmod(phase / TAU, 1.0)
				sample_val = 4.0 * absf(norm - 0.5) - 1.0
			_:
				sample_val = sin(phase)
		var env := (1.0 - t) * gain
		var pcm := int(clampf(sample_val * env, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, pcm)

	return _pcm_wav(bytes)


func _pcm_wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func play_pistol_shot(pitch_offset: float = 0.0) -> void:
	var p := int(round(pitch_offset))
	_play_tone("pistol_%d" % p, 520.0 + pitch_offset, 140.0, 0.08, "square", 0.12)


func play_magic_cast(pitch_offset: float = 0.0) -> void:
	var p := int(round(pitch_offset))
	_play_tone("magic_%d" % p, 660.0 + pitch_offset, 980.0, 0.12, "sine", 0.14)


func play_reload() -> void:
	_play_tone("reload_1", 280.0, 440.0, 0.08, "triangle", 0.10)


func play_enemy_hit() -> void:
	_play_tone("hit", 190.0, 95.0, 0.06, "sawtooth", 0.08)


func play_enemy_kill() -> void:
	play_zombie_death()


func play_zombie_death() -> void:
	_play_death("zombie_death", 0.27, 142.0, 0.23, 0.0)


func play_boss_death() -> void:
	_play_death("boss_death", 1.10, 88.0, 0.46, 0.52)


func _play_death(cache_key: String, duration: float, pitch: float, gain: float, impact_gain: float) -> void:
	if _muted or _volume <= 0.01:
		return
	if not _cache.has(cache_key):
		var count := int(duration * SAMPLE_RATE)
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		var noise := RandomNumberGenerator.new()
		noise.seed = 6659
		var rumble := 0.0
		var phase := 0.0
		for i in range(count):
			var t := float(i) / count
			var seconds := t * duration
			var roll := noise.randf_range(-1.0, 1.0)
			rumble = lerpf(rumble, roll, 0.12)
			phase += TAU * lerpf(pitch, pitch * 0.33, sqrt(t)) / SAMPLE_RATE
			var growl := 0.46 * sin(phase) + 0.20 * sin(phase * 2.07) + 0.10 * sin(phase * 4.1)
			var grit := rumble * 0.48 + roll * 0.12 * exp(-t * 9.0)
			var impact := impact_gain * sin(TAU * (48.0 * seconds + 1.7 * (1.0 - exp(-seconds * 44.0)))) * exp(-seconds * 8.0)
			var decay := (1.0 - t) * (1.0 - t)
			var sample := ((growl + grit) * decay + impact) * minf(seconds * 280.0, 1.0) * gain
			bytes.encode_s16(i * 2, int(sample * 32767.0))
		_cache[cache_key] = _pcm_wav(bytes)
	_play_stream(_cache[cache_key])


func play_player_hurt() -> void:
	_play_tone("hurt", 160.0, 65.0, 0.18, "sawtooth", 0.18)
	trigger_haptic(45)


func play_skill() -> void:
	_play_tone("skill", 320.0, 880.0, 0.22, "sine", 0.15)
	trigger_haptic(30)


func play_pickup() -> void:
	_play_tone("pickup", 520.0, 1020.0, 0.12, "sine", 0.12)


func play_boss_telegraph() -> void:
	_play_tone("boss_warn", 120.0, 80.0, 0.35, "sawtooth", 0.22)
	trigger_haptic(80)


func play_victory() -> void:
	_play_tone("victory", 523.25, 1046.5, 0.38, "triangle", 0.16)


func play_defeat() -> void:
	_play_tone("defeat", 300.0, 110.0, 0.42, "sawtooth", 0.16)
