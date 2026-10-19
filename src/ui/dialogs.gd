class_name Dialogs
extends RefCounted
## Builders for the shared dialogs: settings, stats and patch notes.

const NOTES_PATH := "res://PATCH_NOTES.md"


static func settings(on_tutorial: Callable = Callable()) -> Modal:
	var m := Modal.new(880)
	m.add_title("SETTINGS")
	m.content.add_child(_toggle_row("sound", "Sound effects", "sound"))
	m.content.add_child(_toggle_row("music", "Music", "music"))
	m.content.add_child(_toggle_row("vibrate", "Vibration", "haptics"))
	if on_tutorial.is_valid():
		m.add_button("HOW TO PLAY", "ghost", func():
			m.close()
			on_tutorial.call(), Vector2(560, 120))
	var credits := m.add_text("Prisma v%s\nMade with care by Claude, for João." % ProjectSettings.get_setting("application/config/version"), 30)
	credits.modulate.a = 0.7
	m.add_button("DONE", "primary", m.close)
	return m


static func _toggle_row(icon_name: String, caption: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	var ic := TextureRect.new()
	ic.texture = Art.icon(icon_name)
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = Color(1, 1, 1, 0.85)
	row.add_child(ic)
	var l := UiKit.label(caption, 44, PrismPalette.TEXT, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := UiKit.button("", "teal", Vector2(210, 112))
	var refresh := func():
		var on := Save.setting(key)
		b.text = "ON" if on else "OFF"
		b.kind = "teal" if on else "ghost"
		b.apply_kind()
		b.add_theme_font_size_override("font_size", 44)
	refresh.call()
	b.pressed.connect(func():
		Save.set_setting(key, not Save.setting(key))
		Sfx.apply_settings()
		if key == "haptics" and Save.setting(key):
			Sfx.haptic(30, 0.7)
		refresh.call())
	row.add_child(b)
	return row


static func stats() -> Modal:
	var m := Modal.new(920)
	m.add_title("STATS")
	var games := Save.stat("games")
	var avg := 0 if games == 0 else Save.stat("total_score") / games
	var items := [
		["Best score", UiKit.format_score(int(Save.data.best)), PrismPalette.GOLD],
		["Games", UiKit.format_score(games), PrismPalette.ACCENT],
		["Average", UiKit.format_score(avg), PrismPalette.ACCENT],
		["Best combo", str(Save.stat("best_combo")), PrismPalette.gem(2)],
		["Lines cleared", UiKit.format_score(Save.stat("lines")), PrismPalette.gem(4)],
		["Prism lines", UiKit.format_score(Save.stat("prisms")), PrismPalette.gem(6)],
		["Perfect clears", str(Save.stat("perfects")), PrismPalette.gem(3)],
		["Daily streak", str(int(Save.data.daily_streak)), PrismPalette.gem(1)],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	for it in items:
		var c := UiKit.chip(it[0], it[1], it[2])
		c.custom_minimum_size = Vector2(380, 0)
		grid.add_child(c)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	m.content.add_child(cc)
	m.add_button("DONE", "primary", m.close)
	return m


static func whats_new() -> Modal:
	var m := Modal.new(940)
	m.add_title("WHAT'S NEW")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(840, 1000)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.text = notes_bbcode()
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(rtl)
	m.content.add_child(scroll)
	m.add_button("NICE!", "primary", m.close)
	Save.data.seen_notes = latest_notes_id()
	Save.save_data()
	return m


static func _read_notes() -> String:
	if not FileAccess.file_exists(NOTES_PATH):
		return ""
	return FileAccess.get_file_as_string(NOTES_PATH)


## The first "## " heading identifies the newest group of notes.
static func latest_notes_id() -> String:
	for line in _read_notes().split("\n"):
		if line.begins_with("## "):
			return line.substr(3).strip_edges()
	return ""


static func has_unseen_notes() -> bool:
	var id := latest_notes_id()
	return id != "" and id != str(Save.data.seen_notes)


static func notes_bbcode() -> String:
	var out := ""
	var in_comment := false
	for raw in _read_notes().split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("<!--"):
			in_comment = not line.ends_with("-->")
			continue
		if in_comment:
			if line.ends_with("-->"):
				in_comment = false
			continue
		if line.begins_with("# ") or line == "":
			continue
		if line.begins_with("## "):
			out += "\n[font_size=42][b][color=#ffd166]%s[/color][/b][/font_size]\n[font_size=12] [/font_size]\n" % line.substr(3).replace("[", "[lb]")
		elif line.begins_with("- "):
			var body := line.substr(2).replace("[", "[lb]")
			body = _bold(body)
			out += "[color=#b9b2e8]•[/color]  %s\n[font_size=12] [/font_size]\n" % body
	return out.strip_edges()


static func _bold(s: String) -> String:
	# **text** -> [b]text[/b]
	var parts := s.split("**")
	var out := ""
	for i in parts.size():
		out += ("[b]%s[/b]" % parts[i]) if i % 2 == 1 else parts[i]
	return out
