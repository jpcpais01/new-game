class_name ReportPanel
extends Modal
## The after-action report: every damage source ranked, the run as a timeline,
## each boss fight and the run's highlights. Opened from the results screen,
## or from the pause menu for the run so far.

var sim: Sim
var live := false   # opened mid-run from the pause menu

const W := 772.0


func build() -> void:
	Art.ensure()
	accent = UiKit.MAGENTA
	heading("AFTER-ACTION REPORT" if not live else "RUN SO FAR", UiKit.MAGENTA, 52)
	var sd := Defs.ship(sim.ship_id)
	var bits: Array = [String(sd.name).to_upper(), UiKit.fmt_time(sim.seconds())]
	if sim.gauntlet:
		bits.append("THE GAUNTLET")
	elif sim.loadout.has("daily"):
		bits.append("DAILY " + Daily.label(int(sim.loadout.daily)))
	if sim.sector > 0:
		bits.append(String(Defs.sector(sim.sector).name).to_upper())
	if sim.radiance > 0:
		bits.append("R%d" % sim.radiance)
	if not live:
		bits.append("DAWN" if sim.dawn else "LOST")
	body.add_child(UiKit.label("  ·  ".join(bits), 24, UiKit.DIM, UiKit.display_light()))
	_section("DAMAGE", "%s DEALT" % RunReport.short(_total()))
	body.add_child(RunReport.rows(sim, 12, W, 0.15))
	_section("TIMELINE", "")
	var chart := ReportChart.new()
	chart.sim = sim
	chart.custom_minimum_size = Vector2(W, 330)
	body.add_child(chart)
	body.add_child(_legend())
	if not sim.boss_log.is_empty():
		_section("BOSSES", "")
		_bosses()
	_section("HIGHLIGHTS", "")
	_highlights()
	var done := UiKit.button("BACK", UiKit.MAGENTA, 42, true)
	done.custom_minimum_size = Vector2(0, 116)
	done.pressed.connect(close)
	body.add_child(done)
	Sfx.play("card", 1.1)


func _total() -> float:
	var t := 0.0
	for r in sim.damage_report():
		t += float(r[1])
	return t


func _section(title: String, right: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(W, 0)
	var l := UiKit.label(title, 26, UiKit.CYAN, UiKit.display(), HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(l)
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)
	if right != "":
		row.add_child(UiKit.label(right, 22, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_RIGHT))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var rule := ColorRect.new()
	rule.color = Color(UiKit.CYAN, 0.25)
	rule.custom_minimum_size = Vector2(W, 2)
	v.add_child(rule)
	body.add_child(v)


func _legend() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	for it in [["HULL", UiKit.CYAN], ["DAMAGE / S", UiKit.MAGENTA], ["BOSS FIGHT", UiKit.GOLD]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var sw := ColorRect.new()
		sw.color = it[1]
		sw.custom_minimum_size = Vector2(22, 6)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		h.add_child(UiKit.label(it[0], 18, UiKit.DIM, UiKit.display_light()))
		row.add_child(h)
	return row


func _bosses() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	for k in sim.boss_log.size():
		var b: Array = sim.boss_log[k]
		var type: int = b[0]
		var col: Color = Defs.ENEMY_COLOR[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var icon := TextureRect.new()
		icon.texture = Art.enemy[type]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64)
		row.add_child(icon)
		var nm := UiKit.label(String(Hud.BOSS_NAMES.get(type, "BOSS")), 26, col, UiKit.display(),
				HORIZONTAL_ALIGNMENT_LEFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UiKit.label("AT " + UiKit.fmt_time(float(b[1]) / Sim.TPS), 20, UiKit.DIM, UiKit.display_light()))
		var verdict := "STILL STANDING"
		var vc := UiKit.DIM
		if int(b[2]) >= 0:
			var fight := float(int(b[2]) - int(b[1])) / Sim.TPS
			if b[3]:
				verdict = "ESCAPED  " + GauntletScreen.fmt_split(int(b[2]) - int(b[1]))
				vc = UiKit.RED
			else:
				verdict = "FELLED  " + GauntletScreen.fmt_split(int(b[2]) - int(b[1]))
				vc = UiKit.GOLD if fight < 30.0 else UiKit.GREEN
		var vl := UiKit.label(verdict, 24, vc, UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size = Vector2(250, 0)
		row.add_child(vl)
		box.add_child(row)
		UiKit.pop_in(row, 0.1 + 0.07 * k)
	body.add_child(box)


func _highlights() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var hit := RunReport.source_info(sim, sim.best_hit_src) if sim.best_hit > 0.0 else {}
	var tiles: Array = [
		["BIGGEST HIT", RunReport.short(sim.best_hit), String(hit.get("name", "—")).to_upper(),
				hit.get("color", UiKit.DIM)],
		["PEAK DAMAGE", RunReport.short(sim.peak_dps()) + "/S", "OVER 5 SECONDS", UiKit.MAGENTA],
		["CLOSEST CALL", "UNTOUCHED" if sim.low_hp < 0.0 else "%d HP" % maxi(1, ceili(sim.low_hp)),
				"NEVER HIT" if sim.low_hp < 0.0 else "LOWEST HULL", UiKit.GREEN if sim.low_hp < 0.0 else UiKit.RED],
		["PEAK SWARM", str(sim.peak_en), "ENEMIES AT ONCE", Defs.ENEMY_COLOR[0]],
		["BEST CHAIN", UiKit.fmt_int(sim.chain_best), "KILLS IN A ROW", UiKit.GOLD],
		["KILL RATE", "%d/MIN" % int(float(sim.kills) / maxf(1.0 / 60.0, sim.seconds() / 60.0)), "ON AVERAGE",
				UiKit.CYAN],
	]
	for k in tiles.size():
		var tile := _tile(tiles[k])
		grid.add_child(tile)
		UiKit.pop_in(tile, 0.2 + 0.06 * k, 24.0)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	body.add_child(cc)


func _tile(t: Array) -> Control:
	var col: Color = t[3]
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(col, 0.6), Color(0.04, 0.03, 0.1, 0.8), 16, 2, 6)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(246, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UiKit.label(t[0], 17, UiKit.DIM, UiKit.display_light()))
	v.add_child(UiKit.glow_label(t[1], 34, col))
	var sub := UiKit.label(t[2], 15, Color(col, 0.75), UiKit.display_light())
	sub.clip_text = true
	sub.custom_minimum_size = Vector2(220, 0)
	v.add_child(sub)
	p.add_child(v)
	return p
