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
			Defs.PHANTOM, Defs.SENTINEL:
				rot = Trig.to_rad(s.e_ang[i])
			Defs.BASTION:
				rot = t * 0.3 + uid
			Defs.WARDEN:
				rot = t * 0.35
			Defs.ECLIPSE:
				rot = -t * 0.3
			Defs.SERAPH:
				rot = t * (1.6 if s.e_state[i] == 2 else 0.5)
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
		elif type == Defs.PHANTOM:
			# Flickers like a bad signal, and fades out before a blink.
			var fade := clampf(float(s.e_t[i]) / 48.0, 0.0, 1.0) if s.e_state[i] == 1 else 1.0
			mod = Color(1.3, 1.5, 1.7, mod.a * (0.55 + 0.35 * fade + 0.1 * sin(t * 23.0 + uid)))
			if s.e_state[i] == 1:
				x += randf_range(-4.0, 4.0) * (1.0 - fade)
				sc *= 0.7 + 0.3 * fade
		elif type == Defs.SENTINEL and s.e_state[i] == 1:
			var kc := 1.0 - float(s.e_t[i]) / 80.0
			mod = Color(1.3 + kc, 1.2 + 0.4 * kc, 1.2, 1.0)
			sc *= 1.0 + 0.1 * kc
		elif type == Defs.SERAPH and s.e_state[i] == 5:
			var c := s.e_t[i] % 600
			var fade2 := clampf(1.0 - float(c - 480) / 60.0, 0.0, 1.0)
			mod = Color(1.5, 2.0, 1.9, 0.25 + 0.75 * fade2)
			sc *= 0.6 + 0.4 * fade2
		if s.freeze > 0:
			# Stopped time: everything turns to cold glass.
			mod = Color(0.55, 0.65, 1.7, mod.a)
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
	draw_texture(Art.tex("ship_" + s.ship_id), Vector2(-64, -64), Color(1.5, 1.5, 1.5, 0.35 if blink else 1.0))
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
	_draw_threats(s, t)
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
	# Singularities: rings collapsing into a violet core.
	var ring := Art.tex("ring")
	var glow := Art.tex("glow")
	for w in s.wells:
		var wr: float = w.r
		var life := clampf(float(w.t) / float(w.get("max", Sim.WELL_TICKS)), 0.0, 1.0)
		var grow := clampf((1.0 - life) * 6.0, 0.0, 1.0)
		for k in 4:
			var ph := fmod(t * 1.8 + k * 0.25, 1.0)
			var rr := wr * (1.0 - ph) * grow
			var sc := rr / 110.0
			draw_set_transform(Vector2(w.x, w.y), t * 2.0 + k, Vector2(sc, sc))
			draw_texture(ring, Vector2(-128, -128), Color(0.8, 0.4, 1.6, ph * 0.7))
		var core_s := (0.9 + 0.5 * (1.0 - life) + 0.1 * sin(t * 30.0)) * grow
		draw_set_transform(Vector2(w.x, w.y), 0.0, Vector2(core_s, core_s))
		draw_texture(glow, Vector2(-64, -64), Color(0.7, 0.3, 1.4, 0.9))
		draw_set_transform(Vector2(w.x, w.y), -t * 6.0, Vector2(core_s, core_s) * 0.35)
		draw_texture(Art.tex("i_nova_evo"), Vector2(-48, -48), Color(1.6, 1.2, 2.0))
	# Pickups. Prism Caches stand under a pillar of light so you can find them.
	for p in s.pickups:
		var kind := String(p.k)
		var tex := Art.tex("p_" + kind)
		var pulse := 1.0 + 0.12 * sin(t * 7.0)
		if kind == "chest" or kind == "bigchest":
			var big := kind == "bigchest"
			var col := Color(1.0, 0.45, 0.95) if big else Color(1.0, 0.8, 0.35)
			draw_set_transform(Vector2(p.x, p.y), -PI * 0.5, Vector2.ONE)
			draw_texture_rect(Art.tex("beam"), Rect2(0, -26, 900, 52), false, Color(col, 0.35 + 0.1 * sin(t * 4.0)))
			var rs := (1.15 if big else 0.85) * (1.0 + 0.06 * sin(t * 5.0))
			draw_set_transform(Vector2(p.x, p.y), t * 1.4, Vector2(rs, rs) * 0.6)
			draw_texture(ring, Vector2(-128, -128), Color(col * 1.4, 0.8))
			draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(rs, rs) * 1.5)
			draw_texture(glow, Vector2(-64, -64), Color(col, 0.35))
			var bob := sin(t * 3.0) * 6.0
			draw_set_transform(Vector2(p.x, p.y + bob), sin(t * 1.5) * 0.15, Vector2(rs, rs) * 1.05)
			draw_texture(tex, Vector2(-48, -48), Color(1.7, 1.7, 1.7))
			continue
		draw_set_transform(Vector2(p.x, p.y), sin(t * 2.0) * 0.2, Vector2(pulse, pulse) * 0.75)
		draw_texture(glow, Vector2(-64, -64), Color(1, 1, 1, 0.25))
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
		match s.b_kind[i]:
			0:
				var sc := s.b_r[i] / 9.0
				draw_set_transform(Vector2(x, y), ang, Vector2(sc * 1.1, sc))
				draw_texture(bolt, Vector2(-44, -12), Color(0.6, 1.9, 2.2))
			3:
				var sc := s.b_r[i] / 9.0
				draw_set_transform(Vector2(x, y), ang, Vector2(sc * 1.25, sc))
				draw_texture(bolt, Vector2(-44, -12), Color(2.4, 1.7, 0.7))
				draw_set_transform(Vector2(x, y), 0.0, Vector2(0.5, 0.5))
				draw_texture(glow, Vector2(-64, -64), Color(1.0, 0.7, 0.3, 0.35))
			1:
				var hydra := s.b_pierce[i] > 0
				draw_set_transform(Vector2(x, y), ang, Vector2(1.25, 1.25) if hydra else Vector2(1.1, 1.1))
				draw_texture(missile, Vector2(-32, -32), Color(0.9, 2.2, 1.0) if hydra else Color(2.0, 1.5, 0.8))
			_:
				draw_set_transform(Vector2(x, y), ang, Vector2(0.75, 0.75))
				draw_texture(missile, Vector2(-32, -32), Color(0.7, 2.0, 0.9))
	# Orbit blades.
	var spec := s.orbit_spec()
	if not spec.is_empty():
		var blade := Art.tex("blade")
		var n: int = spec.n
		var rad := s.orbit_radius()
		var evo: bool = spec.get("evo", false)
		var bcol := Color(1.7, 1.0, 2.6) if evo else Color(1.3, 2.0, 2.0)
		var bsc := 1.15 if evo else 0.85
		var px := lerpf(s.ppx, s.px, a)
		var py := lerpf(s.ppy, s.py, a)
		var base := float(s.orbit_ang) + float(spec.spin) * a
		for k in n:
			var ang := Trig.to_rad(int(base) + k * Trig.STEPS / n) + (base - floorf(base)) * TAU / Trig.STEPS
			var bx := px + cos(ang) * rad
			var by := py + sin(ang) * rad
			draw_set_transform(Vector2(bx, by), ang + PI * 0.5, Vector2(bsc, bsc) * sqrt(s.st_area))
			draw_texture(blade, Vector2(-48, -48), bcol)
		# Faint orbit path (a swirling accretion disc once evolved).
		draw_set_transform(Vector2(px, py), 0.0, Vector2.ONE)
		if evo:
			for k in 3:
				var rr := rad * (0.82 + 0.09 * k)
				var a0 := -t * (2.0 + k) + k
				draw_arc(Vector2.ZERO, rr, a0, a0 + PI * 1.2, 40, Color(0.7, 0.4, 1.0, 0.16), 6.0 - k)
		else:
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 64, Color(0.4, 1.0, 1.0, 0.08), 3.0)
	# Ship core glow, the Aegis shield and the Overdrive-ready halo.
	if s.state != Sim.DEAD:
		var x := lerpf(s.ppx, s.px, a)
		var y := lerpf(s.ppy, s.py, a)
		var sc := arena.ship_color
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.3, 1.3))
		draw_texture(Art.tex("glow"), Vector2(-64, -64), Color(sc.r * 0.85, sc.g * 0.85, sc.b * 0.85, 0.35))
		if s.shield > 0:
			var fade := clampf(float(s.shield) / 30.0, 0.0, 1.0)
			var rs := 210.0 * s.st_area / 110.0 * (1.0 + 0.04 * sin(t * 18.0))
			draw_set_transform(Vector2(x, y), t * 2.0, Vector2(rs, rs))
			draw_texture(ring, Vector2(-128, -128), Color(sc * 1.6, 0.85 * fade))
			draw_set_transform(Vector2(x, y), -t * 3.0, Vector2(rs, rs) * 1.95)
			draw_texture(Art.tex("portal"), Vector2(-64, -64), Color(sc * 1.4, 0.5 * fade))
			draw_set_transform(Vector2(x, y), 0.0, Vector2(rs, rs) * 1.7)
			draw_texture(glow, Vector2(-64, -64), Color(sc, 0.18 * fade))
		elif s.od_ready():
			var k := 0.5 + 0.5 * sin(t * 6.0)
			draw_set_transform(Vector2(x, y), t * 1.5, Vector2(0.55, 0.55) * (1.0 + 0.08 * k))
			draw_texture(ring, Vector2(-128, -128), Color(sc * 1.5, 0.35 + 0.35 * k))


