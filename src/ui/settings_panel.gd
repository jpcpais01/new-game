class_name SettingsPanel
extends Modal
## Sound, music, vibration, shake and damage-number toggles.

const ROWS := [
	["sound", "SOUND"], ["music", "MUSIC"], ["haptics", "VIBRATION"], ["shake", "SCREEN SHAKE"],
	["numbers", "DAMAGE NUMBERS"],
]

var extra_buttons: Array = []


func build() -> void:
	accent = UiKit.MAGENTA
	heading("SETTINGS", UiKit.MAGENTA, 60)
	for r in ROWS:
		body.add_child(_toggle(r[0], r[1]))
	for b in extra_buttons:
		body.add_child(b)
	var done := UiKit.button("DONE", UiKit.MAGENTA, 42, true)
	done.pressed.connect(close)
	body.add_child(done)


func _toggle(key: String, text: String) -> Button:
	var b := UiKit.button(text, UiKit.CYAN, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var state := UiKit.label("", 36, UiKit.CYAN, UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT)
	state.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state.offset_right = -36
	b.add_child(state)
	var refresh := func():
		var on := Save.setting(key)
		state.text = "ON" if on else "OFF"
		state.add_theme_color_override("font_color", UiKit.GREEN if on else Color(0.6, 0.55, 0.7))
		b.modulate = Color(1, 1, 1) if on else Color(0.75, 0.75, 0.85)
	refresh.call()
	b.pressed.connect(func():
		Save.set_setting(key, not Save.setting(key))
		Sfx.apply_settings()
		refresh.call())
	return b
