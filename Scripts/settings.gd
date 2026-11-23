extends Control

@onready var crt_rect: ColorRect = $CRT/Rect

func _ready() -> void:
	SettingsMenager.apply_crt(crt_rect)
	var panel := PanelContainer.new()
	panel.position = Vector2(236, 38)
	panel.size = Vector2(680, 552)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.065, 0.97)
	style.border_color = Color(0.68, 0.57, 0.29)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 17
	style.content_margin_bottom = 17
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var title := Label.new()
	title.text = "LOC_SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	_add_row(column, "LOC_LANGUAGE", SettingsMenager.language_selector())

	var resolution := OptionButton.new()
	resolution.name = "Resolution"
	for dimensions in SettingsMenager.RESOLUTIONS:
		resolution.add_item("%d x %d" % [dimensions.x, dimensions.y])
	resolution.select(SettingsMenager.resolution_index)
	resolution.item_selected.connect(func(index: int):
		SettingsMenager.apply_resolution(index)
		SettingsMenager.save_settings())
	_add_row(column, "LOC_RESOLUTION", resolution)
	_toggle(column, "LOC_FULLSCREEN", "Fullscreen", SettingsMenager.fullscreen, func(on: bool):
		SettingsMenager.apply_fullscreen(on)
		SettingsMenager.save_settings())
	_toggle(column, "LOC_VSYNC", "VSync", SettingsMenager.vsync, func(on: bool):
		SettingsMenager.apply_vsync(on)
		SettingsMenager.save_settings())
	_toggle(column, "LOC_CRT", "CRTfilter", SettingsMenager.crt_enabled, func(on: bool):
		SettingsMenager.crt_enabled = on
		SettingsMenager.apply_crt(crt_rect)
		SettingsMenager.save_settings())
	_toggle(column, "LOC_VIBRATION", "Controllervibration", SettingsMenager.vibration_enabled, func(on: bool):
		SettingsMenager.vibration_enabled = on
		if not on:
			for device in Input.get_connected_joypads(): Input.stop_joy_vibration(device)
		SettingsMenager.save_settings())
	_volume(column, "LOC_MASTER", "Master", SettingsMenager.master)
	_volume(column, "LOC_MUSIC", "Music", SettingsMenager.music)
	_volume(column, "LOC_SFX", "SFX", SettingsMenager.sfx)
	var hint := Label.new()
	hint.text = "LOC_SETTINGS_HINT"
	hint.add_theme_font_size_override("font_size", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var back := Button.new()
	back.text = "LOC_BACK"
	back.custom_minimum_size.y = 42
	back.pressed.connect(func():
		SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
		get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn"))
	column.add_child(back)

func _add_row(parent: VBoxContainer, caption: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	control.custom_minimum_size.x = 240
	row.add_child(control)
	parent.add_child(row)

func _toggle(parent: VBoxContainer, caption: String, name_id: String, value: bool, callback: Callable) -> void:
	var button := CheckButton.new()
	button.name = name_id
	button.button_pressed = value
	button.toggled.connect(callback)
	_add_row(parent, caption, button)

func _volume(parent: VBoxContainer, caption: String, bus: String, value: float) -> void:
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.value_changed.connect(func(v: float):
		match bus:
			"Master": SettingsMenager.master = v
			"Music": SettingsMenager.music = v
			"SFX": SettingsMenager.sfx = v
		SettingsMenager.apply_bus_volume(bus, v)
		SettingsMenager.save_settings())
	_add_row(parent, caption, slider)
