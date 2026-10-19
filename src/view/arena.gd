class_name Arena
extends Node2D
## Runs a Sim in real time and turns it into a show: steps the fixed 60 Hz
## simulation, interpolates, drives the camera, shake, slow motion, hit-stop,
## the warping background, particles, sound and haptics. Emits signals for the
## HUD. Owns no rules: everything that matters happens inside Sim.

signal leveled_up
signal ended(won: bool)
signal banner(text: String, color: Color)
signal boss_started(type: int)
signal boss_ended(type: int)
signal card_taken(id: String, lvl: int)
signal hurt

const TICK := 1.0 / 60.0

var sim: Sim
var demo := false
var paused := false
var input_vec := Vector2.ZERO
var alpha := 1.0
var vtime := 0.0
var ship_angle := -PI * 0.5
var ship_bank := 0.0
var hp_ghost := 1.0
var bg_mat: ShaderMaterial

var camera: Camera2D
var fx: Fx
var _bodies: EntityView
var _glow: EntityView
var _acc := 0.0
var _slow := 1.0
var _slow_t := 0.0
var _hitstop := 0.0
var _trauma := 0.0
var _waves: Array = []
var _hurt := 0.0
var _flash := 0.0
var _gem_chain := 0
var _gem_t := 0.0
var _numbers_this_frame := 0
var _kill_sounds := 0
var _end_timer := -1.0
var _cam_pos := Vector2.ZERO
var _danger := 0.0


func _ready() -> void:
	Art.ensure()
	_glow = EntityView.new()
	_glow.layer = EntityView.GLOW
	_glow.arena = self
	add_child(_glow)
	_bodies = EntityView.new()
	_bodies.layer = EntityView.BODIES
	_bodies.arena = self
	add_child(_bodies)
	fx = Fx.new()
	add_child(fx)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()


func start(new_sim: Sim, is_demo: bool) -> void:
	sim = new_sim
	demo = is_demo
	paused = false
	_acc = 0.0
	_slow = 1.0
	_hitstop = 0.0
	_end_timer = -1.0
	hp_ghost = 1.0
	fx.clear()
	_waves.clear()
	_cam_pos = Vector2(sim.px, sim.py)
	camera.position = _cam_pos


## Brief slow motion (view only; the simulation is unaffected).
func slowmo(scale: float, seconds: float) -> void:
	_slow = minf(_slow, scale)
	_slow_t = maxf(_slow_t, seconds)


func shake(amount: float) -> void:
	if demo or not Save.setting("shake"):
		amount *= 0.35
	_trauma = minf(1.0, _trauma + amount)


func add_wave(x: float, y: float, strength: float, speed := 900.0) -> void:
	if _waves.size() >= 8:
		_waves.pop_front()
	_waves.append({"x": x, "y": y, "r": 0.0, "s": strength, "v": speed, "t": 0.0})


func _process(delta: float) -> void:
	if sim == null:
		return
	vtime += delta
	_numbers_this_frame = 0
	_kill_sounds = 0
	if _slow_t > 0.0:
		_slow_t -= delta
	else:
		_slow = lerpf(_slow, 1.0, clampf(delta * 6.0, 0.0, 1.0))
	if not paused and sim.state == Sim.RUNNING:
		var dt := delta * _slow
		if _hitstop > 0.0:
			_hitstop -= delta
			dt = 0.0
		_acc += dt
		var steps := 0
		while _acc >= TICK and steps < 5:
			var mv := input_vec
			if demo:
				var m := Autopilot.move(sim)
				mv = Vector2(m.x, m.y) / 100.0
			sim.step(int(round(mv.x * 100.0)), int(round(mv.y * 100.0)))
			_acc -= TICK
			steps += 1
			handle_events()
			if sim.state != Sim.RUNNING:
				_acc = 0.0
				break
		if steps >= 5:
			_acc = 0.0
		alpha = clampf(_acc / TICK, 0.0, 1.0)
	else:
		alpha = 1.0
	if demo and sim.state == Sim.CHOOSING:
		sim.choose(Autopilot.pick(sim))
		handle_events()
	if _end_timer > 0.0:
		_end_timer -= delta
		if _end_timer <= 0.0:
			ended.emit(sim.state == Sim.WON)
	_update_view(delta)