## Bastion aegis, blink markers and lasers (warning lines, then beams).
func _draw_threats(s: Sim, t: float) -> void:
	var ring := Art.tex("ring")
	var portal := Art.tex("portal")
	var glow := Art.tex("glow")
	var frozen := s.freeze > 0
	var blue: Color = Defs.ENEMY_COLOR[Defs.BASTION]
	for i in s.en:
		var type := s.e_type[i]
		if s.e_spawn[i] > 0:
			continue
		if s.e_shd[i] == 1:
			var rs := s.e_r[i] * 1.45 / 52.0
			draw_set_transform(Vector2(s.e_x[i], s.e_y[i]), t * 0.8, Vector2(rs, rs))
			draw_texture(portal, Vector2(-64, -64), Color(blue * 1.5, 0.45))
		if type == Defs.BASTION:
			var br := Sim.BASTION_R * (1.3 if s.e_elite[i] == 1 else 1.0)
			var pulse := 1.0 + 0.03 * sin(t * 4.0 + float(i))
			draw_set_transform(Vector2(s.e_x[i], s.e_y[i]), -t * 0.4, Vector2.ONE * br / 110.0 * pulse)
			draw_texture(ring, Vector2(-128, -128), Color(blue * 1.3, 0.35))
			draw_set_transform(Vector2(s.e_x[i], s.e_y[i]), 0.0, Vector2.ONE * br / 64.0)
			draw_texture(glow, Vector2(-64, -64), Color(blue, 0.08))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for j in s.en:
				if s.e_shd[j] != 1:
					continue
				var dx := s.e_x[j] - s.e_x[i]
				var dy := s.e_y[j] - s.e_y[i]
				if dx * dx + dy * dy < br * br:
					draw_line(Vector2(s.e_x[i], s.e_y[i]), Vector2(s.e_x[j], s.e_y[j]), Color(blue * 1.4, 0.18), 2.0)
		elif (type == Defs.PHANTOM and s.e_state[i] == 1) or (type == Defs.SERAPH and s.e_state[i] == 5):
			# Where it will appear: a shrinking ring of light.
			var big := type == Defs.SERAPH
			var col: Color = Defs.ENEMY_COLOR[type]
			var k := 0.0
			if big:
				k = clampf(float(s.e_t[i] % 600 - 480) / 60.0, 0.0, 1.0)
			else:
				k = 1.0 - clampf(float(s.e_t[i]) / 48.0, 0.0, 1.0)
			var rr := (s.e_r[i] * (1.2 + 2.0 * (1.0 - k))) / 110.0
			draw_set_transform(Vector2(s.e_ax[i], s.e_ay[i]), t * 3.0, Vector2(rr, rr))
			draw_texture(ring, Vector2(-128, -128), Color(col * 1.6, 0.25 + 0.6 * k))
			draw_set_transform(Vector2(s.e_ax[i], s.e_ay[i]), -t * 2.0, Vector2(rr, rr) * 1.7)
			draw_texture(portal, Vector2(-64, -64), Color(col * 1.3, 0.2 + 0.5 * k))
	var beam := Art.tex("beam")
	for l in s.lasers():
		var p0 := Vector2(l[0], l[1])
		var ang := Trig.to_rad(l[2])
		var length: float = l[3]
		var hw: float = l[4]
		var live: bool = l[5]
		var kc: float = l[7]
		var col: Color = Defs.ENEMY_COLOR[l[6]]
		if frozen:
			col = Color(0.5, 0.65, 1.6)
		draw_set_transform(p0, ang, Vector2.ONE)
		if live:
			var flick := 0.85 + 0.15 * sin(t * 60.0)
			var w := hw * 2.0 * flick
			draw_texture_rect(beam, Rect2(0, -w * 1.8, length, w * 3.6), false, Color(col * 1.5, 0.75))
			draw_texture_rect(beam, Rect2(0, -w * 0.5, length, w), false, Color(1.8, 1.8, 1.8, 1.0))
			draw_set_transform(p0, 0.0, Vector2.ONE * (hw * 3.0 / 64.0))
			draw_texture(glow, Vector2(-64, -64), Color(col * 1.6, 0.8))
		else:
			# Warning: a thin flickering line that thickens as the charge fills.
			var blink := 0.55 + 0.45 * absf(sin(t * (10.0 + 20.0 * kc)))
			draw_rect(Rect2(0, -hw * kc, length, hw * 2.0 * kc), Color(col, 0.08 + 0.1 * kc))
			draw_line(Vector2.ZERO, Vector2(length, 0), Color(col * 1.4, (0.25 + 0.55 * kc) * blink), 2.0 + 2.0 * kc)
			draw_set_transform(p0, 0.0, Vector2.ONE * (0.3 + 0.5 * kc))
			draw_texture(glow, Vector2(-64, -64), Color(col * 1.5, 0.3 + 0.5 * kc))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
