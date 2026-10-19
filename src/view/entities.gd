class_name EntityView
extends Node2D
## Draws the simulation's entities, interpolated between ticks.
## layer BODIES (normal blend): enemies and the ship.
## layer GLOW (additive): gems, shots, orbs, blades, pickups, warp portals.

enum { BODIES, GLOW }

const GEM_TIERS := [
	[3.0, Color(0.35, 0.85, 1.0), 0.8],
	[10.0, Color(0.45, 1.0, 0.55), 1.05],
	[1e9, Color(1.0, 0.45, 1.0), 1.35],
]

var arena: Arena
var layer := BODIES


func _ready() -> void:
	Art.ensure()
	if layer == GLOW:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if arena == null or arena.sim == null:
		return
	if layer == BODIES:
		_draw_enemies()
		_draw_player()
	else:
		_draw_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_enemies() -> void:
	var s := arena.sim
	var a := arena.alpha
	var t := arena.vtime
	var gold := Art.tex("ring")
	for i in s.en:
		if s.e_spawn[i] > 6:
			continue
		var type := s.e_type[i]
		var x := lerpf(s.e_ox[i], s.e_x[i], a)
		var y := lerpf(s.e_oy[i], s.e_y[i], a)
		var r := s.e_r[i]
		var uid := float(s.e_uid[i])
		var rot := 0.0
		match type:
			Defs.DRIFTER:
				rot = t * 1.3 + uid
			Defs.DART, Defs.MITE, Defs.WEAVER:
				rot = Trig.to_rad(s.e_ang[i])
			Defs.SPLITTER:
				rot = t * 0.9 + uid
			Defs.BRUTE:
				rot = t * 0.45 + uid
			Defs.SPITTER:
				rot = t * 2.2 + uid
			Defs.BOMBER:
				rot = t * (9.0 if s.e_state[i] == 1 else 2.5) + uid
			Defs.WARDEN:
				rot = t * 0.35
			Defs.ECLIPSE:
				rot = -t * 0.3
		var sc := r / Art.SPRITE_R * (1.0 + 0.05 * sin(t * 5.0 + uid))
		var mod := Color(1.25, 1.25, 1.25, 1.0)
		if s.e_spawn[i] > 0:
			var k := 1.0 - float(s.e_spawn[i]) / 6.0
			sc *= 0.5 + 0.5 * k
			mod.a = k
		if type == Defs.DART and s.e_state[i] == 1:
			x += randf_range(-3.0, 3.0)
			y += randf_range(-3.0, 3.0)
			mod = Color(2.0, 1.8, 1.2)
		elif type == Defs.BOMBER and s.e_state[i] == 1:
			var blink := 0.5 + 0.5 * sin(t * 40.0)
			sc *= 1.0 + 0.25 * (1.0 - float(s.e_t[i]) / 36.0)
			mod = Color(1.4 + blink, 1.0, 1.0)
		elif type == Defs.SPITTER and s.e_t[i] < 20:
			sc *= 1.0 + 0.012 * float(20 - s.e_t[i])
			mod = Color(1.8, 1.4, 1.9)
		elif type == Defs.ECLIPSE and s.e_state[i] == 1:
			mod = Color(2.0, 1.2, 1.8)
		draw_set_transform(Vector2(x, y), rot, Vector2(sc, sc))
		draw_texture(Art.enemy[type], Vector2(-64, -64), mod)
		var fl := s.e_flash[i]
		if fl > 0:
			draw_texture(Art.enemy_white[type], Vector2(-64, -64), Color(1.6, 1.6, 1.6, float(fl) / 5.0))
		if s.e_elite[i] == 1:
			var rs := (r + 18.0) / 110.0
			draw_set_transform(Vector2(x, y), -t * 1.5, Vector2(rs, rs))
			draw_texture(gold, Vector2(-128, -128), Color(1.6, 1.3, 0.5, 0.75 + 0.25 * sin(t * 6.0)))


