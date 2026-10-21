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

## Shardfield crystal hues, by crystal index.
const SHARD_HUES := [Color(0.45, 0.92, 1.0), Color(0.72, 0.55, 1.0), Color(1.0, 0.5, 0.8), Color(0.45, 1.0, 0.8)]
const SHARD_LIGHT := Vector2(-0.6, -0.8)

var arena: Arena
var layer := BODIES
var _shard_shapes := {}   # crystal index -> its drawn shape (rebuilt when a new field is placed)


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
	_draw_shards(s, t)
	_draw_levi_body(s, a, t)
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
			Defs.LEVIATHAN:
				rot = Trig.to_rad(s.e_ang[i])
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
		elif type == Defs.LEVIATHAN and s.e_state[i] >= 3:
			# Rearing to lunge: it trembles and burns white; lunging, it stretches.
			if s.e_state[i] == 3:
				x += randf_range(-4.0, 4.0)
				y += randf_range(-4.0, 4.0)
				mod = Color(2.2, 1.9, 2.4)
			else:
				mod = Color(1.8, 1.6, 2.2)
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
		if s.e_tr[i] != 0:
			var ts := s.trait_state(i)
			if int(ts.get("blink", 0)) > 0:
				# Phasing out: it thins to a flicker before it blinks.
				var fk := float(ts.blink) / float(Defs.PHASE_MARK)
				mod = Color(1.3, 1.0, 1.9, mod.a * (0.3 + 0.6 * fk + 0.1 * sin(t * 31.0)))
				x += randf_range(-3.0, 3.0) * (1.0 - fk)
			elif int(ts.get("dash", 0)) == 1:
				mod = Color(2.0, 1.9, 1.1, mod.a)
				x += randf_range(-3.0, 3.0)
				y += randf_range(-3.0, 3.0)
			if s.e_tr[i] & Defs.trait_bit("pulsar"):
				var c := int(ts.get("tt", 0)) % Defs.PULSAR_EVERY
				if c >= Defs.PULSAR_EVERY - Defs.PULSAR_SWELL:
					var sk := float(c - (Defs.PULSAR_EVERY - Defs.PULSAR_SWELL)) / float(Defs.PULSAR_SWELL)
					sc *= 1.0 + 0.18 * sk * sk
					mod = mod.lerp(Color(2.0, 1.0, 1.8, mod.a), sk)
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
	_draw_plates(s, a, t)


## Over every elite (and trait-bearing night boss): its traits as a row of
## icons over a health bar, with the barrier of a Shielded one laid on top.
func _draw_plates(s: Sim, a: float, t: float) -> void:
	for i in s.en:
		if s.e_spawn[i] > 6 or (s.e_elite[i] == 0 and s.e_tr[i] == 0) or s.e_type[i] >= Defs.WARDEN:
			continue
		var x := lerpf(s.e_ox[i], s.e_x[i], a)
		var y := lerpf(s.e_oy[i], s.e_y[i], a)
		var r := s.e_r[i]
		var w := clampf(r * 2.4, 84.0, 140.0)
		var by := y - r - 34.0
		var frac := clampf(s.e_hp[i] / s.e_maxhp[i], 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(x - w * 0.5 - 3, by - 3, w + 6, 14), Color(0.02, 0.01, 0.05, 0.8))
		draw_rect(Rect2(x - w * 0.5, by, w * frac, 8), Color(1.9, 1.5, 0.6))
		var ts := s.trait_state(i)
		if float(ts.get("bmax", 0.0)) > 0.0:
			var bf := clampf(float(ts.bar) / float(ts.bmax), 0.0, 1.0)
			draw_rect(Rect2(x - w * 0.5, by - 7, w * bf, 5), Defs.TRAITS.shielded.color * 1.8)
		var ids := Defs.trait_ids(s.e_tr[i])
		var n := ids.size()
		var isz := 46.0
		var x0 := x - float(n) * isz * 0.5
		for k in n:
			var id: String = ids[k]
			var pulse := 1.0 + 0.08 * sin(t * 5.0 + float(k) * 1.7)
			draw_set_transform(Vector2(x0 + isz * (float(k) + 0.5), by - 32.0), 0.0, Vector2.ONE * (isz / 96.0) * pulse)
			draw_texture(Art.icon("trait_" + id), Vector2(-48, -48), Color(1.5, 1.5, 1.5))


