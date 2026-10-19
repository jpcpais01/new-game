class_name ResultsPanel
extends Modal
## End of run: verdict, stats, Flux earned, records, next steps.

signal retry
signal forge
signal home

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
	var h := UiKit.button("HOME", UiKit.MAGENTA, 40)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.pressed.connect(func(): home.emit())
	row.add_child(h)
	body.add_child(row)


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
