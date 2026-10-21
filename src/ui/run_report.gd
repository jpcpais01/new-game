class_name RunReport
extends RefCounted
## Shared pieces of the after-action report: who dealt the damage (names,
## colours and icons for every damage source the sim tracks) and the animated
## damage rows used by the results screen, the pause menu and the full report.


## Name, tag, colour and icon of a damage source from `Sim.damage_report()`.
static func source_info(sim: Sim, src: String) -> Dictionary:
	if Defs.WEAPONS.has(src):
		var did := sim.display_id(src)
		var info := Defs.card_info(did)
		var lvl := sim.weapon_level(src)
		return {"name": String(info.name), "tag": "EVOLVED" if sim.is_evolved(src) else "LV %d" % lvl,
				"color": info.get("color", UiKit.CYAN), "tex": Art.icon(did), "weapon": true}
	if Defs.RESONANCES.has(src):
		var r: Dictionary = Defs.RESONANCES[src]
		return {"name": String(r.name), "tag": "RESONANCE", "color": r.color, "tex": Art.icon("res_" + src)}
	var sd := Defs.ship(sim.ship_id)
	match src:
		"od":
			return {"name": String(sd.od), "tag": "OVERDRIVE", "color": sd.color, "tex": Art.icon("od_" + sim.ship_id)}
		"wake":
			return {"name": String(Defs.RELICS.wake.name), "tag": "RELIC", "color": Defs.RELICS.wake.color,
					"tex": Art.icon("wake")}
		"rift":
			return {"name": "Rifts", "tag": "BEACONS · METEORS", "color": Color(0.78, 0.55, 1.0),
					"tex": Art.icon("rift_beacon")}
		"maw":
			return {"name": "Black holes", "tag": "THE ABYSS", "color": Defs.sector(Defs.SECTOR_ABYSS).color,
					"tex": Art.icon("sector_abyss")}
		"sun":
			return {"name": "The sun", "tag": "CORONA", "color": Defs.sector(Defs.SECTOR_CORONA).color,
					"tex": Art.icon("sector_corona")}
		"shard":
			return {"name": "Crystals", "tag": "THE SHARDFIELD", "color": Defs.sector(Defs.SECTOR_SHARD).color,
					"tex": Art.icon("shard")}
		"levi":
			return {"name": "Leviathan scales", "tag": "BURSTING BODY", "color": Defs.ENEMY_COLOR[Defs.LEVIATHAN],
					"tex": Art.tex("levi_seg")}
		"bomber":
			return {"name": "Bomber blasts", "tag": "CHAIN REACTIONS", "color": Defs.ENEMY_COLOR[Defs.BOMBER],
					"tex": Art.tex("e_bomber")}
		"star":
			return {"name": "Falling stars", "tag": "STARCALLER ELITES", "color": Defs.TRAITS.starcaller.color,
					"tex": Art.icon("trait_starcaller")}
		"volatile":
			var m: Dictionary = Defs.MUTATORS.volatile
			return {"name": String(m.name), "tag": "MUTATOR", "color": m.color, "tex": Art.icon("mod_volatile")}
		"ship":
			return {"name": "%s shockwaves" % sd.name, "tag": "SHIP", "color": sd.color,
					"tex": Art.icon("ship_" + sim.ship_id)}
	return {"name": "Other", "tag": "", "color": UiKit.DIM, "tex": Art.icon("flux")}


## Damage per second while a weapon was carried (0 for other sources).
static func dps(sim: Sim, src: String, dmg: float) -> float:
	if not sim.got_at.has(src):
		return 0.0
	var secs := float(sim.tick - int(sim.got_at[src])) / Sim.TPS
	return dmg / maxf(1.0, secs)


## Short number: 1,234 / 45.6K / 1.23M.
static func short(v: float) -> String:
	if v >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fK" % (v / 1000.0)
	return UiKit.fmt_int(int(v))


