extends Node
## Sound effects, music and haptics. Sounds are synthesised offline by
## tools/gen_audio.py; each name gets a small round-robin pool of players so
## overlapping, differently pitched hits never cut each other off.

const SOUNDS := ["pick", "place", "drop_bad", "clear", "prism", "perfect", "deal",
		"gameover", "newbest", "click", "land", "combo", "whoosh"]
const POOL := 4
## Pentatonic ladder (semitones) that clear sounds climb as a combo grows.
const LADDER := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31]

var _pools := {}
var _next := {}
var _music: AudioStreamPlayer
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for n in SOUNDS:
		var path := "res://assets/audio/%s.wav" % n
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		var pool := []
		for i in POOL:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "SFX"
			add_child(p)
			pool.append(p)
		_pools[n] = pool
		_next[n] = 0
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -60.0
	if ResourceLoader.exists("res://assets/audio/music.ogg"):
		var m: AudioStream = load("res://assets/audio/music.ogg")
		if m is AudioStreamOggVorbis:
			m.loop = true
		_music.stream = m
	add_child(_music)
	apply_settings()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not Save.setting("sound"))
	var music_on := Save.setting("music")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	if music_on and _music.stream != null and not _music.playing:
		start_music()


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _pools.has(sound):
		return
	var pool: Array = _pools[sound]
	var p: AudioStreamPlayer = pool[_next[sound]]
	_next[sound] = (_next[sound] + 1) % pool.size()
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


## Play a sound transposed up the pentatonic ladder by `step`.
func play_step(sound: String, step: int, volume_db := 0.0) -> void:
	var semis: int = LADDER[clampi(step, 0, LADDER.size() - 1)]
	play(sound, pow(2.0, semis / 12.0), volume_db)


func start_music() -> void:
	if _music.stream == null:
		return
	if not _music.playing:
		_music.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -9.0, 2.5)


func duck_music(duck: bool) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -20.0 if duck else -9.0, 0.6)


## Haptic tap. `strength` 0..1. No-op on desktop or when disabled.
func haptic(ms: int, strength := 0.5) -> void:
	if not Save.setting("haptics"):
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(ms, clampf(strength, 0.05, 1.0))
