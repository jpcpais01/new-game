extends Control
## Root of the app: the living background, screen routing, fades, the
## Android back button, safe-area insets and the (UI-side) date and seed.
## Wall-clock time is only read here, never inside the game rules.

var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _screen: Control
var _fade: ColorRect


func _ready() -> void:
	theme = UiKit.theme()
	get_tree().set_auto_accept_quit(false)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = load("res://src/view/background.gdshader")
	_bg.material = _bg_mat
	add_child(_bg)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.01, 0.05, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	set_bg_aspect(size)
	resized.connect(func(): set_bg_aspect(size))
	go_title()
	Sfx.start_music()


func go_title() -> void:
	Sfx.duck_music(false)
	_switch(func():
		var t := TitleScreen.new()
		t.main = self
		return t)


func start_game(mode: String, resume: bool) -> void:
	Sfx.duck_music(false)
	_switch(func():
		var g := GameScreen.new()
		g.main = self
		g.ready.connect(func(): g.start(mode, resume), CONNECT_ONE_SHOT)
		return g)


func restart_game(mode: String, abandon := false) -> void:
	if abandon:
		# Abandoned runs still count towards stats.
		if _screen is GameScreen and _screen.game != null and _screen.game.moves.size() > 0:
			Save.record_game(_screen.game, _screen.daily_date)
	if mode == "daily":
		Save.data.daily_run = null
	else:
		Save.data.run = null
	Save.save_data()
	start_game(mode, false)


func _switch(make: Callable) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16 if _screen else 0.0)
	tw.tween_callback(func():
		if _screen:
			_screen.queue_free()
		_screen = make.call()
		add_child(_screen)
		move_child(_fade, -1))
	tw.tween_property(_fade, "color:a", 0.0, 0.32)
	tw.tween_callback(func(): _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func set_bg_aspect(vs: Vector2) -> void:
	if _bg_mat and vs.x > 0:
		_bg_mat.set_shader_parameter("aspect", Vector2(1.0, vs.y / vs.x))


func set_bg_mood(energy: float, flash: float) -> void:
	_bg_mat.set_shader_parameter("energy", energy)
	_bg_mat.set_shader_parameter("hue", energy * 0.35)
	_bg_mat.set_shader_parameter("flash", flash)


## Notch / status-bar insets in viewport units.
func safe_insets() -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return out
	var k := get_viewport_rect().size.y / float(win.y)
	out.top = maxf(0.0, safe.position.y * k)
	out.bottom = maxf(0.0, (win.y - safe.end.y) * k)
	return out


## Today's date (UTC) as YYYY-MM-DD. UI-side only: it picks the daily seed.
func today() -> String:
	return Time.get_date_string_from_system(true)


func yesterday() -> String:
	var unix := Time.get_unix_time_from_datetime_string(today() + "T12:00:00") - 86400
	return Time.get_date_string_from_unix_time(unix)


func pretty_date(date: String) -> String:
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var parts := date.split("-")
	if parts.size() != 3:
		return date
	return "%s %d" % [months[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2])]


## A fresh seed for a classic run. Entropy comes from the UI layer; the run
## itself is fully determined by this number.
func fresh_seed() -> int:
	var t := int(Time.get_unix_time_from_system() * 1000.0)
	return PrismRng.mix32(t & PrismRng.MASK32) ^ (PrismRng.mix32(Time.get_ticks_usec() & PrismRng.MASK32) << 16)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _screen and _screen.has_method("on_back"):
			_screen.on_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
