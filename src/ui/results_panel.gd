class_name ResultsPanel
extends Modal
## End of run: verdict, stats, Flux earned, records, next steps.

signal retry
signal forge
signal home
signal hangar

var sim: Sim
var won := false
var beat := {}

var _flux_label: Label
var _flux_shown := 0.0
var _flux_target := 0


func build() -> void:
	accent = UiKit.GOLD if won else UiKit.MAGENTA
	var t := heading("DAWN REACHED" if won else "SIGNAL LOST", UiKit.GOLD if won else UiKit.RED, 76)
	t.pivot_offset = Vector2(386, 50)
	t.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(t, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sub := "You outlasted the Eclipse." if won else "The swarm took you. The light remembers."
	body.add_child(UiKit.label(sub, 34, UiKit.DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 22)
	_stat(grid, "SURVIVED", UiKit.fmt_time(sim.seconds()), beat.has("time"), 0)
	_stat(grid, "LEVEL", str(sim.level), beat.has("level"), 1)
	_stat(grid, "KILLS", UiKit.fmt_int(sim.kills), beat.has("kills"), 2)
	_stat(grid, "BOSSES", str(sim.bosses_killed), false, 3)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	body.add_child(cc)
	_evolutions()
	_missions()
	var flux_box := PanelContainer.new()
	var fsb := UiKit.box(UiKit.GOLD, Color(0.1, 0.07, 0.02, 0.6), 24, 2, 12)
	fsb.content_margin_top = 16
	fsb.content_margin_bottom = 16
	flux_box.add_theme_stylebox_override("panel", fsb)
	_flux_label = UiKit.glow_label("+0  FLUX", 58, UiKit.GOLD)
	flux_box.add_child(_flux_label)
	body.add_child(flux_box)
	_flux_target = sim.flux_earned()
	var total := UiKit.label("TOTAL  ◆ %s" % UiKit.fmt_int(int(Save.data.flux)), 30, UiKit.DIM, UiKit.display_light())
	body.add_child(total)
	var again := UiKit.button("RETRY", UiKit.CYAN, 52, true)
	again.custom_minimum_size = Vector2(0, 140)
	again.pressed.connect(func(): retry.emit())
	body.add_child(again)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var f := UiKit.button("FORGE", UiKit.GOLD, 40)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.pressed.connect(func(): forge.emit())
	row.add_child(f)
	if not (beat.get("ships", []) as Array).is_empty():
		var hg := UiKit.button("HANGAR", UiKit.CYAN, 40)
		hg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hg.pressed.connect(func(): hangar.emit())
		row.add_child(hg)
	var h := UiKit.button("HOME", UiKit.MAGENTA, 40)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.pressed.connect(func(): home.emit())
	row.add_child(h)
	body.add_child(row)


## Evolved weapons this run; first-time discoveries are marked NEW.
func _evolutions() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	for w in sim.weapons:
		if not sim.is_evolved(w.id):
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UiKit.icon_rect(w.id + "_evo", 110))
		var fresh: bool = beat.has(w.id)
		cell.add_child(UiKit.label("NEW" if fresh else "EVOLVED", 20, UiKit.GOLD if fresh else UiKit.DIM, UiKit.display()))
		row.add_child(cell)
	if row.get_child_count() == 0:
		row.free()
		return
	body.add_child(row)
	UiKit.pop_in(row, 0.6, 20)


## Missions completed this run, and any ship they unlocked.
func _missions() -> void:
	var ids: Array = beat.get("missions", [])
	if ids.is_empty():
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var shown := 0
	for id in ids:
		for m in Defs.MISSIONS:
			if m.id != id:
				continue
			if shown < 3:
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 14)
				var name := UiKit.label("✓  " + String(m.name).to_upper(), 30, UiKit.GREEN, UiKit.display(),
						HORIZONTAL_ALIGNMENT_LEFT)
				name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(name)
				line.add_child(UiKit.label("+◆ %s" % UiKit.fmt_int(int(m.flux)), 30, UiKit.GOLD, UiKit.display()))
				box.add_child(line)
				UiKit.pop_in(line, 0.8 + 0.25 * shown, 0)
			shown += 1
	if shown > 3:
		box.add_child(UiKit.label("+%d MORE MISSIONS" % (shown - 3), 26, UiKit.DIM, UiKit.display_light()))
	body.add_child(box)
	for k in mini(shown, 3):
		get_tree().create_timer(0.8 + 0.25 * k).timeout.connect(func(): Sfx.play("mission", 1.0 + 0.06 * k))
	for sid in beat.get("ships", []):
		var sd := Defs.ship(String(sid))
		var p := PanelContainer.new()
		var sb := UiKit.box(sd.color, Color(sd.color, 0.12), 24, 3, 18)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		p.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 18)
		h.add_child(UiKit.icon_rect("ship_" + String(sd.id), 90))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(UiKit.label("NEW SHIP UNLOCKED", 24, Color(1, 1, 1, 0.75), UiKit.display_light(),
				HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(UiKit.glow_label(String(sd.name).to_upper(), 50, sd.color))
		h.add_child(v)
		p.add_child(h)
		body.add_child(p)
		UiKit.pop_in(p, 1.4, 0)
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "modulate", Color(1.3, 1.3, 1.3), 0.7).set_delay(1.8)
		tw.tween_property(p, "modulate", Color.WHITE, 0.7)


func _stat(grid: GridContainer, name: String, value: String, record: bool, k: int) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(UiKit.label(name, 26, UiKit.DIM, UiKit.display_light()))
	var v := UiKit.glow_label(value, 58, Color.WHITE)
	box.add_child(v)
	if record:
		var r := UiKit.label("NEW BEST", 24, UiKit.GOLD, UiKit.display())
		box.add_child(r)
		var tw := r.create_tween().set_loops()
		tw.tween_property(r, "modulate:a", 0.4, 0.5)
		tw.tween_property(r, "modulate:a", 1.0, 0.5)
	grid.add_child(box)
	UiKit.pop_in(box, 0.25 + 0.1 * k, 24)


func _process(delta: float) -> void:
	if _flux_label == null:
		return
	if _flux_shown < float(_flux_target):
		var before := int(_flux_shown)
		_flux_shown = minf(float(_flux_target), _flux_shown + maxf(4.0, float(_flux_target) * 0.9) * delta)
		if int(_flux_shown) != before and int(_flux_shown) % 3 == 0:
			Sfx.play("gem", 1.0 + 0.6 * _flux_shown / maxf(1.0, float(_flux_target)))
		_flux_label.text = "+%s  FLUX" % UiKit.fmt_int(int(_flux_shown))
