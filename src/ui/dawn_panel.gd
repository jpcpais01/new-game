class_name DawnPanel
extends Modal
## The Eclipse is down: bank the win, or fly on into the Afterdark.

signal chose(go_on: bool)

var sim: Sim


func build() -> void:
	accent = UiKit.GOLD
	var t := heading("DAWN REACHED", UiKit.GOLD, 78)
	t.pivot_offset = Vector2(386, 50)
	t.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(t, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	body.add_child(UiKit.label("You outlasted the Eclipse in %s." % UiKit.fmt_time(sim.seconds()), 34, UiKit.DIM))
	var score := UiKit.glow_label(UiKit.fmt_int(sim.score()), 72, Color.WHITE)
	body.add_child(UiKit.label("SCORE", 26, UiKit.DIM, UiKit.display_light()))
	body.add_child(score)
	UiKit.pop_in(score, 0.3, 20)
	var p := PanelContainer.new()
	var sb := UiKit.box(UiKit.MAGENTA, Color(0.12, 0.02, 0.1, 0.7), 24, 2, 14)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiKit.glow_label("THE AFTERDARK", 44, UiKit.MAGENTA))
	var l := UiKit.label("The night is not over. Fly on and the swarm keeps growing, and every %d seconds a boss returns stronger than before. Your win is already banked; everything after it is score." % Defs.NIGHT_BOSS_EVERY, 32, Color(0.95, 0.9, 1.0, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(740, 0)
	v.add_child(l)
	body.add_child(p)
	UiKit.pop_in(p, 0.5, 20)
	var go := UiKit.button("INTO THE AFTERDARK", UiKit.MAGENTA, 46, true)
	go.custom_minimum_size = Vector2(0, 140)
	go.pressed.connect(func():
		chose.emit(true)
		close())
	body.add_child(go)
	var pulse := go.create_tween().set_loops()
	pulse.tween_property(go, "modulate", Color(1.3, 1.2, 1.3), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(go, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
	var end := UiKit.button("BANK THE DAWN", UiKit.GOLD, 38)
	end.pressed.connect(func():
		chose.emit(false)
		close())
	body.add_child(end)
	Sfx.play("mission", 0.9)