func _draw_player() -> void:
	var s := arena.sim
	if s.state == Sim.DEAD:
		return
	var a := arena.alpha
	var x := lerpf(s.ppx, s.px, a)
	var y := lerpf(s.ppy, s.py, a)
	var blink := s.iframes > 0 and int(arena.vtime * 20.0) % 2 == 0
	var rot := arena.ship_angle
	var tilt := 1.0 - 0.18 * absf(sin(arena.ship_bank))
	draw_set_transform(Vector2(x, y), rot, Vector2(0.62, 0.62 * tilt))
	draw_texture(Art.tex("ship"), Vector2(-64, -64), Color(1.5, 1.5, 1.5, 0.35 if blink else 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Health bar under the ship.
	var frac := clampf(s.hp / s.max_hp, 0.0, 1.0)
	var w := 76.0
	var by := y + 44.0
	draw_rect(Rect2(x - w * 0.5 - 3, by - 3, w + 6, 14), Color(0.02, 0.01, 0.05, 0.75))
	var hc := UiKit.GREEN.lerp(UiKit.RED, 1.0 - frac) if frac < 0.5 else UiKit.GREEN
	draw_rect(Rect2(x - w * 0.5, by, w * frac, 8), hc * Color(1.3, 1.3, 1.3))
	if arena.hp_ghost > frac:
		draw_rect(Rect2(x - w * 0.5 + w * frac, by, w * (arena.hp_ghost - frac), 8), Color(1, 1, 1, 0.8))


func _draw_glow() -> void:
	var s := arena.sim
	var a := arena.alpha
	var t := arena.vtime
	# Warp-in portals.
	var portal := Art.tex("portal")
	for i in s.en:
		var sp := s.e_spawn[i]
		if sp <= 0:
			continue
		var r := s.e_r[i]
		var k := clampf(float(sp) / 40.0, 0.0, 1.0)
		var sc := (r * 1.6 + 30.0 * k) / 52.0
		var col: Color = Defs.ENEMY_COLOR[s.e_type[i]]
		draw_set_transform(Vector2(s.e_x[i], s.e_y[i]), t * 3.0 + float(i), Vector2(sc, sc))
		draw_texture(portal, Vector2(-64, -64), Color(col * 1.6, (1.0 - k) * 0.9 + 0.1))
	# Gems.
	var gem := Art.tex("gem")
	for i in s.gn:
		var v := s.g_val[i]
		var tier: Array = GEM_TIERS[0]
		for tr in GEM_TIERS:
			if v < tr[0]:
				tier = tr
				break
		var x := lerpf(s.g_ox[i], s.g_x[i], a)
		var y := lerpf(s.g_oy[i], s.g_y[i], a)
		var sc: float = tier[2] * (1.0 + 0.1 * sin(t * 6.0 + float(i)))
		draw_set_transform(Vector2(x, y), 0.0, Vector2(sc, sc))
		var c: Color = tier[1]
		draw_texture(gem, Vector2(-24, -24), c * 1.5)
	# Pickups.
	for p in s.pickups:
		var tex := Art.tex("p_" + String(p.k))
		var pulse := 1.0 + 0.12 * sin(t * 7.0)
		draw_set_transform(Vector2(p.x, p.y), sin(t * 2.0) * 0.2, Vector2(pulse, pulse) * 0.75)
		draw_texture(Art.tex("glow"), Vector2(-64, -64), Color(1, 1, 1, 0.25))
		draw_texture(tex, Vector2(-48, -48), Color(1.5, 1.5, 1.5))
	# Enemy orbs.
	var orb := Art.tex("orb")
	var core := Art.tex("orb_core")
	for i in s.qn:
		var x := lerpf(s.q_ox[i], s.q_x[i], a)
		var y := lerpf(s.q_oy[i], s.q_y[i], a)
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.15, 1.15))
		draw_texture(orb, Vector2(-24, -24), Color(1.8, 0.35, 0.6))
		draw_texture(core, Vector2(-24, -24), Color(2.0, 1.6, 1.8))
	# Player shots.
	var bolt := Art.tex("bolt")
	var missile := Art.tex("missile")
	for i in s.bn:
		var x := lerpf(s.b_ox[i], s.b_x[i], a)
		var y := lerpf(s.b_oy[i], s.b_y[i], a)
		var ang := atan2(s.b_vy[i], s.b_vx[i])
		if s.b_kind[i] == 0:
			var sc := s.b_r[i] / 9.0
			draw_set_transform(Vector2(x, y), ang, Vector2(sc * 1.1, sc))
			draw_texture(bolt, Vector2(-44, -12), Color(0.6, 1.9, 2.2))
		else:
			draw_set_transform(Vector2(x, y), ang, Vector2(1.1, 1.1))
			draw_texture(missile, Vector2(-32, -32), Color(2.0, 1.5, 0.8))
	# Orbit blades.
	var spec := s.orbit_spec()
	if not spec.is_empty():
		var blade := Art.tex("blade")
		var n: int = spec.n
		var rad: float = spec.r * s.st_area
		var px := lerpf(s.ppx, s.px, a)
		var py := lerpf(s.ppy, s.py, a)
		var base := float(s.orbit_ang) + float(spec.spin) * a
		for k in n:
			var ang := Trig.to_rad(int(base) + k * Trig.STEPS / n) + (base - floorf(base)) * TAU / Trig.STEPS
			var bx := px + cos(ang) * rad
			var by := py + sin(ang) * rad
			draw_set_transform(Vector2(bx, by), ang + PI * 0.5, Vector2(0.85, 0.85) * sqrt(s.st_area))
			draw_texture(blade, Vector2(-48, -48), Color(1.3, 2.0, 2.0))
		# Faint orbit path.
		draw_set_transform(Vector2(px, py), 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 64, Color(0.4, 1.0, 1.0, 0.08), 3.0)
	# Ship core glow.
	if s.state != Sim.DEAD:
		var x := lerpf(s.ppx, s.px, a)
		var y := lerpf(s.ppy, s.py, a)
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.3, 1.3))
		draw_texture(Art.tex("glow"), Vector2(-64, -64), Color(0.3, 0.8, 1.0, 0.35))