## Trait auras (additive): a Shielded barrier, a Pulsar's swell, a Graviton's
## pull, a Brood's clutch, a Leech's reach, a Starcaller's crown, a Phasing
## mark and the Swift's wake, then every star falling.
func _draw_traits(s: Sim, t: float, a: float) -> void:
	var glow := Art.tex("glow")
	var ring := Art.tex("ring")
	for i in s.en:
		if s.e_tr[i] == 0 or s.e_spawn[i] > 6:
			continue
		var m := s.e_tr[i]
		var ts := s.trait_state(i)
		if ts.is_empty():
			continue
		var x := lerpf(s.e_ox[i], s.e_x[i], a)
		var y := lerpf(s.e_oy[i], s.e_y[i], a)
		var r := s.e_r[i]
		var p := Vector2(x, y)
		var uid := float(s.e_uid[i])
		if m & Defs.trait_bit("shielded"):
			var bf := clampf(float(ts.bar) / maxf(1.0, float(ts.bmax)), 0.0, 1.0)
			if bf > 0.0:
				var col: Color = Defs.TRAITS.shielded.color
				var hr := r * 1.35 + 16.0
				var hit := float(s.e_flash[i]) / 5.0
				var pts := PackedVector2Array()
				for k in 7:
					var ang := t * 0.6 + uid + TAU * float(k) / 6.0
					pts.append(Vector2(cos(ang), sin(ang)) * hr)
				draw_set_transform(p, 0.0, Vector2.ONE)
				var fill := PackedVector2Array(pts)
				fill.remove_at(6)
				draw_colored_polygon(fill, Color(col, (0.06 + 0.1 * hit) * bf))
				draw_polyline(pts, Color(col * (1.4 + 1.2 * hit), 0.35 + 0.55 * bf), 3.0 + 2.0 * hit)
				for k in 6:
					draw_line(pts[k] * 0.55, pts[k], Color(col * 1.4, 0.18 * bf), 1.5)
		if m & Defs.trait_bit("pulsar"):
			var col2: Color = Defs.TRAITS.pulsar.color
			var c := int(ts.tt) % Defs.PULSAR_EVERY
			var start := Defs.PULSAR_EVERY - Defs.PULSAR_SWELL
			if c >= start:
				var sk := float(c - start) / float(Defs.PULSAR_SWELL)
				var rr := lerpf(r * 4.0, r * 1.1, sk)
				draw_set_transform(p, t * 2.0, Vector2.ONE * (rr / 110.0))
				draw_texture(ring, Vector2(-128, -128), Color(col2 * 1.6, 0.25 + 0.6 * sk))
				draw_set_transform(p, 0.0, Vector2.ONE * (r * (2.0 + 1.5 * sk) / 64.0))
				draw_texture(glow, Vector2(-64, -64), Color(col2, 0.25 + 0.45 * sk))
			else:
				draw_set_transform(p, -t, Vector2.ONE * ((r + 26.0) / 110.0))
				draw_texture(ring, Vector2(-128, -128), Color(col2, 0.3))
		if m & Defs.trait_bit("graviton"):
			var col3: Color = Defs.TRAITS.graviton.color
			draw_set_transform(p, 0.0, Vector2.ONE)
			for k in 3:
				var ph := fmod(t * 0.55 + float(k) / 3.0, 1.0)
				var rr2 := lerpf(Defs.GRAVITON_R * 0.75, r + 10.0, ph)
				draw_arc(Vector2.ZERO, rr2, 0.0, TAU, 48, Color(col3 * 1.3, 0.28 * ph), 2.5)
			var segs := 30
			for k in segs:
				var a0 := t * 0.25 + TAU * float(k) / float(segs)
				draw_arc(Vector2.ZERO, Defs.GRAVITON_R, a0, a0 + TAU / float(segs) * 0.45, 4, Color(col3, 0.22), 2.0)
		if m & Defs.trait_bit("brood"):
			var col4: Color = Defs.TRAITS.brood.color
			var c4 := int(ts.tt) % Defs.BROOD_EVERY
			var ripe := clampf(float((c4 - Defs.BROOD_EVERY / 2 + Defs.BROOD_EVERY) % Defs.BROOD_EVERY)
					/ float(Defs.BROOD_EVERY), 0.0, 1.0)
			for k in 3:
				var ang2 := t * 1.6 + uid + TAU * float(k) / 3.0
				var cp := p + Vector2(cos(ang2), sin(ang2)) * (r + 20.0)
				var sz := 6.0 + 5.0 * ripe
				var tri := PackedVector2Array()
				for v in 3:
					var va := ang2 * 2.0 + TAU * float(v) / 3.0
					tri.append(cp + Vector2(cos(va), sin(va)) * sz)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_colored_polygon(tri, Color(col4 * 1.5, 0.55 + 0.4 * ripe))
		if m & Defs.trait_bit("leech"):
			var col5: Color = Defs.TRAITS.leech.color
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + uid)
			draw_set_transform(p, 0.0, Vector2.ONE * (r * 2.6 / 64.0))
			draw_texture(glow, Vector2(-64, -64), Color(col5, 0.18 + 0.15 * pulse))
			draw_set_transform(p, 0.0, Vector2.ONE)
			var segs2 := 40
			for k in segs2:
				var a1 := -t * 0.2 + TAU * float(k) / float(segs2)
				draw_arc(Vector2.ZERO, Defs.LEECH_R, a1, a1 + TAU / float(segs2) * 0.3, 3, Color(col5, 0.14), 2.0)
		if m & Defs.trait_bit("starcaller"):
			var col6: Color = Defs.TRAITS.starcaller.color
			for k in 3:
				var ang3 := -t * 1.2 + TAU * float(k) / 3.0
				var sp := p + Vector2(cos(ang3), sin(ang3)) * (r + 26.0)
				draw_set_transform(sp, t * 3.0, Vector2.ONE * 0.11)
				draw_texture(glow, Vector2(-64, -64), Color(col6 * 2.0, 0.9))
				var star := PackedVector2Array()
				for v2 in 10:
					var va2 := t * 3.0 + TAU * float(v2) / 10.0
					star.append(sp + Vector2(cos(va2), sin(va2)) * (9.0 if v2 % 2 == 0 else 4.0))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_colored_polygon(star, Color(col6 * 1.8, 0.95))
		if m & Defs.trait_bit("swift"):
			var col7: Color = Defs.TRAITS.swift.color
			var v := Vector2(s.e_x[i] - s.e_ox[i], s.e_y[i] - s.e_oy[i])
			if v.length_squared() > 4.0:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var dir := v.normalized()
				var side := Vector2(-dir.y, dir.x)
				var len := minf(160.0, v.length() * 9.0)
				for k in 3:
					var o := side * (float(k) - 1.0) * r * 0.55
					draw_line(p + o - dir * r * 0.6, p + o - dir * (r * 0.6 + len), Color(col7 * 1.5, 0.45), 3.0)
		if m & Defs.trait_bit("phasing") and int(ts.blink) > 0:
			var col8: Color = Defs.TRAITS.phasing.color
			var fk := float(ts.blink) / float(Defs.PHASE_MARK)
			var tp := Vector2(float(ts.bx), float(ts.by))
			draw_set_transform(tp, 0.0, Vector2.ONE)
			draw_circle(Vector2.ZERO, r + 10.0, Color(col8, 0.08 + 0.14 * (1.0 - fk)))
			draw_arc(Vector2.ZERO, (r + 10.0) * (0.4 + 0.9 * fk), 0.0, TAU, 40, Color(col8 * 1.6, 0.8), 3.0)
			draw_arc(Vector2.ZERO, r + 10.0, 0.0, TAU, 40, Color(col8 * 1.3, 0.5), 2.0)
	# Falling stars: a closing mark on the ground and a star streaking down onto it.
	var comet := Art.tex("comet")
	var scol: Color = Defs.TRAITS.starcaller.color
	for st in s.stars:
		var mx: float = st[0]
		var my: float = st[1]
		var left := clampf(float(st[2]) / float(Defs.STAR_FALL), 0.0, 1.0)
		var near := 1.0 - left
		var mr := Defs.STAR_R
		var hot := Color(1.0, 0.4, 0.3) if left < 0.3 else scol
		draw_set_transform(Vector2(mx, my), 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, mr, Color(hot, 0.06 + 0.14 * near))
		draw_arc(Vector2.ZERO, mr, 0.0, TAU, 40, Color(hot * 1.6, 0.4 + 0.5 * near), 2.5)
		draw_arc(Vector2.ZERO, mr * (0.2 + 0.8 * left), 0.0, TAU, 32, Color(hot * 1.9, 0.45 + 0.5 * near), 3.0)
		var cx := mx + 300.0 * left
		var cy := my - 820.0 * left
		draw_set_transform(Vector2(cx, cy), atan2(820.0, -300.0), Vector2.ONE * (0.6 + 0.5 * near))
		draw_texture(comet, Vector2(-224, -32), Color(scol * 1.9, 0.3 + 0.7 * near))
		draw_set_transform(Vector2(cx, cy), t * 4.0, Vector2.ONE * (0.25 + 0.3 * near))
		draw_texture(glow, Vector2(-64, -64), Color(scol * 2.2, 0.9))


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
	# Warp-in: the ship drops out of a pillar of light, big and white-hot.
	var wk := arena.warp * arena.warp
	var ws := 0.62 * (1.0 + 1.6 * wk)
	var wc := Color(1.5 + 2.0 * wk, 1.5 + 2.0 * wk, 1.5 + 2.0 * wk, (0.35 if blink else 1.0) * (1.0 - 0.6 * wk))
	draw_set_transform(Vector2(x, y), rot, Vector2(ws, ws * tilt))
	draw_texture(Art.tex("ship_" + s.ship_id), Vector2(-64, -64), wc)
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
	_draw_traits(s, t, a)
	_draw_sector(s, t, a)
	_draw_levi_glow(s, a, t)
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
	_draw_wake(s, t)
	_draw_mines(s, t)
	_draw_rift(s, t, a)
	# Pickups. Prism Caches stand under a pillar of light so you can find them.
	for p in s.pickups:
		var kind := String(p.k)
		var tex := Art.tex("p_" + kind)
		var pulse := 1.0 + 0.12 * sin(t * 7.0)
		if kind == "chest" or kind == "bigchest":
			var big := kind == "bigchest"
			var col := Color(1.0, 0.45, 0.95) if big else Color(1.0, 0.8, 0.35)
			if p.get("relic", false):
				col = Color(0.75, 0.5, 1.0)
				tex = Art.tex("p_relicchest")
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
			4, 5, 6:
				_draw_glaive(s, i, x, y, t, glow)
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
		if s.surge_t > 0:
			# Halo Surge: the blades blaze magenta-white and swell.
			var sk := minf(1.0, float(s.surge_t) / 20.0)
			bcol = bcol.lerp(Color(2.6, 1.4, 2.8), sk)
			bsc *= 1.0 + 0.3 * sk
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
		if s.surge_t > 0:
			var sa := minf(1.0, float(s.surge_t) / 20.0)
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 72, Color(1.0, 0.55, 1.0, 0.35 * sa), 10.0)
	# Ship core glow, the Aegis shield and the Overdrive-ready halo.
	if s.state != Sim.DEAD:
		var x := lerpf(s.ppx, s.px, a)
		var y := lerpf(s.ppy, s.py, a)
		var sc := arena.ship_color
		if arena.warp <= 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			TrailArt.draw(self, arena.trail_pts, sc, arena.trail_tier, t)
		if arena.warp > 0.0:
			var wk := arena.warp
			draw_set_transform(Vector2(x, y), -PI * 0.5, Vector2.ONE)
			draw_texture_rect(Art.tex("beam"), Rect2(0, -70.0 * wk, 2400, 140.0 * wk), false, Color(sc * 1.8, wk))
			draw_texture_rect(Art.tex("beam"), Rect2(0, -18.0 * wk, 2400, 36.0 * wk), false, Color(2, 2, 2, wk))
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
		# Guardian Halo: a gold crown of light that dims while it recharges.
		var hf := s.halo_frac()
		if hf >= 0.0:
			var gold := Color(1.0, 0.85, 0.4)
			draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
			if hf >= 1.0:
				var k2 := 0.5 + 0.5 * sin(t * 4.0)
				draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 48, Color(gold * 1.6, 0.55 + 0.25 * k2), 3.0)
				draw_arc(Vector2.ZERO, 52.0, 0.0, TAU, 48, Color(gold, 0.18), 8.0)
			else:
				draw_arc(Vector2.ZERO, 46.0, -PI * 0.5, -PI * 0.5 + TAU * hf, 40, Color(gold, 0.3), 2.0)


