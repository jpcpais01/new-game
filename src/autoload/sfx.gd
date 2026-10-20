extends Node
## Sound effects, layered music and haptics. Every sound is synthesised by
## tools/gen_audio.py. Each sound has a small pool of players and a minimum
## gap, so hundreds of hits per second never turn into noise.

const SOUNDS := {
	# name: [pool size, min gap seconds, base volume dB]
	"click": [2, 0.03, -4.0], "card": [3, 0.03, -3.0], "select": [2, 0.05, -1.0],
	"levelup": [2, 0.1, -1.0], "shoot": [4, 0.05, -15.0], "hit": [4, 0.035, -13.0],
	"kill": [6, 0.028, -8.0], "kill_big": [3, 0.08, -2.0], "gem": [6, 0.022, -11.0],
	"hurt": [2, 0.1, -1.0], "nova": [2, 0.1, -4.0], "zap": [3, 0.06, -8.0],
	"lance": [2, 0.08, -5.0], "missile": [3, 0.06, -12.0], "boom": [4, 0.05, -6.0],
	"alarm": [1, 0.5, -6.0], "boss_down": [1, 0.5, 0.0], "pickup": [2, 0.06, -3.0],
	"revive": [1, 0.5, 0.0], "win": [1, 0.5, 0.0], "lose": [1, 0.5, -1.0],
	"wave": [1, 0.3, -4.0], "dash": [3, 0.08, -10.0], "buy": [2, 0.05, -2.0],
	"chest": [1, 0.3, -2.0], "evolve": [1, 0.5, 0.0], "well": [2, 0.15, -5.0], "implode": [2, 0.1, -3.0],
	"overdrive": [1, 0.3, 0.0], "od_ready": [1, 0.5, -3.0], "mission": [1, 0.3, -2.0],
	"charge": [3, 0.12, -9.0], "laser": [3, 0.08, -5.0], "blink": [3, 0.06, -9.0], "chain": [1, 0.2, -4.0],
	"chain_lost": [1, 0.3, -4.0], "slash": [3, 0.06, -9.0], "mine": [2, 0.1, -14.0], "relic": [1, 0.5, -2.0],
	"halo": [1, 0.2, -3.0], "banish": [1, 0.15, -2.0], "ascend": [1, 0.5, -2.0],
	"rift": [1, 0.5, -3.0], "wisp": [2, 0.15, -5.0], "trial": [1, 0.5, -2.0], "rift_done": [1, 0.5, -2.0],
	"glaive": [3, 0.07, -10.0], "ricochet": [4, 0.04, -12.0], "meteor": [3, 0.07, -3.0],
	"meteor_fall": [2, 0.12, -11.0], "starfall": [1, 0.5, -2.0],
	"levi_roar": [1, 0.5, -1.0], "lunge": [2, 0.2, -3.0], "shed": [3, 0.06, -4.0], "coil": [1, 0.5, -5.0],
}

var _pools := {}
var _next := {}
var _last := {}
var _menu: AudioStreamPlayer
var _run: AudioStreamPlayer
var _drive: AudioStreamPlayer
var _intensity := 0.0
var _mode := ""


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
		for i in int(SOUNDS[n][0]):
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "SFX"
			add_child(p)
			pool.append(p)
		_pools[n] = pool
		_next[n] = 0
		_last[n] = -1.0
	_menu = _music_player("music_menu")
	_run = _music_player("music_run")
	_drive = _music_player("music_drive")
	apply_settings()


func _music_player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	var path := "res://assets/audio/%s.ogg" % n
	if ResourceLoader.exists(path):
		var m: AudioStream = load(path)
		if m is AudioStreamOggVorbis:
			m.loop = true
		p.stream = m
	add_child(p)
	return p


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not Save.setting("sound"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Save.setting("music"))


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _pools.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last[sound]) < float(SOUNDS[sound][1]):
		return
	_last[sound] = now
	var pool: Array = _pools[sound]
	var p: AudioStreamPlayer = pool[_next[sound]]
	_next[sound] = (_next[sound] + 1) % pool.size()
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = float(SOUNDS[sound][2]) + volume_db
	p.play()


## Short vibration on phones (if enabled).
func buzz(ms: int) -> void:
	if Save.setting("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## "menu" or "run". Crossfades between the two music beds.
func music(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	if mode == "run":
		_fade(_menu, -80.0, 0.8)
		_run.play(0.0)
		_drive.play(0.0)
		_run.volume_db = -30.0
		_fade(_run, -6.0, 1.2)
		_drive.volume_db = -80.0
		_intensity = 0.0
	else:
		_fade(_run, -80.0, 0.8)
		_fade(_drive, -80.0, 0.8)
		if not _menu.playing:
			_menu.play()
		_menu.volume_db = -30.0
		_fade(_menu, -8.0, 1.5)


## 0..1: how hard the run's drive layer (drums/arps) plays.
func set_intensity(v: float) -> void:
	_intensity = clampf(v, 0.0, 1.0)


func duck(on: bool) -> void:
	var target := -14.0 if on else -6.0
	if _mode == "run":
		_fade(_run, target, 0.3)


func _process(delta: float) -> void:
	if _mode == "run" and _drive.playing:
		var target := lerpf(-40.0, -5.0, sqrt(_intensity))
		_drive.volume_db = lerpf(_drive.volume_db, target, clampf(delta * 1.5, 0.0, 1.0))
		# Keep the layers locked together.
		if absf(_drive.get_playback_position() - _run.get_playback_position()) > 0.08:
			_drive.seek(_run.get_playback_position())


func _fade(p: AudioStreamPlayer, db: float, t: float) -> void:
	if p.stream == null:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, t)
	if db <= -79.0:
		tw.tween_callback(p.stop)
