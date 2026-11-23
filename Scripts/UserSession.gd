extends Node
## Local mock platform. Primary ownership is separate from last-input-wins.
signal logged_in(profile: Dictionary)
signal logged_out(reason: String)
signal secondary_joined(profile: Dictionary)
signal session_changed
signal network_changed(online: bool)
signal progress_changed
var profiles: Array[Dictionary] = []
var primary: Dictionary = {}
var primary_device := ""
var secondary: Dictionary = {}
var pending_device := "keyboard"
var phase := "press"
var online := true
var progress: Dictionary = {}
var profiles_dir := "user://profiles"
var legacy_check := false
var storage_error := ""
var badge: Label
var network_notice: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profiles-dir="):
			profiles_dir = argument.trim_prefix("--profiles-dir=")
		if argument == "--pc-benchmark" or argument == "--verify-controllers" or argument.begins_with("--pc-verify-settings="):
			legacy_check = true
	_load_profiles()
	_build_overlay()
	Localization.changed.connect(_refresh_overlay)
	session_changed.connect(_refresh_overlay)
	network_changed.connect(func(_value: bool): _refresh_overlay())
	progress_changed.connect(_refresh_overlay)
	Input.joy_connection_changed.connect(_device_connection)
	if legacy_check:
		primary = profiles[0].duplicate()
		primary_device = "keyboard"
		progress = _empty_progress()
		phase = "logged_in"
	_refresh_overlay()

func device_for_event(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo: return "keyboard"
	if event is InputEventMouseButton and event.pressed: return "keyboard"
	if event is InputEventJoypadButton and event.pressed: return "pad:%d" % event.device
	return ""

func _input(event: InputEvent) -> void:
	if legacy_check: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			if not primary.is_empty(): logout("Platforma wylogowała użytkownika", false, true)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9:
			online = not online
			if LicenseService.simulate_network_persisted:
				_write_json(profiles_dir.path_join("simulated-network.json"), {"offline": not online})
			network_changed.emit(online)
			get_viewport().set_input_as_handled()
			return
	var device := device_for_event(event)
	if device.is_empty(): return
	if phase == "press" and primary.is_empty():
		pending_device = device
		phase = "choose"
		_select_input(event)
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("show_profiles"): scene.call_deferred("show_profiles")
		get_viewport().set_input_as_handled()
	elif not primary.is_empty() and device != primary_device and secondary.is_empty():
		# The joining button does not also deal a card or activate a menu item.
		for profile in profiles:
			if profile.id != primary.id:
				secondary = {"id": profile.id, "name": profile.name, "device": device}
				secondary_joined.emit(secondary.duplicate())
				session_changed.emit()
				get_viewport().set_input_as_handled()
				break

func _select_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var name := str(ControllerInput.device_names.get(event.device, Input.get_joy_name(event.device)))
		ControllerInput._select_device(ControllerInput.controller_family(name), event.device)
	else:
		ControllerInput._select_device("keyboard", -1)

func device_description(device: String) -> String:
	if device == "keyboard": return tr("LOC_DEVICE_KEYBOARD")
	var id := int(device.trim_prefix("pad:"))
	var name := str(ControllerInput.device_names.get(id, Input.get_joy_name(id)))
	return name if not name.is_empty() else tr("LOC_DEVICE_PAD")

func _empty_progress() -> Dictionary:
	return {"rounds": 0, "wins": 0, "best_stage": 1, "best_bankroll": 500}

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	return JSON.parse_string(file.get_as_text())

func _write_json(path: String, data: Dictionary) -> bool:
	if legacy_check: return true
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profiles_dir))
	if error != OK:
		storage_error = "LOC_PROFILE_DIR_ERROR"
		_refresh_overlay()
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		storage_error = "LOC_PROFILE_WRITE_ERROR"
		_refresh_overlay()
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		storage_error = "LOC_PROFILE_SAVE_ERROR"
		_refresh_overlay()
		return false
	storage_error = ""
	return true

func _load_profiles() -> void:
	if not legacy_check:
		var data: Variant = _read_json(profiles_dir.path_join("profiles.json"))
		if data is Dictionary and data.get("profiles") is Array:
			for entry in data.profiles:
				if entry is Dictionary and entry.get("id") is String and entry.get("name") is String:
					if entry.id.is_valid_identifier() and not entry.name.strip_edges().is_empty():
						profiles.append({"id": entry.id, "name": entry.name.left(24)})
	if profiles.is_empty():
		profiles.assign([{"id": "ala", "name": "Ala"}, {"id": "olek", "name": "Olek"}])
		if not legacy_check: _write_json(profiles_dir.path_join("profiles.json"), {"version": 1, "profiles": profiles})