## The Leviathan's body: hex scales from the tail up to the neck, tinted
## violet to magenta, with a ripple of light running down it.
func _draw_levi_body(s: Sim, a: float, t: float) -> void:
	var n := s.lv_n
	if n <= 0:
		return
	var h := s._levi_head()
	var fade := 1.0
	var hx := s.lv_x[0]
	var hy := s.lv_y[0]
	var st := 0
	if h >= 0:
		hx = lerpf(s.e_ox[h], s.e_x[h], a)
		hy = lerpf(s.e_oy[h], s.e_y[h], a)
		st = s.e_state[h]
		if s.e_spawn[h] > 0:
			fade = 1.0 - clampf(float(s.e_spawn[h]) / 150.0, 0.0, 1.0)
	var first := n - s.lv_pop if h < 0 else 0
	var tex := Art.tex("levi_seg")
	var neck: Color = Defs.ENEMY_COLOR[Defs.LEVIATHAN]
	var tail := Color(1.0, 0.36, 0.78)
	var frozen := s.freeze > 0
	for k in range(n - 1, first - 1, -1):
		var x := lerpf(s.lv_ox[k], s.lv_x[k], a)
		var y := lerpf(s.lv_oy[k], s.lv_y[k], a)
		var ax := hx
		var ay := hy
		if k > 0:
			ax = lerpf(s.lv_ox[k - 1], s.lv_x[k - 1], a)
			ay = lerpf(s.lv_oy[k - 1], s.lv_y[k - 1], a)
		var ang := atan2(ay - y, ax - x)
		var f := float(k) / float(Defs.LEVI_SEGS - 1)
		var wave := 0.5 + 0.5 * sin(t * 7.0 - float(k) * 0.55)
		var col := neck.lerp(tail, f) * (1.05 + 0.35 * wave)
		if st == 1:
			col *= 1.1
		elif st == 3:
			col = col.lerp(Color(1.8, 1.6, 2.0), 0.25)
		if h < 0:
			# The head has fallen: every scale burns white before it bursts.
			col = col.lerp(Color(1.7, 1.6, 2.0), 0.35)
			x += randf_range(-3.0, 3.0)
			y += randf_range(-3.0, 3.0)
		if frozen:
			col = Color(0.55, 0.65, 1.7)
		var sc := Sim.levi_seg_r(k) / 24.0 * 1.2 * (1.0 + 0.06 * wave)
		draw_set_transform(Vector2(x, y), ang, Vector2(sc, sc))
		draw_texture(tex, Vector2(-32, -32), Color(col, fade))


