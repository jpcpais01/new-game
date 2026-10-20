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
signal chest_opened(rewards: Array, big: bool)
signal overdrive_ready
signal chain_milestone(count: int, title: String)
signal chain_lost(count: int)
signal relic_taken(id: String)
## A moment worth a one-time coach tip: elite, boss, laser, chain, low_hp, rift.
signal coach(key: String)
## The Gauntlet: a boss was passed (felled or escaped) after `ticks`, or the
## first cycle was cleared at run tick `ticks` (stage 4), or a new cycle began.
signal gauntlet_split(stage: int, ticks: int, felled: bool)
signal gauntlet_cleared(ticks: int)
signal gauntlet_cycle(cycle: int)
signal resonance_formed(id: String)

const TICK := 1.0 / 60.0

var sim: Sim
var demo := false
var paused := false
var input_vec := Vector2.ZERO
## Set by the HUD button; consumed by the next simulation step.
var burst_request := false
var ship_color := Color(0.35, 0.95, 1.0)
var alpha := 1.0
var vtime := 0.0
var ship_angle := -PI * 0.5
var ship_bank := 0.0
var hp_ghost := 1.0
var bg_mat: ShaderMaterial
var post_rect: ColorRect

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
var _night := 0.0
var _sun_heat := 0.0
var _gold := 0.0
var _slash_spin := 1.0
## 1 -> 0 over the opening second of a run: the ship warps in on a pillar of light.
var warp := 0.0
var _aberr := 0.0
var _zoom := 0.0
## The ship's light trail: recent positions [Vector2], their times, and the
## style its mastery has earned (Defs.TRAILS).
var trail_pts := PackedVector2Array()
var _trail_t := PackedFloat32Array()
var trail_tier := 0


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
	burst_request = false
	ship_color = Defs.ship(sim.ship_id).color
	trail_tier = Defs.trail_tier(Save.ship_radiance(sim.ship_id))
	trail_pts.clear()
	_trail_t.clear()
	_acc = 0.0
	_slow = 1.0
	_hitstop = 0.0
	_end_timer = -1.0
	hp_ghost = 1.0
	_night = 1.0 if sim.endless else 0.0
	_gold = 1.0 if sim.gauntlet else 0.0
	fx.clear()
	_waves.clear()
	_cam_pos = Vector2(sim.px, sim.py)
	camera.position = _cam_pos
	warp = 0.0
	if not is_demo:
		warp_in()


## The run opens with the ship dropping in on a beam of light.
func warp_in() -> void:
	warp = 1.0
	var col := ship_color
	var t := create_tween()
	t.tween_interval(0.45)
	t.tween_callback(func():
		for k in 3:
			fx.ring(sim.px, sim.py, 20.0, 360.0 + 240.0 * k, 0.55 + 0.2 * k, col, 1.6)
		fx.burst(sim.px, sim.py, col * 2.0, 60, 900.0, 1.3, 0.7)
		fx.flash(sim.px, sim.py, 420.0, 0.5, col)
		add_wave(sim.px, sim.py, 2.2, 1100.0)
		shake(0.35)
		Sfx.play("blink", 0.6)
		Sfx.buzz(40))


