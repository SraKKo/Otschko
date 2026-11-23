extends Control
var column: VBoxContainer
var name_edit: LineEdit
var error_label: Label
var last_reason := ""
var input_label: Label
var language_picker: OptionButton

func _ready() -> void:
	if UserSession.legacy_check:
		if "--verify-controllers" in OS.get_cmdline_user_args():
			get_tree().call_deferred("change_scene_to_file", "res://Scenes/StartScreen.tscn")
		return
	if not LicenseService.site_allowed():
		UserSession.phase = "site_blocked"
		var message := Label.new()
		message.text = "LOC_SITE_BLOCKED"
		message.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message.add_theme_font_size_override("font_size", 26)
		add_child(message)
		return
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = preload("res://Sprites/MainMenuBg.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var panel := PanelContainer.new()
	panel.position = Vector2(236, 80)
	panel.size = Vector2(680, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.065, 0.98)
	style.border_color = Color(0.7, 0.59, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	language_picker = SettingsMenager.language_selector()
	language_picker.position = Vector2(944, 80)
	language_picker.size = Vector2(180, 40)
	add_child(language_picker)
	Localization.changed.connect(_refresh_input_label)
	if UserSession.phase == "choose": show_profiles()
	else: show_press()

func _clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func _label(text: String, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	column.add_child(label)
	return label

func _button(text: String, id: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	column.add_child(button)
	return button

func show_press() -> void:
	if column == null: return
	_clear()
	language_picker.hide()
	_label("OTSHCKO!", 38)
	_label("LOC_PRESS_ANY", 28)
	_label("LOC_PRIMARY_CLAIM", 18)
	_label("LOC_LOCAL_PROFILES", 17)
	_button("LOC_CONTINUE", "Continue", func(): pass)
	ControllerInput.refresh_context()

func show_profiles() -> void:
	if column == null: return
	_clear()
	language_picker.show()
	_label("LOC_CHOOSE_PROFILE", 32)
	input_label = _label("", 17)
	input_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_refresh_input_label()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 166
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for profile in UserSession.profiles:
		var button := Button.new()
		button.name = "Profile_" + str(profile.id)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = str(profile.name)
		button.custom_minimum_size.y = 42
		var id := str(profile.id)
		button.pressed.connect(func(): UserSession.login(id))
		list.add_child(button)
	name_edit = LineEdit.new()
	name_edit.name = "NewProfileName"
	name_edit.placeholder_text = "LOC_NEW_PROFILE"
	name_edit.max_length = 24
	name_edit.custom_minimum_size.y = 42
	column.add_child(name_edit)
	name_edit.text_submitted.connect(func(_text: String): _create())
	_button("LOC_CREATE_PROFILE", "CreateProfile", _create)
	error_label = _label("", 16)
	error_label.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	ControllerInput.refresh_context()

func _refresh_input_label() -> void:
	if is_instance_valid(input_label):
		input_label.text = Localization.message("LOC_SESSION_PRIMARY_DEVICE", {"device": UserSession.device_description(UserSession.pending_device)})

func _create() -> void:
	var error := UserSession.create_profile(name_edit.text)
	if not error.is_empty():
		error_label.text = error
		return
	show_profiles()