## The Leviathan's spine of light (additive), and while it coils, the ring
## it is closing around you.
func _draw_levi_glow(s: Sim, a: float, t: float) -> void:
	var n := s.lv_n
	if n <= 0:
		return
	var h := s._levi_head()
	if h >= 0 and s.e_spawn[h] > 0:
		return
	var neck: Color = Defs.ENEMY_COLOR[Defs.LEVIATHAN]
	var tail := Color(1.0, 0.36, 0.78)
	var first := n - s.lv_pop if h < 0 else 0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var prev := Vector2(lerpf(s.e_ox[h], s.e_x[h], a), lerpf(s.e_oy[h], s.e_y[h], a)) if h >= 0 else \
			Vector2(s.lv_x[first], s.lv_y[first])
	for k in range(first, n):
		var p := Vector2(lerpf(s.lv_ox[k], s.lv_x[k], a), lerpf(s.lv_oy[k], s.lv_y[k], a))
		var f := float(k) / float(Defs.LEVI_SEGS - 1)
		var col := neck.lerp(tail, f)
		var w := Sim.levi_seg_r(k)
		var pulse := 0.5 + 0.5 * sin(t * 7.0 - float(k) * 0.55)
		draw_line(prev, p, Color(col, 0.1 + 0.08 * pulse), w * 2.2)
		draw_line(prev, p, Color(col * 1.4, 0.4 + 0.25 * pulse), w * 0.3)
		prev = p
	if h >= 0 and s.e_state[h] == 1:
		# The coil closing: a dashed ring at the radius it is tightening to.
		var c := s.e_t[h] % 720
		var k2 := clampf(float(c - 260) / 210.0, 0.0, 1.0)
		var rad := 420.0 - 210.0 * k2
		var px := lerpf(s.ppx, s.px, a)
		var py := lerpf(s.ppy, s.py, a)
		draw_set_transform(Vector2(px, py), 0.0, Vector2.ONE)
		var segs := 24
		for i in segs:
			var a0 := -t * 0.9 + TAU * float(i) / float(segs)
			draw_arc(Vector2.ZERO, rad, a0, a0 + TAU / float(segs) * 0.5, 4, Color(neck * 1.5, 0.22 + 0.2 * k2), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ricochet Glaive: a spinning disc with a short smear of afterimages.
## Ouroboros glaives burn gold-lime and brighten with every ricochet.
func _draw_glaive(s: Sim, i: int, x: float, y: float, t: float, glow: Texture2D) -> void:
	var kind := s.b_kind[i]
	var evo := s.is_evolved("glaive") and kind != 6
	var col := Color(1.35, 1.5, 0.45) if evo else Color(0.9, 1.5, 0.55)
	if kind == 6:
		col = Color(1.1, 1.5, 0.7)
	var spec := s.glaive_spec()
	var heat := 0.0
	if evo and not spec.is_empty():
		heat = clampf((s.b_dmg[i] / float(spec.dmg) - 1.0) / 2.0, 0.0, 1.0)
		col = col.lerp(Color(1.8, 1.5, 0.9), heat)
	var sc := s.b_r[i] / 16.0 * (0.7 if kind == 6 else 1.0)
	var spin := t * (26.0 if kind == 5 else 20.0) + float(i)
	var tex := Art.tex("glaive_evo" if evo else "glaive")
	var vx := s.b_vx[i]
	var vy := s.b_vy[i]
	var sp := sqrt(vx * vx + vy * vy) + 0.001
	for k in range(3, 0, -1):
		var back := float(k) * 0.022
		draw_set_transform(Vector2(x - vx * back, y - vy * back), spin - float(k) * 0.5, Vector2(sc, sc))
		draw_texture(tex, Vector2(-32, -32), Color(col, 0.09 * float(4 - k)))
	draw_set_transform(Vector2(x, y), 0.0, Vector2(sc, sc) * (0.5 + 0.2 * heat))
	draw_texture(glow, Vector2(-64, -64), Color(col * 0.5, 0.16 + 0.14 * heat))
	draw_set_transform(Vector2(x, y), spin, Vector2(sc, sc))
	draw_texture(tex, Vector2(-32, -32), col)
	if kind == 5 and sp > 900.0:
		# Flying home: a thin streak back towards the ship.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(Vector2(x, y), Vector2(x - vx * 0.05, y - vy * 0.05), Color(col, 0.35), 4.0 * sc)


## Rifts: a beacon's ring and pillar, the fleeing Prism Wisp, the Umbral vortex
## (and, during a trial, a countdown ring around the ship).
func _draw_rift(s: Sim, t: float, a: float) -> void:
	if s.rift.is_empty():
		return
	var kind := int(s.rift.kind)
	var col: Color = Defs.RIFTS[kind].color
	var x := lerpf(float(s.rift.ox), float(s.rift.x), a)
	var y := lerpf(float(s.rift.oy), float(s.rift.y), a)
	var ring := Art.tex("ring")
	var glow := Art.tex("glow")
	var beam := Art.tex("beam")
	var life := float(s.rift.life) / 60.0
	# The last five seconds of a waiting rift flicker out.
	var fade := 1.0 if s.rift.on or life > 5.0 else 0.55 + 0.45 * absf(sin(t * (6.0 + 6.0 * (5.0 - life))))
	match kind:
		Defs.RIFT_BEACON:
			var k := s.rift_frac()
			var rr := Defs.BEACON_R
			draw_set_transform(Vector2(x, y), -PI * 0.5, Vector2.ONE)
			var bw := 30.0 + 90.0 * k
			draw_texture_rect(beam, Rect2(0, -bw * 0.5, 1600, bw), false,
					Color(col * (1.0 + k), (0.25 + 0.5 * k) * fade))
			draw_texture_rect(beam, Rect2(0, -bw * 0.12, 1600, bw * 0.24), false,
					Color(2, 2, 2, (0.2 + 0.6 * k) * fade))
			draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
			# Ground ring: dashes turning around the edge, the charge filling it.
			var segs := 16
			for i in segs:
				var a0 := t * 0.6 + TAU * float(i) / float(segs)
				draw_arc(Vector2.ZERO, rr, a0, a0 + TAU / float(segs) * 0.55, 6, Color(col * 1.4, 0.6 * fade), 4.0)
			draw_arc(Vector2.ZERO, rr + 14.0, 0.0, TAU, 64, Color(col, 0.12 * fade), 10.0)
			if k > 0.0:
				draw_arc(Vector2.ZERO, rr - 14.0, -PI * 0.5, -PI * 0.5 + TAU * k, 64, Color(col * 2.0, 0.95), 9.0)
				draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * (rr * 2.2 / 128.0))
				draw_texture(glow, Vector2(-64, -64), Color(col, 0.12 + 0.25 * k))
			var cs := 0.8 + 0.25 * k + 0.06 * sin(t * 5.0)
			draw_set_transform(Vector2(x, y), t * (0.8 + 4.0 * k), Vector2(cs, cs))
			draw_texture(Art.tex("i_rift_beacon"), Vector2(-48, -48), Color(1.6, 1.6, 1.6, fade))
		Defs.RIFT_WISP:
			var tired: bool = s.rift.on and int(s.rift.k0) % 300 >= 210
			var flick := 0.6 + 0.4 * absf(sin(t * 30.0)) if tired else 1.0
			var hue := Color.from_hsv(fmod(t * 0.5, 1.0), 0.45, 1.0)
			draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * 1.6)
			draw_texture(glow, Vector2(-64, -64), Color(hue, 0.45 * fade * flick))
			draw_set_transform(Vector2(x, y), t * 2.5, Vector2.ONE * (0.55 + 0.05 * sin(t * 9.0)))
			draw_texture(ring, Vector2(-128, -128), Color(col * 1.6, 0.7 * fade * flick))
			draw_set_transform(Vector2(x, y), -t * 4.0, Vector2.ONE * 0.75)
			draw_texture(Art.tex("i_rift_wisp"), Vector2(-48, -48), Color(1.8, 1.8, 1.8, fade * flick))
			draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * 0.45)
			draw_texture(glow, Vector2(-64, -64), Color(2.2, 2.2, 2.2, fade * flick))
		Defs.RIFT_TRIAL:
			var on: bool = s.rift.on
			var vs := (Defs.TRIAL_R * 1.5 / 110.0) * (1.0 + 0.05 * sin(t * 3.0))
			draw_set_transform(Vector2(x, y), -t * (1.2 if not on else 3.5), Vector2(vs, vs))
			draw_texture(Art.tex("vortex"), Vector2(-128, -128), Color(col * 1.5, 0.85 * fade))
			draw_set_transform(Vector2(x, y), t * 0.7, Vector2(vs, vs) * 0.7)
			draw_texture(Art.tex("vortex"), Vector2(-128, -128), Color(1.0, 0.4, 0.8, 0.5 * fade))
			draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * (Defs.TRIAL_R * 2.4 / 128.0))
			draw_texture(glow, Vector2(-64, -64), Color(col, 0.3 * fade))
			if not on:
				draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
				var pulse := fmod(t * 0.8, 1.0)
				draw_arc(Vector2.ZERO, Defs.TRIAL_R * (1.0 + 0.6 * pulse), 0.0, TAU, 48,
						Color(col * 1.4, 0.5 * (1.0 - pulse)), 4.0)
			else:
				# Around the ship: kills needed (inner) and time left (outer).
				var px := lerpf(s.ppx, s.px, a)
				var py := lerpf(s.ppy, s.py, a)
				var tl := clampf(float(s.rift.life) / float(Defs.TRIAL_TICKS), 0.0, 1.0)
				var kf := s.rift_frac()
				draw_set_transform(Vector2(px, py), 0.0, Vector2.ONE)
				var warn := tl < 0.3
				var tc := Color(1.0, 0.3, 0.4) if warn else col
				var pulse2 := 0.75 + 0.25 * sin(t * (14.0 if warn else 5.0))
				draw_arc(Vector2.ZERO, 92.0, -PI * 0.5, -PI * 0.5 + TAU * tl, 64, Color(tc * 1.6, 0.85 * pulse2), 5.0)
				draw_arc(Vector2.ZERO, 80.0, -PI * 0.5, -PI * 0.5 + TAU * kf, 64, Color(1.6, 1.2, 2.0, 0.9), 4.0)
		Defs.RIFT_STARFALL:
			_draw_starfall(s, x, y, col, t, fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Starfall: a wide ring of cold light with a star at its heart. Once it is
## called down, every meteor shows where it will land: a shrinking target
## and the comet itself, falling in from high above.
func _draw_starfall(s: Sim, x: float, y: float, col: Color, t: float, fade: float) -> void:
	var on: bool = s.rift.on
	var k := s.rift_frac()
	var rr := Defs.STARFALL_R
	var glow := Art.tex("glow")
	var ring := Art.tex("ring")
	draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
	var segs := 24
	for i in segs:
		var a0 := -t * 0.35 + TAU * float(i) / float(segs)
		draw_arc(Vector2.ZERO, rr, a0, a0 + TAU / float(segs) * 0.5, 6, Color(col * 1.4, (0.5 + 0.3 * k) * fade), 4.0)
	draw_arc(Vector2.ZERO, rr + 16.0, 0.0, TAU, 72, Color(col, 0.1 * fade), 12.0)
	if on:
		draw_arc(Vector2.ZERO, rr - 16.0, -PI * 0.5, -PI * 0.5 + TAU * k, 72, Color(col * 2.0, 0.95), 9.0)
		draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * (rr * 2.2 / 128.0))
		draw_texture(glow, Vector2(-64, -64), Color(col, 0.08 + 0.1 * k))
	else:
		var pulse := fmod(t * 0.7, 1.0)
		draw_arc(Vector2.ZERO, rr * (0.3 + 0.7 * pulse), 0.0, TAU, 64, Color(col * 1.3, 0.35 * (1.0 - pulse) * fade), 3.0)
	var cs := 0.85 + 0.08 * sin(t * 4.0)
	draw_set_transform(Vector2(x, y), t * (0.4 if not on else 2.0), Vector2(cs, cs))
	draw_texture(Art.tex("i_rift_starfall"), Vector2(-48, -48), Color(1.6, 1.6, 1.8, fade))
	if not s.rift.has("mets"):
		return
	var comet := Art.tex("comet")
	for m in s.rift.mets:
		var mx: float = m[0]
		var my: float = m[1]
		var left := clampf(float(m[2]) / float(Defs.METEOR_FALL), 0.0, 1.0)
		var near := 1.0 - left
		var mr := Defs.METEOR_R
		# The mark: a target ring closing in, red-hot just before impact.
		var hot := Color(1.0, 0.45, 0.35) if left < 0.3 else col
		draw_set_transform(Vector2(mx, my), 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, mr, Color(hot, 0.05 + 0.12 * near))
		draw_arc(Vector2.ZERO, mr, 0.0, TAU, 40, Color(hot * 1.5, 0.35 + 0.5 * near), 2.5)
		draw_arc(Vector2.ZERO, mr * (0.25 + 0.75 * left), 0.0, TAU, 32, Color(hot * 1.8, 0.4 + 0.5 * near), 3.0)
		# The comet: falls along a steep diagonal and lands on the mark.
		var ox := -260.0 * left
		var oy := -900.0 * left
		var cx := mx + ox
		var cy := my + oy
		var dir := atan2(900.0, 260.0)
		draw_set_transform(Vector2(cx, cy), dir, Vector2(1.0, 1.0) * (0.7 + 0.5 * near))
		draw_texture(comet, Vector2(-224, -32), Color(col * 1.8, 0.3 + 0.7 * near))
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2.ONE * (0.4 + 0.4 * near))
		draw_texture(glow, Vector2(-64, -64), Color(1.8, 1.8, 2.2, 0.5 + 0.5 * near))
		draw_set_transform(Vector2(mx, my), t * 3.0, Vector2.ONE * (mr / 110.0) * (0.6 + 0.4 * left))
		draw_texture(ring, Vector2(-128, -128), Color(hot * 1.3, 0.25 * near))