## The run flies on past the dawn: the light inverts into the Afterdark.
func night_fall() -> void:
	for k in 4:
		fx.ring(sim.px, sim.py, 30.0, 700.0 + 300.0 * k, 0.8 + 0.3 * k, Color(1.0, 0.3, 0.7), 1.8)
	fx.burst(sim.px, sim.py, Color(2.0, 0.6, 1.6), 90, 1100.0, 1.6, 1.1)
	add_wave(sim.px, sim.py, 3.0, 800.0)
	_flash = 1.0
	shake(0.7)
	slowmo(0.2, 1.0)
	Sfx.play("od_ready", 0.7)
	Sfx.buzz(200)


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
			var burst := burst_request and sim.od_ready()
			burst_request = false
			if demo:
				var m := Autopilot.move(sim)
				mv = Vector2(m.x, m.y) / 100.0
				burst = Autopilot.burst(sim)
			sim.step(int(round(mv.x * 100.0)), int(round(mv.y * 100.0)), burst)
			_acc -= TICK
			steps += 1
			handle_events()
			if sim.state != Sim.RUNNING or paused:
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
			var tc := Color(ship_color.r, ship_color.g, ship_color.b) * 1.6
			fx.particle(p.x + back.x + randf_range(-4, 4), p.y + back.y + randf_range(-4, 4),
					-cos(ship_angle) * 260.0 + randf_range(-40, 40), -sin(ship_angle) * 260.0 + randf_range(-40, 40),
					0.32, 0.9, tc, 0, 4.0)
	else:
		ship_bank = lerpf(ship_bank, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	# Missile trails.
	for i in sim.bn:
		var kind := sim.b_kind[i]
		if (kind == 1 or kind == 2) and randf() < 0.8:
			var green := kind == 2 or sim.b_pierce[i] > 0
			fx.particle(sim.b_x[i], sim.b_y[i], randf_range(-30, 30), randf_range(-30, 30), 0.35,
					0.8 if kind == 1 else 0.55, Color(0.6, 1.8, 0.7) if green else Color(1.6, 0.8, 0.3), 0, 3.0)
	# Glaives shed sparks as they spin.
	if not paused:
		for i in sim.bn:
			var gk := sim.b_kind[i]
			if gk >= 4 and randf() < 0.6:
				var gold := sim.is_evolved("glaive") and gk != 6
				fx.particle(sim.b_x[i], sim.b_y[i], randf_range(-50, 50), randf_range(-50, 50), 0.25, 0.6,
						Color(1.3, 1.5, 0.5) if gold else Color(0.8, 1.5, 0.6), 0, 3.0)
	# Singularities suck light inwards.
	if not paused:
		for w in sim.wells:
			for k in 3:
				var ang := randf() * TAU
				var rr: float = w.r * randf_range(0.6, 1.0)
				var sx: float = w.x + cos(ang) * rr
				var sy: float = w.y + sin(ang) * rr
				var tang := ang + PI * 0.5
				fx.particle(sx, sy, (w.x - sx) * 2.2 + cos(tang) * 220.0, (w.y - sy) * 2.2 + sin(tang) * 220.0, 0.4,
						0.9, Color(0.9, 0.5, 1.8), 1, 0.5)
	# Event Horizon blades leave violet trails.
	if not paused and sim.is_evolved("orbit") and sim.state == Sim.RUNNING:
		var spec := sim.orbit_spec()
		var n: int = spec.n
		var rad := sim.orbit_radius()
		for k in n:
			var ang := Trig.to_rad(sim.orbit_ang + k * Trig.STEPS / n)
			fx.particle(p.x + cos(ang) * rad, p.y + sin(ang) * rad, randf_range(-20, 20), randf_range(-20, 20), 0.3,
					1.1, Color(0.9, 0.5, 1.8), 0, 4.0)
	if not paused and sim.state == Sim.RUNNING:
		_rift_particles(p)
		_sector_particles()
	_update_trail(p)
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
	warp = maxf(0.0, warp - delta * 1.6)
	_flash = maxf(0.0, _flash - delta * 2.5)
	_aberr = maxf(0.0, _aberr - delta * 2.2)
	_zoom = maxf(0.0, _zoom - delta * 2.4)
	_update_post(p)
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
		var bi := sim.boss_index()
		Sfx.set_intensity(clampf(float(sim.en) / 160.0 + (0.6 if bi >= 0 else 0.0), 0.0, 1.0))
		_boss_music(bi)
	fx.update_fx(delta * (_slow if _hitstop <= 0.0 else 0.15))
	_update_bg(delta, p)


## Boss themes: the boss on the field picks the track; its wounds bring in the
## fury layer (from 62% hull down to 42%, or at once when it overloads).
func _boss_music(bi: int) -> void:
	if bi < 0 or sim.state == Sim.DEAD:
		Sfx.boss_theme("", 0.0)
		return
	var frac := sim.e_hp[bi] / maxf(1.0, sim.e_maxhp[bi])
	var fury := clampf((0.62 - frac) / 0.2, 0.0, 1.0)
	if sim.e_t[bi] >= sim.overload_ticks:
		fury = 1.0
	Sfx.boss_theme(BOSS_THEMES.get(sim.e_type[bi], ""), fury)


const BOSS_THEMES := {Defs.LEVIATHAN: "leviathan", Defs.WARDEN: "warden", Defs.SERAPH: "seraph",
		Defs.ECLIPSE: "eclipse"}


## Samples the ship's path for its light trail; Starwake and Prism shed stars.
func _update_trail(p: Vector2) -> void:
	if sim.state == Sim.DEAD:
		trail_pts.clear()
		_trail_t.clear()
		return
	var n := trail_pts.size()
	if n == 0 or trail_pts[n - 1].distance_squared_to(p) > 9.0:
		trail_pts.append(p)
		_trail_t.append(vtime)
	elif n > 0:
		trail_pts[n - 1] = p
	var life := 0.35 if trail_tier == 0 else 0.6
	while _trail_t.size() > 0 and vtime - _trail_t[0] > life:
		trail_pts.remove_at(0)
		_trail_t.remove_at(0)
	if trail_tier >= 2 and not paused and trail_pts.size() > 4 and randf() < 0.5:
		var q := trail_pts[randi() % (trail_pts.size() - 2)]
		var sc := ship_color if trail_tier < 4 else Color.from_hsv(randf(), 0.5, 1.0)
		fx.particle(q.x + randf_range(-8, 8), q.y + randf_range(-8, 8), randf_range(-30, 30), randf_range(-30, 30),
				0.5, 0.7, sc * 1.8, 0, 2.5)


## The impact pass costs a full-screen read, so it only runs while a hit or an
## Overdrive is still ringing (and never behind menus or the title demo).
func _update_post(p: Vector2) -> void:
	if post_rect == null:
		return
	var low := 0.0
	if not demo and sim.state == Sim.RUNNING and sim.hp < sim.max_hp * 0.25:
		low = 0.12 + 0.1 * sin(vtime * 6.0)
	var a := minf(1.0, _aberr + low)
	var on := not demo and not paused and Save.setting("shake") and (a > 0.01 or _zoom > 0.01)
	post_rect.visible = on
	if not on:
		return
	var vs := get_viewport_rect().size
	var sp := get_viewport().get_canvas_transform() * p
	var mat := post_rect.material as ShaderMaterial
	mat.set_shader_parameter("aberr", a)
	mat.set_shader_parameter("zoom", _zoom)
	mat.set_shader_parameter("center", Vector2(sp.x / vs.x, sp.y / vs.y))
	mat.set_shader_parameter("tint", Vector3(ship_color.r, ship_color.g, ship_color.b))
	mat.set_shader_parameter("t", vtime)


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
	_night = move_toward(_night, 1.0 if sim.endless else 0.0, delta * 0.4)
	bg_mat.set_shader_parameter("night", _night)
	_gold = move_toward(_gold, 1.0 if sim.gauntlet else 0.0, delta * 0.5)
	bg_mat.set_shader_parameter("gauntlet", _gold)
	bg_mat.set_shader_parameter("arena_r", Sim.ARENA_R)
	bg_mat.set_shader_parameter("abyss", 1.0 if sim.sector == Defs.SECTOR_ABYSS else 0.0)
	bg_mat.set_shader_parameter("corona", 1.0 if sim.sector == Defs.SECTOR_CORONA else 0.0)
	bg_mat.set_shader_parameter("shard", 1.0 if sim.sector == Defs.SECTOR_SHARD else 0.0)
	var ms := PackedVector4Array()
	for m in sim.maws:
		if ms.size() < 3:
			ms.append(Vector4(lerpf(m.ox, m.x, alpha), lerpf(m.oy, m.y, alpha), _maw_grip(m), 0.0))
	while ms.size() < 3:
		ms.append(Vector4.ZERO)
	bg_mat.set_shader_parameter("maws", ms)
	bg_mat.set_shader_parameter("maw_core", Defs.MAW_CORE)
	bg_mat.set_shader_parameter("sun_r", Defs.SUN_R)
	var heat := sim.flare_warn()
	if not sim.flare.is_empty() and int(sim.flare.t) >= Defs.FLARE_WARN:
		heat = maxf(0.0, 1.0 - float(int(sim.flare.t) - Defs.FLARE_WARN) / 40.0)
	_sun_heat = lerpf(_sun_heat, heat, clampf(delta * 10.0, 0.0, 1.0))
	bg_mat.set_shader_parameter("sun_heat", _sun_heat)


## A black hole's grip as drawn: it swells open, and in its last second it
## shudders before collapsing.
func _maw_grip(m: Dictionary) -> float:
	var g := Sim.maw_strength(m)
	var left := int(m.life) - int(m.t)
	if left < 60:
		g = 1.0 + 0.5 * float(left) / 60.0 + 0.15 * sin(vtime * 50.0)
	return g


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
				_aberr = 1.0
				if loud and sim.hp < sim.max_hp * 0.35 and not sim.mods.has("bloodlight"):
					coach.emit("low_hp")
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
				elif e[1] == "pulse_evo":
					fx.spray(e[2] + cos(ang) * 26.0, e[3] + sin(ang) * 26.0, Color(2.0, 1.5, 0.6), 6, ang, 0.9,
							460.0, 0.8, 0.14)
					if loud:
						Sfx.play("shoot", randf_range(0.8, 0.9))
				elif e[1] == "glaive" or e[1] == "glaive_evo":
					var gc := Color(1.8, 2.0, 0.6) if e[1] == "glaive_evo" else Color(1.0, 2.0, 0.7)
					fx.spray(e[2] + cos(ang) * 24.0, e[3] + sin(ang) * 24.0, gc, 4, ang, 0.8, 420.0, 0.7, 0.14)
					if loud:
						Sfx.play("glaive", randf_range(0.92, 1.1) * (0.85 if e[1] == "glaive_evo" else 1.0))
				elif e[1] == "supernova":
					fx.ring(e[2], e[3], 20.0, 220.0, 0.35, Color(1.0, 0.8, 0.4), 1.4)
					fx.flash(e[2], e[3], 160.0, 0.25, Color(1.0, 0.75, 0.35))
					add_wave(e[2], e[3], 0.8, 1100.0)
					shake(0.08)
					if loud:
						Sfx.play("nova", 1.35)
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
				var storm: bool = e[2]
				fx.arc(pts, Color(1.0, 0.85, 0.4) if storm else Color(0.7, 0.65, 1.0))
				for k in range(1, pts.size()):
					fx.spray(pts[k].x, pts[k].y, Color(1.0, 1.0, 1.8), 4, randf() * TAU, TAU, 320.0, 0.7, 0.2)
				if loud:
					Sfx.play("zap", randf_range(0.9, 1.15))
			Sim.EV_LANCE:
				var a := Vector2(e[1], e[2])
				var b := Vector2(e[3], e[4])
				var hue: float = e[6]
				var bc := Color(1.0, 0.95, 0.55)
				if hue >= 0.0:
					bc = Color.from_hsv(fmod(hue + vtime * 0.4, 1.0), 0.55, 1.0)
				fx.beam(a, b, e[5], bc)
				fx.flash(e[1], e[2], 90.0, 0.2, bc)
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
				if loud:
					coach.emit("boss")
				boss_started.emit(e[1])
				shake(0.4)
				if loud:
					slowmo(0.45, 0.8)
					_zoom = maxf(_zoom, 0.35)
				if loud:
					Sfx.play("alarm")
					Sfx.buzz(120)
					if e[1] == Defs.LEVIATHAN:
						coach.emit("leviathan")
						Sfx.play("levi_roar")
			Sim.EV_BOSS_DOWN:
				var col: Color = Defs.ENEMY_COLOR[e[1]]
				for k in 3:
					fx.ring(e[2], e[3], 40.0, 500.0 + k * 220.0, 0.8 + k * 0.25, col, 1.6)
				fx.flash(e[2], e[3], 520.0, 0.9, col)
				_zoom = 0.8
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
			Sim.EV_CHEST:
				var big: bool = e[2]
				var col := Color(1.0, 0.45, 0.95) if big else Color(1.0, 0.8, 0.35)
				fx.ring(sim.px, sim.py, 20.0, 420.0, 0.6, col, 1.6)
				fx.burst(sim.px, sim.py, col * 1.8, 50, 900.0, 1.4, 0.8)
				add_wave(sim.px, sim.py, 1.6, 1000.0)
				_flash = 0.6
				shake(0.3)
				if loud:
					Sfx.buzz(60)
					chest_opened.emit(e[1], big)
			Sim.EV_EVOLVE:
				var col: Color = Defs.EVOLUTIONS[e[1]].color
				for k in 3:
					fx.ring(sim.px, sim.py, 20.0, 380.0 + 200.0 * k, 0.7 + 0.2 * k, col, 1.8)
				fx.burst(sim.px, sim.py, col * 2.0, 80, 1100.0, 1.6, 1.0)
				add_wave(sim.px, sim.py, 2.5, 900.0)
				_flash = 1.0
				shake(0.6)
			Sim.EV_WELL:
				fx.flash(e[1], e[2], e[3] * 0.6, 0.4, Color(0.6, 0.3, 1.0))
				fx.ring(e[1], e[2], e[3], 20.0, 0.5, Color(0.8, 0.45, 1.0), 1.4)
				add_wave(e[1], e[2], 0.7, 700.0)
				if loud:
					Sfx.play("well", randf_range(0.95, 1.05))
			Sim.EV_IMPLODE:
				fx.flash(e[1], e[2], e[3] * 1.8, 0.45, Color(0.75, 0.4, 1.0))
				fx.ring(e[1], e[2], 20.0, e[3] * 1.3, 0.45, Color(0.85, 0.5, 1.0), 2.0)
				fx.burst(e[1], e[2], Color(1.2, 0.7, 2.0), 40, 900.0, 1.3, 0.6)
				add_wave(e[1], e[2], 2.0, 1000.0)
				shake(0.3)
				if loud:
					Sfx.play("implode", randf_range(0.9, 1.05))
			Sim.EV_PICKUP:
				if e[1] == "chest" or e[1] == "bigchest":
					continue
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
					coach.emit("elite")
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
			Sim.EV_OVERDRIVE:
				_on_overdrive(String(e[1]), e[2], e[3], loud)
			Sim.EV_OD_READY:
				if loud:
					Sfx.play("od_ready")
					Sfx.buzz(25)
					overdrive_ready.emit()
			Sim.EV_NIGHT:
				fx.ring(sim.px, sim.py, 40.0, 1400.0, 1.4, Color(1.0, 0.25, 0.6), 2.0)
				add_wave(sim.px, sim.py, 2.0, 700.0)
				shake(0.5)
			Sim.EV_LASER:
				_on_laser(e, loud)
			Sim.EV_BLINK:
				var col: Color = Defs.ENEMY_COLOR[e[5]]
				var big: bool = e[5] == Defs.SERAPH
				if e[6] == 0:
					fx.ring(e[3], e[4], 140.0 if big else 70.0, 10.0, 0.5, col, 1.2)
					if loud:
						Sfx.play("blink", 0.7 if big else randf_range(1.0, 1.2))
				else:
					fx.burst(e[1], e[2], col * 1.5, 30 if big else 12, 500.0, 1.0, 0.4)
					fx.burst(e[3], e[4], col * 1.8, 50 if big else 16, 700.0 if big else 420.0, 1.2, 0.5)
					fx.ring(e[3], e[4], 10.0, 420.0 if big else 120.0, 0.4, col, 1.6 if big else 1.0)
					fx.arc(PackedVector2Array([Vector2(e[1], e[2]), Vector2(e[3], e[4])]), col, 0.18)
					if big:
						fx.flash(e[3], e[4], 500.0, 0.5, col)
						add_wave(e[3], e[4], 2.0, 1000.0)
						shake(0.45)
					if loud:
						Sfx.play("blink", 0.55 if big else randf_range(0.8, 0.95))
			Sim.EV_CHAIN:
				fx.ring(sim.px, sim.py, 20.0, 300.0 + 0.2 * float(e[1]), 0.5, UiKit.GOLD, 1.4)
				if loud:
					coach.emit("chain")
					Sfx.play("chain", 1.0 + 0.04 * float(Defs.CHAIN_TIERS.find_custom(func(x): return x[0] == e[1])))
					Sfx.buzz(20)
					chain_milestone.emit(e[1], e[2])
			Sim.EV_CHAIN_LOST:
				if loud:
					if int(e[1]) >= 25:
						Sfx.play("chain_lost")
					chain_lost.emit(e[1])
			Sim.EV_SLASH:
				_on_slash(e, loud)
			Sim.EV_MINE:
				fx.ring(e[1], e[2], 6.0, 70.0, 0.25, Color(1.0, 0.5, 0.6), 0.8)
				if loud:
					Sfx.play("mine", randf_range(0.95, 1.08))
			Sim.EV_RELIC:
				var info := Defs.card_info(e[1])
				var col: Color = info.get("color", UiKit.GOLD)
				for k in 3:
					fx.ring(sim.px, sim.py, 20.0, 420.0 + 220.0 * k, 0.7 + 0.2 * k, col, 1.8)
				fx.burst(sim.px, sim.py, col * 2.0, 80, 1100.0, 1.5, 1.0)
				fx.flash(sim.px, sim.py, 600.0, 0.6, col)
				add_wave(sim.px, sim.py, 2.4, 900.0)
				_flash = 0.8
				shake(0.4)
				if loud:
					Sfx.play("relic", 1.0)
					Sfx.buzz(80)
					banner.emit(String(info.get("name", "")).to_upper(), col)
					relic_taken.emit(e[1])
			Sim.EV_HALO:
				var gold := Color(1.0, 0.85, 0.4)
				fx.ring(e[1], e[2], 40.0, 260.0, 0.45, gold, 2.0)
				fx.burst(e[1], e[2], gold * 2.0, 40, 700.0, 1.2, 0.6)
				fx.flash(e[1], e[2], 260.0, 0.35, gold)
				add_wave(e[1], e[2], 1.4, 1000.0)
				shake(0.3)
				if loud:
					Sfx.play("halo")
					Sfx.buzz(50)
			Sim.EV_RIFT:
				_on_rift(e, loud)
			Sim.EV_RICOCHET:
				var rc := Color(1.8, 2.0, 0.6) if e[3] else Color(1.0, 2.0, 0.7)
				fx.spray(e[1], e[2], rc, 5, randf() * TAU, TAU, 480.0, 0.8, 0.18)
				fx.ring(e[1], e[2], 6.0, 46.0, 0.16, rc * 0.6, 0.7)
				if loud:
					Sfx.play("ricochet", randf_range(0.9, 1.25))
			Sim.EV_METEOR:
				_on_meteor(e, loud)
			Sim.EV_LEVI:
				_on_levi(e, loud)
			Sim.EV_GAUNTLET:
				_on_gauntlet(e, loud)
			Sim.EV_MAW:
				_on_maw(e, loud)
			Sim.EV_FLARE:
				_on_flare(e, loud)
			Sim.EV_SHARD:
				_on_shard(e, loud)
			Sim.EV_RESONANCE:
				_on_resonance(e, loud)
			Sim.EV_RESFX:
				_on_resfx(e, loud)
			Sim.EV_AEGIS:
				fx.ring(e[1], e[2], e[3] * 0.6, e[3], 0.22, ship_color, 1.0)
				if randf() < 0.5:
					fx.spray(e[1], e[2], ship_color * 1.6, 6, randf() * TAU, TAU, 420.0, 0.8, 0.25)
	sim.events.clear()


## The Leviathan: coils, rears, lunges, sheds its tail, escapes, and after it
## falls, bursts segment by segment.
## The Gauntlet: a gong as each boss steps in, a chime per split, a fanfare
## and a golden shockwave when all four have fallen.
func _on_gauntlet(e: Array, loud: bool) -> void:
	var phase := int(e[1])
	match phase:
		0:
			for k in 2:
				fx.ring(sim.px, sim.py, 40.0, 900.0 + 300.0 * k, 0.9 + 0.3 * k, Defs.GAUNTLET_COLOR, 1.4)
			add_wave(sim.px, sim.py, 1.6, 700.0)
			if loud:
				Sfx.play("gong")
		1:
			if loud:
				gauntlet_split.emit(int(e[2]), int(e[3]), bool(e[4]))
		2:
			var col := Defs.GAUNTLET_COLOR
			for k in 4:
				fx.ring(sim.px, sim.py, 30.0, 700.0 + 320.0 * k, 0.8 + 0.3 * k, col, 1.9)
			fx.burst(sim.px, sim.py, Color(2.2, 1.6, 0.7), 110, 1200.0, 1.8, 1.2)
			add_wave(sim.px, sim.py, 3.2, 800.0)
			_flash = 1.0
			_zoom = 1.0
			shake(0.8)
			slowmo(0.2, 1.4)
			if loud:
				Sfx.play("gauntlet_clear")
				Sfx.buzz(220)
				gauntlet_cleared.emit(int(e[3]))
		3:
			if loud:
				gauntlet_cycle.emit(int(e[2]) / Defs.GAUNTLET.size())
				Sfx.play("od_ready", 0.8)


func _on_levi(e: Array, loud: bool) -> void:
	var x: float = e[1]
	var y: float = e[2]
	var col: Color = Defs.ENEMY_COLOR[Defs.LEVIATHAN]
	match int(e[3]):
		0:
			fx.ring(x, y, 20.0, 260.0, 0.45, col, 1.4)
			shake(0.15)
			if loud:
				Sfx.play("coil")
		1:
			fx.flash(x, y, 200.0, 0.3, Color(1.0, 0.85, 1.0))
			fx.ring(x, y, 120.0, 30.0, 0.35, Color(1.0, 0.8, 1.0), 1.2)
		2:
			fx.burst(x, y, col * 1.8, 30, 700.0, 1.2, 0.5)
			add_wave(x, y, 1.4, 1100.0)
			shake(0.3)
			if loud:
				Sfx.play("lunge")
				Sfx.buzz(40)
		3:
			var tail := Color(1.0, 0.36, 0.78)
			fx.flash(x, y, 160.0, 0.3, tail)
			fx.ring(x, y, 10.0, 140.0, 0.35, tail, 1.3)
			fx.burst(x, y, tail * 1.8, 22, 600.0, 1.1, 0.5)
			shake(0.15)
			if loud:
				Sfx.play("shed", randf_range(0.9, 1.15))
		4:
			# Escaped: the whole body sinks into the dark in a trail of sparks.
			var n: int = e[4]
			for k in n:
				fx.burst(sim.lv_x[k], sim.lv_y[k], col * 1.4, 6, 300.0, 0.8, 0.6)
			fx.ring(x, y, 20.0, 400.0, 0.6, col, 1.4)
			if loud:
				banner.emit("THE LEVIATHAN ESCAPED", col)
				Sfx.play("levi_roar", 1.25)
		5:
			var k5: int = e[4]
			var f := float(k5) / float(Defs.LEVI_SEGS - 1)
			var c5 := col.lerp(Color(1.0, 0.36, 0.78), f)
			fx.flash(x, y, 150.0, 0.25, c5)
			fx.burst(x, y, c5 * 2.0, 14, 520.0, 1.1, 0.45)
			fx.ring(x, y, 10.0, 110.0, 0.3, c5, 1.2)
			shake(0.06)
			if loud:
				Sfx.play("boom", 0.8 + 0.6 * f)


## Rifts: opened, taken on, completed or closed.
func _on_rift(e: Array, loud: bool) -> void:
	var kind: int = e[1]
	var x: float = e[2]
	var y: float = e[3]
	var phase: int = e[4]
	var info: Dictionary = Defs.RIFTS[kind]
	var col: Color = info.color
	match phase:
		0:
			fx.ring(x, y, 20.0, 380.0, 0.7, col, 1.6)
			fx.burst(x, y, col * 1.8, 40, 700.0, 1.2, 0.8)
			add_wave(x, y, 1.2, 900.0)
			if loud:
				coach.emit("rift")
				banner.emit(String(info.name).to_upper(), col)
				Sfx.play("rift")
		1:
			if kind == Defs.RIFT_TRIAL:
				for k in 3:
					fx.ring(sim.px, sim.py, 20.0, 480.0 + 120.0 * k, 0.5 + 0.15 * k, col, 1.8)
				fx.flash(sim.px, sim.py, 500.0, 0.5, col)
				add_wave(sim.px, sim.py, 2.0, 1000.0)
				shake(0.45)
				if loud:
					banner.emit("UMBRAL TRIAL\nDESTROY %d" % int(sim.rift.goal), col)
					Sfx.play("trial")
					Sfx.buzz(90)
			elif kind == Defs.RIFT_WISP:
				fx.burst(x, y, col * 1.8, 24, 500.0, 1.0, 0.5)
				if loud:
					Sfx.play("wisp", 1.2)
			elif kind == Defs.RIFT_STARFALL:
				for k in 2:
					fx.ring(x, y, Defs.STARFALL_R * 1.6, Defs.STARFALL_R, 0.5 + 0.2 * k, col, 1.6)
				fx.flash(x, y, Defs.STARFALL_R * 1.4, 0.4, col)
				add_wave(x, y, 1.4, 900.0)
				shake(0.25)
				if loud:
					banner.emit("STARFALL\nSTAY IN THE RING", col)
					Sfx.play("starfall")
					Sfx.buzz(60)
			else:
				fx.ring(x, y, 20.0, Defs.BEACON_R, 0.4, col, 1.4)
				if loud:
					Sfx.play("charge", 0.6)
		2:
			for k in 3:
				fx.ring(x, y, 20.0, 360.0 + 200.0 * k, 0.6 + 0.2 * k, col, 1.8)
			fx.burst(x, y, col * 2.0, 70, 1000.0, 1.5, 0.9)
			fx.burst(x, y, Color(2, 2, 2), 30, 600.0, 1.0, 0.6)
			fx.flash(x, y, 520.0, 0.6, col)
			add_wave(x, y, 2.2, 1000.0)
			_flash = 0.5
			_zoom = maxf(_zoom, 0.4)
			shake(0.45)
			slowmo(0.35, 0.4)
			if loud:
				var done := ["BEACON LIT", "WISP CAUGHT", "TRIAL WON", "STARFALL WEATHERED"]
				banner.emit(done[kind], col)
				Sfx.play("rift_done")
				Sfx.buzz(70)
		_:
			fx.ring(x, y, 200.0, 10.0, 0.5, Color(col, 0.6), 1.0)
			if loud:
				if phase == 4:
					var lost := ["BEACON LOST", "WISP ESCAPED", "TRIAL FAILED", "STRUCK BY A STAR"]
					banner.emit(lost[kind], UiKit.RED)
				Sfx.play("blink", 0.5)


## The Abyss: a black hole opens with an inward rush, eats with a streak of
## light, burns you at its core and collapses in a burst of light.
func _on_maw(e: Array, loud: bool) -> void:
	var x: float = e[1]
	var y: float = e[2]
	var violet := Color(0.7, 0.45, 1.0)
	match int(e[3]):
		0:
			fx.ring(x, y, Defs.MAW_PULL, 30.0, 0.9, violet, 1.6)
			fx.ring(x, y, Defs.MAW_PULL * 0.6, 20.0, 0.7, Color(1.0, 0.75, 0.4), 1.2)
			add_wave(x, y, 1.2, 700.0)
			if loud:
				coach.emit("maw")
				banner.emit("A BLACK HOLE OPENS", violet)
				Sfx.play("maw_open")
				Sfx.buzz(40)
		1:
			var m := _nearest_maw(x, y)
			if not m.is_empty():
				var dx: float = float(m.x) - x
				var dy: float = float(m.y) - y
				fx.particle(x, y, dx * 3.0, dy * 3.0, 0.3, 1.0, Color(1.6, 1.1, 2.2), 0, 3.0)
				fx.spray(x, y, Color(1.4, 0.9, 2.0), 3, atan2(dy, dx), 0.6, 300.0, 0.7, 0.25)
			if loud and randf() < 0.5:
				Sfx.play("maw_eat", randf_range(0.85, 1.25))
		2:
			var big := int(e[4]) >= Defs.MAW_SATED
			for k in 4:
				fx.ring(x, y, 20.0, Defs.MAW_BLAST * (1.2 + 0.7 * k), 0.5 + 0.18 * k,
						violet if k % 2 == 0 else Color(1.0, 0.75, 0.4), 1.8)
			fx.burst(x, y, Color(1.8, 1.2, 2.4), 90, 1300.0, 1.5, 0.9)
			fx.burst(x, y, Color(2.2, 1.7, 0.8), 40, 800.0, 1.1, 0.7)
			fx.flash(x, y, 520.0, 0.5, violet)
			add_wave(x, y, 2.6, 1000.0)
			_zoom = maxf(_zoom, 0.35)
			shake(0.45)
			if loud:
				Sfx.play("maw_collapse")
				Sfx.buzz(90)
				if big:
					banner.emit("SATED · %d DEVOURED" % int(e[4]), Color(1.0, 0.8, 0.4))
		3:
			fx.burst(x, y, Color(1.6, 0.8, 2.2), 24, 600.0, 1.0, 0.4)


func _nearest_maw(x: float, y: float) -> Dictionary:
	var best := {}
	var bd := INF
	for m in sim.maws:
		var d := Vector2(float(m.x) - x, float(m.y) - y).length_squared()
		if d < bd:
			bd = d
			best = m
	return best


## Corona: the sun swells, erupts, burns, and a ping when you slip through.
func _on_flare(e: Array, loud: bool) -> void:
	var ember := Color(1.0, 0.5, 0.18)
	match int(e[1]):
		0:
			fx.ring(0.0, 0.0, Defs.SUN_R * 3.0, Defs.SUN_R, 0.8, ember, 1.4)
			if loud:
				coach.emit("flare")
				Sfx.play("flare_warn")
		1:
			for k in 3:
				fx.ring(0.0, 0.0, Defs.SUN_R, Defs.SUN_R * (2.2 + k), 0.4 + 0.12 * k, Color(1.0, 0.75, 0.35), 2.0)
			fx.burst(0.0, 0.0, Color(2.4, 1.3, 0.5), 70, 1200.0, 1.6, 0.8)
			add_wave(0.0, 0.0, 2.4, Defs.FLARE_SPEED * 2.0)
			shake(0.3)
			if loud:
				Sfx.play("flare")
				Sfx.buzz(60)
		2:
			fx.burst(e[2], e[3], Color(2.4, 1.0, 0.3), 36, 700.0, 1.2, 0.5)
			fx.flash(e[2], e[3], 200.0, 0.3, ember)
		4:
			fx.ring(e[2], e[3], 20.0, 140.0, 0.35, Color(0.55, 1.0, 1.0), 1.4)
			fx.spray(e[2], e[3], Color(1.0, 2.0, 2.0), 12, randf() * TAU, TAU, 420.0, 0.8, 0.3)
			if loud:
				Sfx.play("flare_pass", 1.0 + 0.02 * float(mini(sim.flares_passed, 20)))


## The Shardfield: crystals hum as they fill, shatter into prismatic light,
## drink enemy shots and take lasers for you.
func _on_shard(e: Array, loud: bool) -> void:
	var x: float = e[1]
	var y: float = e[2]
	var k := int(e[4])
	var hue: Color = EntityView.SHARD_HUES[k % EntityView.SHARD_HUES.size()] if k >= 0 else Color(0.55, 0.9, 1.0)
	var r: float = float(sim.shards[k].r) if k >= 0 else 60.0
	var near := Vector2(x - sim.px, y - sim.py).length() < 1100.0
	match int(e[3]):
		0:
			fx.ring(x, y, r * 2.8, r, 0.5, hue, 1.4)
			if loud:
				coach.emit("shard")
				if near:
					Sfx.play("shard_charge", randf_range(0.95, 1.06))
		1:
			var a0 := Trig.to_rad(int(e[5]))
			fx.flash(x, y, Defs.SHARD_BLAST * 1.6, 0.4, hue)
			fx.ring(x, y, r, Defs.SHARD_BLAST * 1.15, 0.4, Color(1.6, 1.6, 1.8), 2.2)
			fx.ring(x, y, r * 0.5, Defs.SHARD_BLAST * 1.6, 0.6, hue, 1.6)
			for b in Defs.SHARD_BEAMS:
				var ang := a0 + TAU * float(b) / float(Defs.SHARD_BEAMS)
				var bc := Color.from_hsv(fmod(float(b) / float(Defs.SHARD_BEAMS) + vtime * 0.1, 1.0), 0.45, 1.0)
				var dir := Vector2(cos(ang), sin(ang))
				fx.beam(Vector2(x, y) + dir * r * 0.6, Vector2(x, y) + dir * Defs.SHARD_BEAM_LEN, Defs.SHARD_BEAM_W * 1.6,
						bc * 1.4, 0.34)
				fx.spray(x, y, bc * 1.8, 6, ang, 0.15, 1300.0, 1.0, 0.35)
			# Glass: shards of every colour, flung out and tumbling.
			for j in 34:
				var ang2 := randf() * TAU
				var sp := randf_range(250.0, 950.0)
				var pc := hue.lerp(Color.from_hsv(randf(), 0.4, 1.0), 0.5) * 1.8
				fx.particle(x + cos(ang2) * r * 0.5, y + sin(ang2) * r * 0.5, cos(ang2) * sp, sin(ang2) * sp,
						randf_range(0.4, 0.9), randf_range(0.8, 1.6), pc, 1, 2.6)
			fx.burst(x, y, Color(1.8, 1.8, 2.0), 40, 900.0, 1.2, 0.5)
			add_wave(x, y, 2.2, 1000.0)
			if near:
				shake(0.32)
				_aberr = maxf(_aberr, 0.35)
			if loud and near:
				Sfx.play("shard_break", randf_range(0.92, 1.08))
				Sfx.buzz(45)
		2:
			fx.ring(x, y, 4.0, 34.0, 0.2, hue, 0.8)
			fx.spray(x, y, hue * 1.8, 4, randf() * TAU, TAU, 260.0, 0.6, 0.2)
			if loud and near and randf() < 0.6:
				Sfx.play("shard_ping", randf_range(0.9, 1.35))
		3:
			fx.ring(sim.px, sim.py, 30.0, 110.0, 0.3, Color(0.55, 0.95, 1.0), 1.2)
			if loud:
				coach.emit("cover")
				Sfx.play("shard_ping", 0.7)
		4:
			fx.ring(x, y, r * 2.2, r * 0.8, 0.9, hue, 1.2)
			for j in 14:
				var ang3 := randf() * TAU
				var rr := r * randf_range(1.4, 2.4)
				fx.particle(x + cos(ang3) * rr, y + sin(ang3) * rr, -cos(ang3) * rr * 1.4, -sin(ang3) * rr * 1.4, 0.6, 1.0,
						hue * 1.6, 0, 1.0)
			if loud and near:
				Sfx.play("shard_grow", randf_range(0.95, 1.05))
		5:
			fx.burst(x, y, hue * 1.4, 24, 500.0, 1.0, 0.5)
			fx.ring(x, y, r * 0.4, r * 1.6, 0.4, hue, 1.0)


## Sector ambience: light spiralling into black holes, embers off the sun and
## the flare front.
func _sector_particles() -> void:
	if sim.sector == Defs.SECTOR_ABYSS:
		for m in sim.maws:
			var grip := minf(Sim.maw_strength(m), 1.0)
			for k in 3:
				if randf() > grip:
					continue
				var ang := randf() * TAU
				var rr := Defs.MAW_PULL * randf_range(0.25, 0.9)
				var sx: float = float(m.x) + cos(ang) * rr
				var sy: float = float(m.y) + sin(ang) * rr
				var tang := ang + PI * 0.5
				var c := Color(1.6, 1.1, 0.6) if randf() < 0.35 else Color(1.0, 0.6, 2.0)
				fx.particle(sx, sy, (float(m.x) - sx) * 1.6 + cos(tang) * 260.0, (float(m.y) - sy) * 1.6 + sin(tang) * 260.0,
						0.55, 0.9, c, 1, 0.6)
	elif sim.sector == Defs.SECTOR_CORONA:
		if randf() < 0.7:
			var ang2 := randf() * TAU
			var r0 := Defs.SUN_R * randf_range(0.9, 1.15)
			var sp := randf_range(80.0, 260.0) * (1.0 + 2.0 * _sun_heat)
			fx.particle(cos(ang2) * r0, sin(ang2) * r0, cos(ang2) * sp, sin(ang2) * sp, randf_range(0.6, 1.4), 1.0,
					Color(2.2, 1.0, 0.3), 0, 1.5)
		if not sim.flare.is_empty() and int(sim.flare.t) >= Defs.FLARE_WARN:
			var fr: float = sim.flare.r
			for k in 6:
				var ang3 := randf() * TAU
				if sim.flare_gap(int(ang3 / TAU * float(Trig.STEPS)) & Trig.MASK):
					continue
				var v := randf_range(100.0, 380.0)
				fx.particle(cos(ang3) * fr, sin(ang3) * fr, cos(ang3) * v, sin(ang3) * v, 0.5, 1.2,
						Color(2.4, 1.2, 0.35), 0, 2.0)
	elif sim.sector == Defs.SECTOR_SHARD:
		# Glints rising off charged crystals near you, and sparks where a laser
		# breaks on one.
		for k in sim.shards.size():
			var c: Dictionary = sim.shards[k]
			if int(c.st) >= 2:
				continue
			var cx: float = c.x
			var cy: float = c.y
			if absf(cx - sim.px) > 900.0 or absf(cy - sim.py) > 1300.0:
				continue
			var f := sim.shard_frac(k)
			if randf() < 0.08 + 0.5 * f:
				var ang4 := randf() * TAU
				var r1: float = float(c.r) * randf_range(0.3, 1.0)
				var hue: Color = EntityView.SHARD_HUES[k % EntityView.SHARD_HUES.size()]
				fx.particle(cx + cos(ang4) * r1, cy + sin(ang4) * r1, randf_range(-20, 20), randf_range(-90, -30),
						randf_range(0.6, 1.2), 0.7 + f, hue * (1.4 + f), 0, 0.6)
		for l in sim.lasers():
			if not l[5] or not l[8]:
				continue
			var la := Trig.to_rad(l[2])
			var end := Vector2(l[0], l[1]) + Vector2(cos(la), sin(la)) * float(l[3])
			var col: Color = Defs.ENEMY_COLOR[l[6]]
			fx.spray(end.x, end.y, col * 2.0, 2, la + PI, 1.6, 520.0, 0.8, 0.22)
			if randf() < 0.3:
				fx.flash(end.x, end.y, 60.0, 0.12, Color(0.6, 0.95, 1.0))


## Sparks that make each rift read at a glance.
func _rift_particles(p: Vector2) -> void:
	if sim.rift.is_empty():
		return
	var kind := int(sim.rift.kind)
	var col: Color = Defs.RIFTS[kind].color
	var x: float = sim.rift.x
	var y: float = sim.rift.y
	match kind:
		Defs.RIFT_BEACON:
			if randf() < 0.6:
				var ang := randf() * TAU
				var rr := Defs.BEACON_R * randf_range(0.9, 1.1)
				var sx := x + cos(ang) * rr
				var sy := y + sin(ang) * rr
				var up := 120.0 + 500.0 * sim.rift_frac()
				fx.particle(sx, sy, (x - sx) * 0.8, (y - sy) * 0.8 - up, 0.6, 0.8, col * 1.8, 0, 3.0)
		Defs.RIFT_WISP:
			for k in 2:
				var c := Color.from_hsv(randf(), 0.5, 1.0) * 1.8
				fx.particle(x + randf_range(-10, 10), y + randf_range(-10, 10), randf_range(-60, 60),
						randf_range(-60, 60), 0.5, 1.0, c, 0, 4.0)
		Defs.RIFT_STARFALL:
			# Stardust drifting down through the ring.
			if randf() < 0.7:
				var ang3 := randf() * TAU
				var rr3 := Defs.STARFALL_R * sqrt(randf())
				fx.particle(x + cos(ang3) * rr3, y + sin(ang3) * rr3 - 40.0, randf_range(10, 30), randf_range(60, 140),
						0.7, 0.8, col * (2.0 if sim.rift.on else 1.3), 0, 2.0)
		Defs.RIFT_TRIAL:
			if randf() < 0.8:
				var ang2 := randf() * TAU
				var rr2 := Defs.TRIAL_R * randf_range(1.2, 2.2)
				var sx2 := x + cos(ang2) * rr2
				var sy2 := y + sin(ang2) * rr2
				var tang := ang2 + PI * 0.5
				fx.particle(sx2, sy2, (x - sx2) * 2.0 + cos(tang) * 160.0, (y - sy2) * 2.0 + sin(tang) * 160.0, 0.5,
						0.9, Color(1.2, 0.5, 2.0), 1, 0.5)


## Starfall meteors: a whistle when one is called down, then a crater of
## light where it lands.
func _on_meteor(e: Array, loud: bool) -> void:
	var col: Color = Defs.RIFTS[Defs.RIFT_STARFALL].color
	var r: float = e[3]
	if int(e[4]) == 0:
		if loud:
			Sfx.play("meteor_fall", randf_range(0.9, 1.15))
		return
	fx.flash(e[1], e[2], r * 2.2, 0.35, col)
	fx.ring(e[1], e[2], 10.0, r * 1.25, 0.32, col, 1.6)
	fx.ring(e[1], e[2], r * 0.4, r * 2.0, 0.5, Color(1.0, 0.7, 0.5), 0.8)
	fx.burst(e[1], e[2], col * 1.8, 26, 640.0, 1.1, 0.55)
	fx.burst(e[1], e[2], Color(2.0, 1.6, 1.2), 10, 380.0, 1.4, 0.8)
	add_wave(e[1], e[2], 1.2, 1000.0)
	shake(0.16)
	if loud:
		Sfx.play("meteor", randf_range(0.85, 1.1))
		Sfx.buzz(25)


## Ion Scythe: a crescent of light, alternating its swing. Lunar Reaper
## sweeps the whole circle.
func _on_slash(e: Array, loud: bool) -> void:
	var ang := Trig.to_rad(e[3])
	var r: float = e[4]
	var evo: bool = e[6]
	var col := Color(0.6, 1.0, 0.9) if evo else Color(0.5, 1.0, 0.8)
	if int(e[7]) == 0:
		_slash_spin = -_slash_spin
	if int(e[5]) >= Trig.HALF:
		fx.slash(e[1], e[2], ang, r, PI * 0.5, col, _slash_spin, 0.3)
		fx.slash(e[1], e[2], ang + PI, r, PI * 0.5, col, _slash_spin, 0.3)
		fx.ring(e[1], e[2], r * 0.4, r * 1.05, 0.28, col, 0.9)
		add_wave(e[1], e[2], 0.6, 1000.0)
	else:
		var half := Trig.to_rad(e[5])
		fx.slash(e[1], e[2], ang, r, half, col, _slash_spin)
		for k in 6:
			var a := ang + randf_range(-half, half)
			fx.spray(e[1] + cos(a) * r * 0.9, e[2] + sin(a) * r * 0.9, col * 1.6, 1, a + PI * 0.5 * _slash_spin,
					0.6, 320.0, 0.7, 0.2)
	shake(0.06 if not evo else 0.1)
	if loud:
		Sfx.play("slash", randf_range(0.9, 1.12) * (0.85 if evo else 1.0))


## Lasers: a whine while they charge, then a searing flash along the line.
func _on_laser(e: Array, loud: bool) -> void:
	var col: Color = Defs.ENEMY_COLOR[e[7]]
	var boss: bool = e[7] == Defs.SERAPH
	if e[6] == 0:
		fx.flash(e[1], e[2], 70.0 if not boss else 200.0, 0.4, col)
		if loud:
			coach.emit("laser")
			Sfx.play("charge", randf_range(0.95, 1.05) * (0.75 if boss else 1.0))
		return
	var ang := Trig.to_rad(e[3])
	var a := Vector2(e[1], e[2])
	var b := a + Vector2(cos(ang), sin(ang)) * float(e[4])
	fx.beam(a, b, float(e[5]) * 1.6, col, 0.32)
	fx.flash(e[1], e[2], 140.0 if not boss else 320.0, 0.3, col)
	fx.spray(e[1], e[2], col * 1.6, 10, ang, 0.5, 700.0, 0.9, 0.3)
	shake(0.3 if boss else 0.12)
	if loud:
		Sfx.play("laser", randf_range(0.92, 1.05) * (0.8 if boss else 1.0))


## Every ship's Overdrive opens with the same punch: a flash, a shockwave,
## a beat of slow motion and the ability's name.
func _on_overdrive(id: String, x: float, y: float, loud: bool) -> void:
	var col: Color = Defs.ship(id).color
	_flash = 0.8
	_zoom = 1.0
	_aberr = maxf(_aberr, 0.45)
	for k in 3:
		fx.ring(x, y, 20.0, 420.0 + 260.0 * k, 0.5 + 0.18 * k, col, 1.8)
	fx.burst(x, y, col * 2.0, 70, 1200.0, 1.5, 0.8)
	add_wave(x, y, 2.6, 1300.0)
	shake(0.6)
	slowmo(0.3, 0.35)
	_hitstop = 0.06
	if id == "lumen":
		fx.flash(x, y, 1100.0, 0.6, col)
		fx.ring(x, y, 40.0, 1000.0, 0.45, Color(1.0, 1.0, 1.0), 2.4)
	elif id == "nyx":
		fx.flash(x, y, 900.0, 0.8, Color(0.4, 0.2, 0.9))
	elif id == "echo":
		for k in 4:
			fx.ring(x, y, 60.0 + 40.0 * k, 300.0 + 160.0 * k, 0.35 + 0.12 * k, Color(1.0, 0.85, 0.4), 1.2)
	if loud:
		Sfx.play("overdrive")
		Sfx.buzz(140)
		banner.emit(String(Defs.ship(id).od).to_upper(), col)


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


## Two weapons start to resonate: their colours spiral in from either side of
## the ship and lock together in a bloom of the resonance's own light.
func _on_resonance(e: Array, loud: bool) -> void:
	var info: Dictionary = Defs.RESONANCES[e[1]]
	var col: Color = info.color
	var ca: Color = Defs.WEAPONS[e[2]].color
	var cb: Color = Defs.WEAPONS[e[3]].color
	fx.ring(sim.px, sim.py, 520.0, 30.0, 0.45, ca, 1.6)
	fx.ring(sim.px, sim.py, 600.0, 30.0, 0.5, cb, 1.6)
	for k in 3:
		fx.ring(sim.px, sim.py, 20.0, 360.0 + 180.0 * k, 0.6 + 0.2 * k, col, 1.8)
	fx.burst(sim.px, sim.py, ca * 1.8, 36, 900.0, 1.3, 0.8)
	fx.burst(sim.px, sim.py, cb * 1.8, 36, 900.0, 1.3, 0.8)
	fx.burst(sim.px, sim.py, Color(2, 2, 2), 24, 600.0, 1.0, 0.6)
	fx.flash(sim.px, sim.py, 520.0, 0.6, col)
	add_wave(sim.px, sim.py, 2.2, 900.0)
	_flash = maxf(_flash, 0.6)
	shake(0.35)
	if loud:
		slowmo(0.35, 0.7)
		Sfx.play("resonance")
		Sfx.buzz(60)
		resonance_formed.emit(e[1])


func _on_resfx(e: Array, loud: bool) -> void:
	var info: Dictionary = Defs.RESONANCES[e[1]]
	var col: Color = info.color
	match String(e[1]):
		"refraction":
			var a := Vector2(e[2], e[3])
			var b := Vector2(e[4], e[5])
			fx.beam(a, b, e[6], col * 1.3, 0.2)
			fx.spray(e[2], e[3], col * 1.8, 6, (b - a).angle(), 0.5, 520.0, 0.7, 0.2)
			if loud:
				Sfx.play("lance", randf_range(1.4, 1.6), -7.0)
		"homecoming":
			fx.ring(e[2], e[3], 20.0, e[4], 0.3, col, 1.3)
			fx.flash(e[2], e[3], 90.0, 0.2, col)
			add_wave(e[2], e[3], 0.6, 1100.0)
			if loud:
				Sfx.play("nova", randf_range(1.3, 1.4), -6.0)
		"bladestorm":
			fx.slash(e[2], e[3], Trig.to_rad(e[4]), e[5], Trig.to_rad(e[6]), col, _slash_spin, 0.22)
		"surge":
			var rad := sim.orbit_radius()
			fx.ring(e[2], e[3], rad * 0.7, rad * 1.15, 0.35, col, 1.4)
			fx.burst(e[2], e[3], col * 1.6, 14, 520.0, 0.9, 0.4)