## A column of damage rows (icon, name, tag, bar, share, numbers), at most n,
## bars filling one after another when `delay` >= 0.
static func rows(sim: Sim, n: int, width: float, delay := 0.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var rep := sim.damage_report()
	var total := 0.0
	for r in rep:
		total += float(r[1])
	if rep.is_empty() or total <= 0.0:
		box.add_child(UiKit.label("NO DAMAGE DEALT YET", 24, UiKit.DIM, UiKit.display_light()))
		return box
	var top := float(rep[0][1])
	var shown := 0
	for k in mini(n, rep.size()):
		var r: Array = rep[k]
		if float(r[1]) < total * 0.001:
			break
		box.add_child(_row(sim, r, total, top, width, delay + 0.09 * k if delay >= 0.0 else -1.0, k))
		shown += 1
	var rest := 0.0
	for k in range(shown, rep.size()):
		rest += float(rep[k][1])
	if rest >= total * 0.001:
		box.add_child(UiKit.label("+ %d MORE  ·  %.1f%%" % [rep.size() - shown, 100.0 * rest / total], 20, UiKit.DIM,
				UiKit.display_light()))
	return box


static func _row(sim: Sim, r: Array, total: float, top: float, width: float, delay: float, rank: int) -> Control:
	var src: String = r[0]
	var dmg: float = r[1]
	var info := source_info(sim, src)
	var col: Color = info.color
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var icon := TextureRect.new()
	icon.texture = info.tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(72, 72)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var col_box := VBoxContainer.new()
	col_box.add_theme_constant_override("separation", 4)
	col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var nm := UiKit.label(String(info.name).to_upper(), 24, col.lightened(0.15), UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT)
	head.add_child(nm)
	if String(info.tag) != "":
		var tg := UiKit.label(String(info.tag), 16, Color(col, 0.7), UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT)
		tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(tg)
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	head.add_child(UiKit.label("%.1f%%" % (100.0 * dmg / total), 24, Color.WHITE if rank == 0 else UiKit.DIM,
			UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT))
	col_box.add_child(head)
	var bar := DamageBar.new()
	bar.color = col
	bar.target = dmg / maxf(1.0, top)
	bar.custom_minimum_size = Vector2(width - 88.0, 16)
	bar.crown = rank == 0
	col_box.add_child(bar)
	if delay >= 0.0:
		bar.fill = 0.0
		bar.create_tween().tween_property(bar, "fill", bar.target, 0.7).set_delay(delay) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	else:
		bar.fill = bar.target
	var bits: Array = [short(dmg) + " DMG"]
	if int(r[2]) > 0:
		bits.append(UiKit.fmt_int(int(r[2])) + " KILLS")
	var d := dps(sim, src, dmg)
	if d > 0.0:
		bits.append(short(d) + " DPS")
	col_box.add_child(UiKit.label("  ·  ".join(bits), 18, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(col_box)
	return row


## A glowing bar that fills to `fill` (0..1). The top damage dealer wears a
## shimmer.
class DamageBar:
	extends Control
	var color := UiKit.CYAN
	var fill := 0.0:
		set(v):
			fill = v
			queue_redraw()
	var target := 1.0
	var crown := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(crown)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, h * 0.25, w, h * 0.5), Color(color, 0.12))
		var fw := w * clampf(fill, 0.0, 1.0)
		if fw <= 1.0:
			return
		draw_rect(Rect2(0, -2, fw, h + 4), Color(color, 0.18))
		draw_rect(Rect2(0, 0, fw, h), Color(color * 1.25, 0.95))
		draw_rect(Rect2(0, 2, fw, h * 0.3), Color(1, 1, 1, 0.35))
		if crown:
			var sx := fmod(_t * 0.45, 1.4) * fw - fw * 0.2
			for k in 6:
				var x0 := sx + k * 6.0
				if x0 > 0.0 and x0 < fw - 6.0:
					draw_rect(Rect2(x0, 0, 6, h), Color(1, 1, 1, 0.07 * (6 - absf(k - 2.5))))
		draw_rect(Rect2(fw - 3, -3, 3, h + 6), Color(1, 1, 1, 0.9))