## Ion Wake: a ribbon of light along the path the ship flew.
func _draw_wake(s: Sim, t: float) -> void:
	var n := s.trail.size()
	if n < 2:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in range(1, n):
		var p0: Array = s.trail[k - 1]
		var p1: Array = s.trail[k]
		var life := float(p1[2]) / float(Defs.WAKE_TICKS)
		var a := Vector2(p0[0], p0[1])
		var b := Vector2(p1[0], p1[1])
		var flick := 0.85 + 0.15 * sin(t * 30.0 + float(k))
		draw_line(a, b, Color(0.3, 0.8, 1.6, 0.22 * life * flick), Sim.WAKE_R * 2.0 * (0.6 + 0.4 * life))
		draw_line(a, b, Color(0.6, 1.6, 2.0, 0.75 * life), 5.0 * life + 1.0)


## Photon Mines: blinking cores that arm, and the Constellation's tripwires.
func _draw_mines(s: Sim, t: float) -> void:
	if s.mines.is_empty():
		return
	var tex := Art.tex("mine")
	var glow := Art.tex("glow")
	var evo := s.is_evolved("mine")
	var col := Color(1.0, 0.6, 0.4) if evo else Color(1.0, 0.45, 0.55)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for l in s.mine_links():
		var a := Vector2(l[0], l[1])
		var b := Vector2(l[2], l[3])
		var flick := 0.8 + 0.2 * sin(t * 40.0 + a.x * 0.01)
		draw_line(a, b, Color(col * 1.4, 0.25 * flick), 22.0)
		draw_line(a, b, Color(1.8, 1.5, 1.2, 0.85 * flick), 3.0)
	for m in s.mines:
		var armed: bool = int(m.t) <= 0
		var life := clampf(float(m.life) / 120.0, 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin(t * (10.0 if life > 0.99 else 28.0) + float(m.x) * 0.05)
		var sc := 0.9 if armed else 0.6 + 0.3 * (1.0 - float(m.t) / float(Sim.MINE_ARM))
		draw_set_transform(Vector2(m.x, m.y), t * 1.2, Vector2(sc, sc))
		draw_texture(tex, Vector2(-32, -32), Color(col * (1.6 if armed else 0.9), 1.0))
		draw_set_transform(Vector2(m.x, m.y), 0.0, Vector2(0.45, 0.45) * (0.8 + 0.4 * blink))
		draw_texture(glow, Vector2(-64, -64), Color(col * 1.8, (0.5 if armed else 0.2) * (0.5 + 0.5 * blink)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## Sector hazards: the Abyss's black holes and Corona's flares.
func _draw_sector(s: Sim, t: float, a: float) -> void:
	if s.sector == Defs.SECTOR_ABYSS:
		for m in s.maws:
			_draw_maw(m, t, a)
	elif s.sector == Defs.SECTOR_CORONA and not s.flare.is_empty():
		_draw_flare(s, t)
	elif s.sector == Defs.SECTOR_SHARD:
		_draw_shard_glow(s, t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A crystal's look, made once per field: a faceted main prism with two
## smaller ones leaning out of it, and the cracks that open as it charges.
func _shard_shape(s: Sim, k: int) -> Dictionary:
	var c: Dictionary = s.shards[k]
	var key := Vector3(float(c.x), float(c.y), float(c.r))
	var sh: Dictionary = _shard_shapes.get(k, {})
	if not sh.is_empty() and sh.key == key:
		return sh
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(key)
	var r: float = c.r
	var rot := Trig.to_rad(int(c.a))
	var parts: Array = []
	# Two smaller prisms behind the main one.
	for j in 2:
		var ang := rot + PI * 0.6 + float(j) * PI * 0.85 + rnd.randf_range(-0.3, 0.3)
		var cen := Vector2(cos(ang), sin(ang)) * r * 0.58
		parts.append(_prism_pts(rnd, cen, r * rnd.randf_range(0.4, 0.5), 5, ang))
	parts.append(_prism_pts(rnd, Vector2.ZERO, r, 6 + k % 3, rot))
	var cracks: Array = []
	for j in 5:
		var ang2 := rnd.randf() * TAU
		var p0 := Vector2(cos(ang2), sin(ang2)) * r * 0.12
		var p1 := p0 + Vector2(cos(ang2 + rnd.randf_range(-0.5, 0.5)), sin(ang2 + rnd.randf_range(-0.5, 0.5))) * r * 0.45
		var p2 := p1 + Vector2(cos(ang2 + rnd.randf_range(-0.7, 0.7)), sin(ang2 + rnd.randf_range(-0.7, 0.7))) * r * 0.35
		cracks.append(PackedVector2Array([p0, p1, p2]))
	var rubble: Array = []
	for j in 7:
		var ang3 := TAU * float(j) / 7.0 + rnd.randf_range(-0.3, 0.3)
		var cen2 := Vector2(cos(ang3), sin(ang3)) * r * rnd.randf_range(0.25, 0.85)
		rubble.append(_prism_pts(rnd, cen2, r * rnd.randf_range(0.12, 0.22), 4, ang3))
	sh = {"key": key, "parts": parts, "cracks": cracks, "rubble": rubble, "hue": SHARD_HUES[k % SHARD_HUES.size()]}
	_shard_shapes[k] = sh
	return sh


## A prism seen from above, cut like a gem: a ring of jittered corners, a
## flat table on top (nudged towards the light, so it looks tall) and sloped
## facets between them that shade like glass.
func _prism_pts(rnd: RandomNumberGenerator, cen: Vector2, r: float, n: int, rot: float) -> Dictionary:
	var pts := PackedVector2Array()
	var table := PackedVector2Array()
	var top := cen + SHARD_LIGHT * r * 0.16
	var k := rnd.randf_range(0.36, 0.5)
	for i in n:
		var ang := rot + TAU * (float(i) + rnd.randf_range(-0.22, 0.22)) / float(n)
		var p := cen + Vector2(cos(ang), sin(ang)) * r * rnd.randf_range(0.88, 1.1)
		pts.append(p)
		table.append(top + (p - cen) * k)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0.14, 0.2) * r)
	return {"pts": pts, "table": table, "shadow": shadow}


## Crystal bodies (normal blend): dark glass facets lit from the top left.
## Shattered ones leave rubble; growing ones rise out of it.
func _draw_shards(s: Sim, t: float) -> void:
	if s.sector != Defs.SECTOR_SHARD:
		return
	for k in s.shards.size():
		var c: Dictionary = s.shards[k]
		var sh := _shard_shape(s, k)
		var hue: Color = sh.hue
		var st := int(c.st)
		var pos := Vector2(float(c.x), float(c.y))
		if st == 2 or st == 3:
			draw_set_transform(pos, 0.0, Vector2.ONE)
			for rb in sh.rubble:
				_draw_prism(rb, hue, 0.55, 0.0)
		if st == 2:
			continue
		var sc := 1.0
		var hot := 0.0
		if st == 3:
			var g := float(int(c.t)) / float(Defs.SHARD_GROW)
			sc = 0.15 + 0.85 * (1.0 - pow(1.0 - g, 3.0))
			hot = 1.0 - g
		elif st == 1:
			var f := 1.0 - float(int(c.t)) / float(Defs.SHARD_FUSE)
			sc = 1.0 + 0.04 * f + 0.02 * sin(t * 60.0) * f
			hot = 0.4 + 0.6 * f
		draw_set_transform(pos, 0.0, Vector2(sc, sc))
		for part in sh.parts:
			_draw_prism(part, hue, 1.0, hot)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_prism(part: Dictionary, hue: Color, alpha: float, hot: float) -> void:
	var pts: PackedVector2Array = part.pts
	var table: PackedVector2Array = part.table
	var n := pts.size()
	var light := SHARD_LIGHT.normalized()
	draw_colored_polygon(part.shadow, Color(0.0, 0.0, 0.02, 0.5 * alpha))
	var deep := Color(hue.r * 0.1 + 0.015, hue.g * 0.12 + 0.02, hue.b * 0.2 + 0.05)
	var white := Color(1.5, 1.5, 1.6)
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(n)
	for i in n:
		var j := (i + 1) % n
		var mid := ((pts[i] + pts[j]) * 0.5 - cen).normalized()
		var lit := clampf(0.5 + 0.5 * mid.dot(light), 0.0, 1.0)
		var col := deep.lerp(hue * 0.95, pow(lit, 1.6))
		if lit > 0.86:
			col = col.lerp(white, (lit - 0.86) * 2.4)
		col = col.lerp(white, hot * 0.6)
		draw_colored_polygon(PackedVector2Array([pts[i], pts[j], table[j], table[i]]), Color(col, 0.95 * alpha))
	var tc := deep.lerp(hue, 0.5).lerp(white, 0.12 + 0.55 * hot)
	draw_colored_polygon(table, Color(tc, 0.95 * alpha))
	for i in n:
		draw_line(pts[i], table[i], Color(hue.lerp(white, 0.3), 0.45 * alpha), 1.5)
	var ring := table.duplicate()
	ring.append(table[0])
	draw_polyline(ring, Color(hue.lerp(white, 0.5), 0.7 * alpha), 1.5)
	ring = pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, Color(hue.lerp(Color.WHITE, 0.35 + 0.5 * hot), 0.95 * alpha), 2.5)


## Crystal light (additive): a pool of light on the floor, edges that bloom,
## a charge ring that fills with kills, cracks and a hum while it resonates,
## and a ghost outline where a shattered one will grow back.
func _draw_shard_glow(s: Sim, t: float) -> void:
	var glow := Art.tex("glow")
	for k in s.shards.size():
		var c: Dictionary = s.shards[k]
		var sh := _shard_shape(s, k)
		var hue: Color = sh.hue
		var st := int(c.st)
		var r: float = c.r
		var pos := Vector2(float(c.x), float(c.y))
		if st == 2:
			# Waiting to grow back: a faint dashed outline, brighter near the end.
			var left := float(int(c.t)) / float(Defs.SHARD_REGROW * Sim.TPS)
			var k2 := clampf(1.0 - left / 0.2, 0.0, 1.0)
			draw_set_transform(pos, t * 0.3, Vector2.ONE)
			for j in 10:
				var a0 := TAU * float(j) / 10.0
				draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 20.0, 6, Color(hue, 0.1 + 0.35 * k2), 2.0)
			continue
		var frac := s.shard_frac(k)
		var res := st == 1
		var fuse := 1.0 - float(int(c.t)) / float(Defs.SHARD_FUSE) if res else 0.0
		var breath := 0.85 + 0.15 * sin(t * 1.7 + float(k))
		draw_set_transform(pos, 0.0, Vector2.ONE * (r * 3.4 / 128.0))
		draw_texture(glow, Vector2(-64, -64), Color(hue, (0.1 + 0.22 * frac) * breath + 0.3 * fuse))
		draw_set_transform(pos, 0.0, Vector2.ONE * (r * 1.3 / 128.0))
		draw_texture(glow, Vector2(-64, -64), Color(hue * 1.6, 0.12 + 0.5 * frac + 0.4 * fuse))
		var sc := 1.0
		if st == 3:
			var g := float(int(c.t)) / float(Defs.SHARD_GROW)
			sc = 0.15 + 0.85 * (1.0 - pow(1.0 - g, 3.0))
		draw_set_transform(pos, 0.0, Vector2(sc, sc))
		var edge := hue * (1.0 + 0.8 * frac + 1.2 * fuse)
		for part in sh.parts:
			var ring: PackedVector2Array = (part.pts as PackedVector2Array).duplicate()
			ring.append(ring[0])
			draw_polyline(ring, Color(edge, 0.35 + 0.35 * frac), 3.0)
		if frac > 0.5 or res:
			# Cracks of light open as it fills.
			var ck := clampf((frac - 0.5) * 2.0, 0.0, 1.0) if not res else 1.0
			var flick := 1.0 if not res else 0.7 + 0.3 * sin(t * 50.0)
			for cr in sh.cracks:
				draw_polyline(cr, Color(2.0, 2.0, 2.2, (0.25 + 0.6 * ck) * flick), 1.5 + 1.5 * fuse)
		draw_set_transform(pos, 0.0, Vector2.ONE)
		if st == 0 and frac > 0.0:
			draw_arc(Vector2.ZERO, r + 18.0, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(6, int(48.0 * frac)),
					Color(hue * 1.5, 0.55), 4.0)
		if res:
			# The hum: rings closing in on it, and a white-hot heart.
			for j in 3:
				var f := fmod(fuse * 3.0 + float(j) / 3.0, 1.0)
				draw_arc(Vector2.ZERO, lerpf(r * 2.6, r * 1.05, f), 0.0, TAU, 48, Color(hue * 2.0, 0.5 * f), 3.0)
			draw_set_transform(pos, 0.0, Vector2.ONE * (r * (0.8 + 1.4 * fuse) / 128.0))
			draw_texture(glow, Vector2(-64, -64), Color(2.0, 2.0, 2.2, 0.4 + 0.5 * fuse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A black hole: its reach as a faint turning ring, a photon ring at the
## core, and in its last second a white shudder before it collapses.
func _draw_maw(m: Dictionary, t: float, a: float) -> void:
	var x := lerpf(float(m.ox), float(m.x), a)
	var y := lerpf(float(m.oy), float(m.y), a)
	var grip := minf(Sim.maw_strength(m), 1.0)
	var left := int(m.life) - int(m.t)
	var core := Defs.MAW_CORE * (0.6 + 0.4 * grip)
	var violet := Color(0.62, 0.42, 1.0)
	draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
	var reach := Defs.MAW_PULL
	var segs := 28
	for k in segs:
		var a0 := -t * 0.35 + TAU * float(k) / float(segs)
		draw_arc(Vector2.ZERO, reach, a0, a0 + TAU / float(segs) * 0.4, 4, Color(violet, 0.16 * grip), 3.0)
	# Rings of light sliding inwards, like water round a drain.
	for k in 3:
		var f := fmod(t * 0.45 + float(k) / 3.0, 1.0)
		var rr := lerpf(reach * 0.85, core * 1.3, f)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(violet * 1.3, 0.22 * f * grip), 2.0 + 3.0 * f)
	var glow := Art.tex("glow")
	draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * (core * 3.6 / 128.0))
	draw_texture(glow, Vector2(-64, -64), Color(0.7, 0.4, 1.4, 0.35 * grip))
	draw_set_transform(Vector2(x, y), t * 2.4, Vector2.ONE)
	for k in 6:
		var a1 := TAU * float(k) / 6.0
		draw_arc(Vector2.ZERO, core * 1.22, a1, a1 + 0.7, 12, Color(1.8, 1.4, 2.4, 0.8 * grip), 3.0)
	if left < 60:
		var k2 := 1.0 - float(left) / 60.0
		draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, core * (2.6 - 1.6 * k2), 0.0, TAU, 64, Color(2.4, 2.2, 2.6, 0.9 * k2), 4.0 + 6.0 * k2)
	var fed := int(m.eaten)
	if fed >= Defs.MAW_SATED:
		# Sated: a golden crown says a cache waits inside.
		draw_set_transform(Vector2(x, y), -t * 1.2, Vector2.ONE)
		for k in 8:
			var a2 := TAU * float(k) / 8.0
			draw_arc(Vector2.ZERO, core * 1.7, a2, a2 + 0.35, 6, Color(2.0, 1.6, 0.6, 0.85), 4.0)