func create_profile(display_name: String) -> String:
	var cleaned := display_name.strip_edges()
	if cleaned.is_empty() or cleaned.length() > 24: return "LOC_PROFILE_LENGTH"
	for character in cleaned:
		if character.unicode_at(0) < 32: return "LOC_PROFILE_CONTROL"
	for profile in profiles:
		if str(profile.name).to_lower() == cleaned.to_lower(): return "LOC_PROFILE_DUPLICATE"
	var id := "user_" + Crypto.new().generate_random_bytes(12).hex_encode()
	profiles.append({"id": id, "name": cleaned})
	if not _write_json(profiles_dir.path_join("profiles.json"), {"version": 1, "profiles": profiles}):
		profiles.pop_back()
		return storage_error
	return ""

func login(id: String) -> bool:
	if not LicenseService.site_allowed(): return false
	for profile in profiles:
		if profile.id != id: continue
		primary = profile.duplicate()
		primary_device = pending_device
		secondary.clear()
		inventory.clear()
		Global.dealer_cards.clear()
		progress = _empty_progress()
		LicenseService.begin_session()
		get_tree().paused = false
		if LicenseService.authorized:
			_finish_login()
		else:
			phase = "license"
			session_changed.emit()
			get_tree().change_scene_to_file("res://Scenes/LicenseGate.tscn")
		return true
	return false

func _finish_login() -> void:
	if primary.is_empty() or not LicenseService.authorized: return
	var saved := RoamingSave.read_local_progress(str(primary.id))
	if not saved.is_empty(): progress = saved
	phase = "logged_in"
	logged_in.emit(primary.duplicate())
	session_changed.emit()
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")

func save_progress() -> bool:
	if primary.is_empty() or not LicenseService.authorized: return false
	return RoamingSave.save_local(str(primary.id), progress)

func record_round(won: bool, stage: int, bankroll: int, natural_blackjack: bool = false) -> void:
	if primary.is_empty() or not LicenseService.authorized: return
	var previous := Achievements.Catalog.earned(progress)
	progress.rounds += 1
	if won: progress.wins += 1
	progress.best_stage = maxi(int(progress.best_stage), stage)
	progress.best_bankroll = maxi(int(progress.best_bankroll), bankroll)
	if won and natural_blackjack:
		Achievements.record_event(progress, "natural_blackjack")
	save_progress()
	Achievements.publish_new(previous)
	progress_changed.emit()

func logout(reason: String, choose_immediately: bool = false, to_menu: bool = false) -> void:
	if LicenseService.authorized: save_progress()
	LicenseService.end_session()
	primary.clear()
	primary_device = ""
	secondary.clear()
	progress.clear()
	inventory.clear()
	Global.dealer_cards.clear()
	phase = "menu" if to_menu else ("choose" if choose_immediately else "press")
	get_tree().paused = false
	ControllerInput.disconnect_notice = false
	ControllerInput.notice.visible = false
	logged_out.emit(reason)
	session_changed.emit()
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn" if to_menu else "res://Scenes/ProfileGate.tscn")

func change_user() -> void:
	pending_device = "keyboard" if ControllerInput.active_device < 0 else "pad:%d" % ControllerInput.active_device
	logout("Zmiana użytkownika", true)

func _device_connection(device: int, connected: bool) -> void:
	if not connected and secondary.get("device", "") == "pad:%d" % device:
		secondary.clear()
		session_changed.emit()

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	badge = Label.new()
	badge.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	badge.position = Vector2(260, 12)
	badge.size = Vector2(500, 28)
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_constant_override("outline_size", 5)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(badge)
	network_notice = Label.new()
	network_notice.position = Vector2(265, 37)
	network_notice.add_theme_font_size_override("font_size", 13)
	network_notice.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	network_notice.add_theme_constant_override("outline_size", 5)
	network_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	network_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(network_notice)

func _refresh_overlay() -> void:
	if badge == null: return
	badge.visible = not primary.is_empty()
	var player := str(primary.get("name", ""))
	badge.text = Localization.message("LOC_SESSION_PLAYER", {"name": player}) if secondary.is_empty() else Localization.message("LOC_SESSION_TWO_PLAYERS", {"primary": player, "secondary": secondary.name})
	network_notice.text = storage_error if not storage_error.is_empty() else ("LOC_OFFLINE_LICENSE" if is_instance_valid(LicenseService) and LicenseService.offline else "LOC_OFFLINE_LOCAL")
	network_notice.visible = not online or (is_instance_valid(LicenseService) and LicenseService.offline) or not storage_error.is_empty()
