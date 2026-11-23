extends Control

var profile: Dictionary
var key_edit: LineEdit
var status: Label
var buttons: Array[Button] = []
var busy := false
var pending_key := ""

func _ready() -> void:
	profile = UserSession.primary.duplicate()
	var bg := TextureRect.new()
	bg.texture = preload("res://Sprites/MainMenuBg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 620
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.065)
	style.border_color = Color(0.7, 0.59, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "LOC_LICENSE_GAME"
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	var account := Label.new()
	account.text = Localization.message("LOC_PROFILE_NAME", {"name": profile.get("name", "")})
	column.add_child(account)
	key_edit = LineEdit.new()
	key_edit.placeholder_text = "LOC_LICENSE_ENTER"
	key_edit.max_length = 64
	key_edit.custom_minimum_size.y = 40
	key_edit.text_submitted.connect(func(_key: String): _activate())
	column.add_child(key_edit)
	_button(column, "LOC_LICENSE_ACTIVATE", _activate)
	_button(column, "LOC_LICENSE_BUY", _buy)
	_button(column, "LOC_LICENSE_RETRY", _verify)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(540, 62)
	status.add_theme_color_override("font_color", Color(1, 0.8, 0.42))
	column.add_child(status)
	_button(column, "LOC_CHANGE_PROFILE", UserSession.change_user, false)
	UserSession.network_changed.connect(_network_changed)
	ControllerInput.refresh_context()
	call_deferred("_verify")

func _button(column: VBoxContainer, text: String, action: Callable, requires_network: bool = true) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	column.add_child(button)
	if requires_network: buttons.append(button)

func _set_busy(value: bool) -> void:
	busy = value
	for button in buttons: button.disabled = value
	key_edit.editable = not value
	ControllerInput.refresh_context()

func _verify() -> void:
	if busy or profile.is_empty(): return
	_set_busy(true)
	status.text = "LOC_LICENSE_CHECKING"
	var result := await LicenseService.check(profile)
	if is_inside_tree(): _complete(result)

func _buy() -> void:
	if busy or profile.is_empty(): return
	_set_busy(true)
	if pending_key.is_empty():
		status.text = "LOC_LICENSE_FETCH"
		var result: Dictionary = await LicenseService.client.new_license()
		if not is_inside_tree(): return
		if result.get("ok") != true or str(result.get("license", "")).is_empty():
			_complete(result)
			return
		pending_key = str(result.license)
	key_edit.text = pending_key
	await _activate_key(pending_key)

func _activate() -> void:
	if busy or profile.is_empty(): return
	var key := key_edit.text.strip_edges().to_upper()
	if key.is_empty():
		status.text = "LOC_LICENSE_REQUIRED"
		return
	_set_busy(true)
	await _activate_key(key)

func _activate_key(key: String) -> void:
	status.text = "LOC_LICENSE_ACTIVATING"
	var result := await LicenseService.activate(profile, key)
	if is_inside_tree(): _complete(result)

func _network_changed(online: bool) -> void:
	if online and not busy: _verify()

func _complete(result: Dictionary) -> void:
	_set_busy(false)
	if result.get("allowed") == true and UserSession.primary == profile:
		LicenseService.authorized = true
		LicenseService.offline = result.get("offline", false)
		UserSession._finish_login()
		return
	status.text = LicenseService.message(result)
	if not UserSession.online:
		status.text = Localization.message("LOC_LICENSE_ERROR_OFFLINE", {"message": tr(status.text)})