## A flare: while the sun swells, the safe lanes light up as cool wedges;
## then a wall of fire races outwards with those lanes as its gaps.
func _draw_flare(s: Sim, t: float) -> void:
	var f: Dictionary = s.flare
	var warn := s.flare_warn()
	var flying := int(f.t) >= Defs.FLARE_WARN
	var r: float = f.r
	var gaps: Array = f.gaps.duplicate()
	gaps.sort()
	var gw := Trig.to_rad(Defs.FLARE_GAP)
	var lane := Color(0.55, 1.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Safe lanes: wedges from the sun to the wall.
	var la := (0.18 + 0.18 * sin(t * 10.0)) * warn if not flying else 0.14
	for g in gaps:
		var c := Trig.to_rad(int(g))
		var r0 := maxf(Defs.SUN_R + 20.0, r + (0.0 if not flying else Defs.FLARE_W))
		var r1 := Sim.ARENA_R
		if r0 >= r1 - 20.0:
			continue
		var p0 := Vector2(cos(c - gw), sin(c - gw))
		var p1 := Vector2(cos(c + gw), sin(c + gw))
		draw_colored_polygon(PackedVector2Array([p0 * r0, p0 * r1, p1 * r1, p1 * r0]), Color(lane, la * 0.6))
		draw_line(p0 * r0, p0 * r1, Color(lane * 1.4, la), 3.0)
		draw_line(p1 * r0, p1 * r1, Color(lane * 1.4, la), 3.0)
	if not flying:
		return
	# The front: arcs of fire between the gaps.
	var hot := Color(2.4, 1.15, 0.4)
	for k in gaps.size():
		var a0 := Trig.to_rad(int(gaps[k])) + gw
		var a1 := Trig.to_rad(int(gaps[(k + 1) % gaps.size()])) - gw
		if a1 <= a0:
			a1 += TAU
		var pts := clampi(int(r * (a1 - a0) / 22.0), 8, 160)
		draw_arc(Vector2.ZERO, r, a0, a1, pts, Color(1.0, 0.35, 0.1, 0.25), Defs.FLARE_W * 2.6)
		draw_arc(Vector2.ZERO, r, a0, a1, pts, Color(hot, 0.85), Defs.FLARE_W)
		draw_arc(Vector2.ZERO, r - Defs.FLARE_W * 0.15, a0, a1, pts, Color(2.6, 2.3, 1.8, 0.9), Defs.FLARE_W * 0.25)