func _update_view(delta: float) -> void:
	var p := Vector2(lerpf(sim.ppx, sim.px, alpha), lerpf(sim.ppy, sim.py, alpha))
	# Ship heading follows movement smoothly; banks while turning.
	var mv := Vector2(sim.mvx, sim.mvy)
	if mv.length() > 0.2:
		var target := mv.angle()
		var diff := wrapf(target - ship_angle, -PI, PI)
		ship_angle += diff * clampf(delta * 14.0, 0.0, 1.0)
		ship_bank = lerpf(ship_bank, clampf(diff, -1.2, 1.2), clampf(delta * 8.0, 0.0, 1.0))
		if randf() < 0.9 and sim.state == Sim.RUNNING:
			var back := Vector2(cos(ship_angle), sin(ship_angle)) * -26.0
			fx.particle(p.x + back.x + randf_range(-4, 4), p.y + back.y + randf_range(-4, 4),
					-cos(ship_angle) * 260.0 + randf_range(-40, 40), -sin(ship_angle) * 260.0 + randf_range(-40, 40),
					0.32, 0.9, Color(0.35, 0.9, 1.6), 0, 4.0)
	else:
		ship_bank = lerpf(ship_bank, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	# Missile trails.
	for i in sim.bn:
		if sim.b_kind[i] == 1 and randf() < 0.8:
			fx.particle(sim.b_x[i], sim.b_y[i], randf_range(-30, 30), randf_range(-30, 30), 0.35, 0.8,
					Color(1.6, 0.8, 0.3), 0, 3.0)
	# Camera: follow with a little look-ahead, plus trauma shake.
	var look := mv * 70.0
	_cam_pos = _cam_pos.lerp(p + look, clampf(delta * 6.0, 0.0, 1.0))
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var sh := _trauma * _trauma
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 34.0 * sh
	camera.rotation = randf_range(-1, 1) * 0.025 * sh
	camera.position = _cam_pos
	hp_ghost = move_toward(hp_ghost, clampf(sim.hp / sim.max_hp, 0.0, 1.0), delta * 0.5)
	if hp_ghost < sim.hp / sim.max_hp:
		hp_ghost = sim.hp / sim.max_hp
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _gem_t > 0.0:
		_gem_t -= delta
	else:
		_gem_chain = 0
	var target_danger := clampf(float(sim.en) / 220.0, 0.0, 1.0) * 0.6
	if sim.boss_index() >= 0:
		target_danger = 0.85
	if sim.hp < sim.max_hp * 0.3 and sim.state == Sim.RUNNING:
		target_danger = maxf(target_danger, 0.7 + 0.3 * sin(vtime * 6.0))
	_danger = lerpf(_danger, target_danger, clampf(delta * 1.5, 0.0, 1.0))
	if not demo:
		Sfx.set_intensity(clampf(float(sim.en) / 160.0 + (0.6 if sim.boss_index() >= 0 else 0.0), 0.0, 1.0))
	fx.update_fx(delta * (_slow if _hitstop <= 0.0 else 0.15))
	_update_bg(delta, p)


func _update_bg(delta: float, p: Vector2) -> void:
	if bg_mat == null:
		return
	var arr := PackedVector4Array()
	var i := _waves.size() - 1
	while i >= 0:
		var w: Dictionary = _waves[i]
		w.t += delta
		w.r += w.v * delta
		if w.t > 0.9:
			_waves.remove_at(i)
		i -= 1
	for w in _waves:
		arr.append(Vector4(w.x, w.y, w.r, w.s * (1.0 - w.t / 0.9)))
	while arr.size() < 8:
		arr.append(Vector4.ZERO)
	var vs := get_viewport_rect().size
	bg_mat.set_shader_parameter("cam", camera.get_screen_center_position())
	bg_mat.set_shader_parameter("view_size", vs)
	bg_mat.set_shader_parameter("waves", arr)
	bg_mat.set_shader_parameter("player", p)
	bg_mat.set_shader_parameter("danger", _danger)
	bg_mat.set_shader_parameter("hurt", _hurt)
	bg_mat.set_shader_parameter("flash", _flash)
	bg_mat.set_shader_parameter("t", vtime)
	bg_mat.set_shader_parameter("arena_r", Sim.ARENA_R)


# --- events -----------------------------------------------------------------------

func handle_events() -> void:
	var loud := not demo
	for e in sim.events:
		match int(e[0]):
			Sim.EV_HIT:
				var col: Color = Defs.ENEMY_COLOR[e[5]]
				fx.spray(e[1], e[2], col * 1.4, 2, randf() * TAU, TAU, 260.0, 0.6, 0.18)
				if loud and Save.setting("numbers") and _numbers_this_frame < 10:
					_numbers_this_frame += 1
					fx.number(e[1], e[2], e[3], e[4])
				if loud:
					Sfx.play("hit", randf_range(0.9, 1.2))
			Sim.EV_KILL:
				_on_kill(e, loud)
			Sim.EV_GEM:
				if loud:
					_gem_chain = mini(_gem_chain + 1, 36)
					_gem_t = 0.5
					Sfx.play("gem", 1.0 + 0.035 * _gem_chain)
				fx.flash(e[1], e[2], 40.0, 0.18, Color(0.5, 1.0, 1.0))
			Sim.EV_HURT:
				_hurt = 1.0
				shake(0.55)
				add_wave(sim.px, sim.py, 1.0, 1100.0)
				fx.ring(sim.px, sim.py, 20.0, 170.0, 0.35, Color(1.0, 0.3, 0.35), 1.2)
				fx.burst(sim.px, sim.py, Color(1.6, 0.4, 0.5), 14, 420.0, 1.0, 0.4)
				if loud:
					Sfx.play("hurt", randf_range(0.95, 1.05))
					Sfx.buzz(70)
					_hitstop = 0.05
					hurt.emit()
			Sim.EV_LEVEL:
				fx.ring(sim.px, sim.py, 20.0, 340.0, 0.6, Color(1.0, 0.85, 0.4), 1.4)
				fx.burst(sim.px, sim.py, Color(1.8, 1.5, 0.6), 30, 600.0, 1.2, 0.7)
				add_wave(sim.px, sim.py, 1.3, 1200.0)
				if loud:
					Sfx.play("levelup")
					Sfx.buzz(30)
					leveled_up.emit()
			Sim.EV_SHOT:
				var ang := Trig.to_rad(e[4])
				if e[1] == "pulse":
					fx.spray(e[2] + cos(ang) * 26.0, e[3] + sin(ang) * 26.0, Color(0.5, 1.6, 2.0), 3, ang, 0.7,
							380.0, 0.6, 0.12)
					if loud:
						Sfx.play("shoot", randf_range(0.95, 1.08))
				else:
					if loud:
						Sfx.play("missile", randf_range(0.9, 1.1))
			Sim.EV_NOVA:
				fx.ring(e[1], e[2], 30.0, e[3], 0.32, Color(1.0, 0.45, 0.9), 1.6)
				fx.ring(e[1], e[2], 10.0, e[3] * 0.7, 0.4, Color(0.6, 0.8, 1.0), 0.8)
				fx.flash(e[1], e[2], 140.0, 0.25, Color(1.0, 0.5, 0.9))
				add_wave(e[1], e[2], 1.5, 1000.0)
				shake(0.12)
				if loud:
					Sfx.play("nova", randf_range(0.95, 1.05))
			Sim.EV_ARC:
				var pts: PackedVector2Array = e[1]
				fx.arc(pts, Color(0.7, 0.65, 1.0))
				for k in range(1, pts.size()):
					fx.spray(pts[k].x, pts[k].y, Color(1.0, 1.0, 1.8), 4, randf() * TAU, TAU, 320.0, 0.7, 0.2)
				if loud:
					Sfx.play("zap", randf_range(0.9, 1.15))
			Sim.EV_LANCE:
				var a := Vector2(e[1], e[2])
				var b := Vector2(e[3], e[4])
				fx.beam(a, b, e[5], Color(1.0, 0.95, 0.55))
				fx.flash(e[1], e[2], 90.0, 0.2, Color(1.0, 0.95, 0.6))
				shake(0.1)
				if loud:
					Sfx.play("lance", randf_range(0.95, 1.05))
			Sim.EV_BLAST:
				var hostile: bool = e[4]
				var col := Color(1.0, 0.35, 0.25) if hostile else Color(1.0, 0.7, 0.3)
				fx.flash(e[1], e[2], e[3] * 1.4, 0.3, col)
				fx.ring(e[1], e[2], 10.0, e[3], 0.3, col, 1.2)
				fx.burst(e[1], e[2], col * 1.6, 16, 520.0, 1.1, 0.45)
				add_wave(e[1], e[2], 0.8 if not hostile else 1.4, 900.0)
				shake(0.18 if hostile else 0.06)
				if loud:
					Sfx.play("boom", randf_range(0.85, 1.15))
			Sim.EV_BOSS:
				banner.emit("WARNING", UiKit.RED)
				boss_started.emit(e[1])
				shake(0.4)
				if loud:
					Sfx.play("alarm")
					Sfx.buzz(120)
			Sim.EV_BOSS_DOWN:
				var col: Color = Defs.ENEMY_COLOR[e[1]]
				for k in 3:
					fx.ring(e[2], e[3], 40.0, 500.0 + k * 220.0, 0.8 + k * 0.25, col, 1.6)
				fx.flash(e[2], e[3], 520.0, 0.9, col)
				fx.burst(e[2], e[3], col * 1.8, 90, 1100.0, 1.8, 1.2)
				fx.burst(e[2], e[3], Color(2, 2, 2), 40, 700.0, 1.2, 0.9)
				add_wave(e[2], e[3], 2.5, 900.0)
				_flash = 1.0
				shake(1.0)
				slowmo(0.2, 1.1)
				if loud:
					Sfx.play("boss_down")
					Sfx.buzz(250)
					boss_ended.emit(e[1])
			Sim.EV_PICKUP:
				var col := Color(1.0, 0.4, 0.5) if e[1] == "heart" else (Color(0.4, 0.8, 1.0) if e[1] == "magnet" else Color(1.0, 0.9, 0.4))
				fx.ring(sim.px, sim.py, 10.0, 160.0, 0.4, col, 1.2)
				fx.burst(sim.px, sim.py, col * 1.6, 20, 420.0, 1.0, 0.6)
				if loud:
					Sfx.play("pickup", 1.0 if e[1] != "core" else 1.25)
					var names := {"heart": "+30 HP", "magnet": "MAGNET", "core": "CORE  +1 LEVEL"}
					banner.emit(names.get(e[1], ""), col)
			Sim.EV_REVIVE:
				_flash = 1.0
				fx.ring(sim.px, sim.py, 20.0, 650.0, 0.9, Color(0.5, 1.0, 0.7), 2.0)
				fx.burst(sim.px, sim.py, Color(1.0, 2.0, 1.4), 80, 1000.0, 1.6, 1.0)
				add_wave(sim.px, sim.py, 3.0, 900.0)
				slowmo(0.25, 0.8)
				shake(0.8)
				if loud:
					Sfx.play("revive")
					banner.emit("SECOND LIGHT", UiKit.GREEN)
			Sim.EV_WAVE:
				if loud:
					banner.emit(e[1], UiKit.MAGENTA)
					Sfx.play("wave")
			Sim.EV_ELITE:
				if loud:
					banner.emit("ELITE " + String(Defs.ENEMY[e[1]].name).to_upper(), UiKit.GOLD)
					Sfx.play("wave", 0.8)
			Sim.EV_TELEGRAPH:
				fx.warn(e[1], e[2], Trig.to_rad(e[3]), e[4], 0.55)
				if loud:
					Sfx.play("dash", randf_range(0.9, 1.1))
			Sim.EV_DEAD:
				fx.flash(sim.px, sim.py, 400.0, 1.0, Color(0.4, 0.9, 1.0))
				fx.burst(sim.px, sim.py, Color(0.5, 1.6, 2.0), 120, 1200.0, 1.8, 1.4)
				for k in 3:
					fx.ring(sim.px, sim.py, 20.0, 380.0 + k * 200.0, 0.7 + k * 0.3, Color(0.4, 0.9, 1.0), 1.5)
				add_wave(sim.px, sim.py, 3.0, 800.0)
				shake(1.0)
				slowmo(0.15, 1.5)
				_end_timer = 1.6
				if loud:
					Sfx.play("lose")
					Sfx.buzz(300)
			Sim.EV_WIN:
				_end_timer = 2.4
				slowmo(0.15, 2.0)
				if loud:
					Sfx.play("win")
			Sim.EV_PICK:
				if loud:
					card_taken.emit(e[1], e[2])
	sim.events.clear()


func _on_kill(e: Array, loud: bool) -> void:
	var type: int = e[3]
	var elite: bool = e[4]
	var r: float = e[5]
	var col: Color = Defs.ENEMY_COLOR[type]
	var big := elite or r > 30.0
	fx.burst(e[1], e[2], col * 1.6, int(8 + r * 0.45) * (3 if elite else 1), 300.0 + r * 9.0, 0.9 + r / 60.0, 0.5)
	fx.flash(e[1], e[2], r * 2.6, 0.22, col)
	if big:
		fx.ring(e[1], e[2], r, r * 5.0, 0.4, col, 1.2)
		add_wave(e[1], e[2], 1.0 if elite else 0.5, 900.0)
		shake(0.25 if elite else 0.1)
		if elite:
			_hitstop = 0.07
			slowmo(0.35, 0.35)
		if loud:
			Sfx.play("kill_big", randf_range(0.9, 1.1))
	elif loud and _kill_sounds < 3:
		_kill_sounds += 1
		Sfx.play("kill", randf_range(0.85, 1.25) * (1.25 if r < 15.0 else 1.0))
