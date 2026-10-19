extends Node
## App root: glow environment, the arena floor, the live Arena, the UI layer
## with screen routing and fades, safe-area insets and the Android back button.
## The wall clock is read only here (fresh_seed), never inside the rules.

var arena: Arena
var ui: CanvasLayer
var screen: Control
var _bg: ColorRect
var _fade: ColorRect
var _env: WorldEnvironment


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	Art.ensure()
	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.35)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.environment = env
	add_child(_env)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/view/background.gdshader")
	_bg.material = mat
	bg_layer.add_child(_bg)

	arena = Arena.new()
	arena.bg_mat = mat
	add_child(arena)

	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.01, 0.005, 0.03, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	go_title()


func go_title() -> void:
	Sfx.music("menu")
	_switch(func():
		arena.start(Sim.new(fresh_seed(), {"hull": 5, "power": 3}), true)
		var t := TitleScreen.new()
		t.main = self
		return t)


func start_run() -> void:
	_switch(func():
		var g := GameScreen.new()
		g.main = self
		g.ready.connect(func(): g.begin(fresh_seed()), CONNECT_ONE_SHOT)
		return g)


func go_forge() -> void:
	_switch(func():
		if not arena.demo:
			arena.start(Sim.new(fresh_seed(), {"hull": 5, "power": 3}), true)
		var f := ForgeScreen.new()
		f.main = self
		return f)


func _switch(make: Callable) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.18 if screen else 0.0)
	tw.tween_callback(func():
		_disconnect_arena()
		if screen:
			screen.queue_free()
		screen = make.call()
		screen.theme = UiKit.theme()
		ui.add_child(screen))
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(func(): _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _disconnect_arena() -> void:
	for sig in ["leveled_up", "ended", "banner", "boss_started", "boss_ended", "card_taken", "hurt"]:
		for c in arena.get_signal_connection_list(sig):
			arena.disconnect(sig, c.callable)


## Notch / status-bar insets in viewport units.
func safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return 0.0
	return maxf(0.0, safe.position.y * get_viewport().get_visible_rect().size.y / float(win.y))


## A fresh seed for a run. Entropy comes from here; the run itself is a pure
## function of this number.
func fresh_seed() -> int:
	var t := int(Time.get_unix_time_from_system() * 1000.0)
	return GlowRng.mix32(t & GlowRng.MASK) ^ GlowRng.mix32(Time.get_ticks_usec() & GlowRng.MASK)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen and screen.has_method("on_back"):
			screen.on_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if screen and screen.has_method("on_background"):
			screen.on_background()
