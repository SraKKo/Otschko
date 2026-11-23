extends Node
## A Save click sends one snapshot; independent changes still require conflict resolution.
signal state_changed
const Catalog := preload("res://Scripts/AchievementCatalog.gd")
const Integrity := preload("res://Scripts/SaveIntegrity.gd")
var integrity_warning := ""
var client: Node
var profile_id := ""
var record: Dictionary = {}
var remote: Dictionary = {}
var status := "LOC_SIGNED_OUT"
var status_args := {}
var busy := false
var disabled := false
var generation := 0
var queued_sync := false
var status_label: Label
var modal: Control
var modal_column: VBoxContainer
var modal_scene: Node
var modal_was_paused := false
var last_get_usec := 0
var premium_busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.changed.connect(_refresh_status_label)
	client = preload("res://Scripts/DswCloudClient.gd").new()
	add_child(client)
	var cloud_test := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-cloud="): cloud_test = true
		if arg.begins_with("--verify-users=") or arg.begins_with("--verify-localization="): disabled = true
	if cloud_test:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--cloud-api-url=http://127.0.0.1:"):
				client.base_url = arg.trim_prefix("--cloud-api-url=")
		if not client.base_url.begins_with("http://127.0.0.1:"):
			disabled = true
	disabled = disabled or UserSession.legacy_check
	UserSession.logged_in.connect(_login)
	UserSession.logged_out.connect(_logout)
	UserSession.network_changed.connect(_network)

static func decision(local_exists: bool, base: int, dirty: bool, found: bool, version: int) -> String:
	if not found: return "upload" if local_exists else "new"
	if not local_exists: return "download"
	if version < base: return "older_server"
	if version > base: return "conflict" if dirty else "download"
	return "upload" if dirty else "same"

func _path(id: String) -> String:
	return UserSession.profiles_dir.path_join(id + ".json")

func _normalized(data: Dictionary) -> Dictionary:
	var result := UserSession._empty_progress()
	for key in result: result[key] = int(data.get(key, result[key]))
	var unlocks := Catalog.event_ids(data)
	if not unlocks.is_empty(): result["achievements"] = unlocks
	return result

func _payload(data: Dictionary) -> String:
	return JSON.stringify({"schema": 1, "progress": _normalized(data)}, "", true)

func read_local_progress(id: String) -> Dictionary:
	integrity_warning = ""
	var saved := _read_record(id)
	return saved.get("progress", {}).duplicate(true)

func _read_record(id: String) -> Dictionary:
	var path := _path(id)
	if not FileAccess.file_exists(path): return {}
	var envelope: Variant = UserSession._read_json(path)
	var saved := Integrity.unseal("save:" + id, envelope)
	if saved.is_empty():
		var legacy := not FileAccess.file_exists(path + ".signed") and envelope is Dictionary
		if legacy and envelope.get("version") == 1 and not envelope.has("hmac") and not envelope.has("payload") and envelope.get("progress") is Dictionary and envelope.get("profile_id", id) == id:
			saved = envelope
			if not _persist(saved, id): return {}
		else:
			_reject_save(id)
			return {}
	if not saved.get("progress") is Dictionary:
		_reject_save(id)
		return {}
	saved["progress"] = _normalized(saved.progress)
	if not saved.get("cloud") is Dictionary:
		saved["cloud"] = {"base_version": 0, "dirty": true, "revision": 1, "saved_at": Time.get_unix_time_from_system(), "server_updated_at": 0}
	var user := str(client.cloud_user(id))
	if saved.cloud.get("user_key", "") != user:
		# A version belongs to a specific remote key and cannot be reused for a name-based key.
		saved.cloud["user_key"] = user
		saved.cloud["base_version"] = 0
		saved.cloud["dirty"] = true
	return saved

func _reject_save(id: String) -> void:
	if not integrity_warning.is_empty(): return
	integrity_warning = "LOC_CLOUD_WARNING"
	print("[ANTI-CHEAT] Odrzucono podpis lokalnego zapisu profilu ", id)

func _persist(data: Dictionary, id: String = "") -> bool:
	var target := profile_id if id.is_empty() else id
	var path := _path(target)
	if not UserSession._write_json(path, Integrity.seal("save:" + target, data)): return false
	if not FileAccess.file_exists(path + ".signed"):
		return UserSession._write_json(path + ".signed", {"version": 2})
	return true

func save_local(id: String, progress: Dictionary) -> bool:
	var current := _read_record(id)
	# Logout must not recreate an empty local save after Clear Local.
	if current.is_empty() and progress == UserSession._empty_progress(): return true
	if not current.is_empty() and current.progress == progress: return true
	var meta: Dictionary = current.get("cloud", {"base_version": 0, "revision": 0, "server_updated_at": 0}).duplicate()
	meta["user_key"] = str(client.cloud_user(id))
	meta["dirty"] = true
	meta["revision"] = int(meta.get("revision", 0)) + 1
	meta["saved_at"] = Time.get_unix_time_from_system()
	var next := {"version": 1, "profile_id": id, "progress": progress.duplicate(true), "cloud": meta}
	if not _persist(next, id): return false
	if id == profile_id:
		record = next
		_set_status("LOC_CLOUD_DIRTY" if UserSession.online else "LOC_CLOUD_DIRTY_OFFLINE")
	return true

func _login(profile: Dictionary) -> void:
	generation += 1
	profile_id = str(profile.id)
	record = _read_record(profile_id)
	remote.clear()
	last_get_usec = 0
	if LicenseService.verification_mode: disabled = true
	if disabled:
		_set_status("LOC_CLOUD_DISABLED")
		return
	call_deferred("synchronize")

func _logout(_reason: String) -> void:
	generation += 1
	close_modal(false)
	profile_id = ""
	integrity_warning = ""
	record.clear()
	remote.clear()
	queued_sync = false
	_set_status("LOC_SIGNED_OUT")

func _network(online: bool) -> void:
	if disabled or profile_id.is_empty(): return
	if online: call_deferred("synchronize")
	else: _set_status("LOC_CLOUD_OFFLINE")

func _set_status(value: String, args: Dictionary = {}) -> void:
	status = value
	status_args = args
	_refresh_status_label()
	state_changed.emit()

func _refresh_status_label() -> void:
	if is_instance_valid(status_label):
		status_label.text = Localization.message("LOC_CLOUD_STATUS", {"message": Localization.message(status, status_args)})

func synchronize() -> void:
	if disabled or profile_id.is_empty(): return
	if not UserSession.online:
		_set_status("LOC_CLOUD_OFFLINE")
		return
	if busy:
		queued_sync = true
		return
	busy = true
	var token := generation
	var id := profile_id
	_set_status("LOC_CLOUD_LOADING")
	var result: Dictionary = await client.load_save(id)
	busy = false
	if token != generation or id != profile_id:
		if queued_sync:
			queued_sync = false
			call_deferred("synchronize")
		return
	queued_sync = false
	last_get_usec = Time.get_ticks_usec()
	if not result.get("ok", false):
		_set_status("LOC_CLOUD_NO_CONNECTION")
		return
	if result.get("found", false) and not _valid_remote(result):
		_set_status("LOC_CLOUD_BAD_REMOTE")
		return
	remote = result.duplicate(true)
	record = _read_record(id)
	if not remote.get("found", false) and record.is_empty() and str(client.cloud_user(id)) != id:
		# Read-only fallback for existing saves created under the former random ID.
		busy = true
		var legacy: Dictionary = await client.load_legacy_save(id)
		busy = false
		if token != generation or id != profile_id:
			if queued_sync:
				queued_sync = false
				call_deferred("synchronize")
			return
		queued_sync = false
		if legacy.get("ok", false) and legacy.get("found", false) and _valid_remote(legacy):
			# New progress may have appeared while the legacy read was in flight.
			record = _read_record(id)
			if record.is_empty():
				_adopt(legacy, true)
				return
	var action := decision(not record.is_empty(), int(record.get("cloud", {}).get("base_version", 0)), bool(record.get("cloud", {}).get("dirty", false)), bool(remote.get("found", false)), int(remote.get("version", 0)))
	match action:
		"new": _set_status("LOC_CLOUD_NO_SAVE")
		"same": _set_status("LOC_CLOUD_IN_SYNC")
		"download": _adopt(remote)
		"upload":
			if not remote.get("found", false):
				record.cloud.base_version = 0
				record.cloud.dirty = true
				_persist(record)
			_set_status("LOC_CLOUD_WAIT_UPLOAD")
		"conflict":
			_set_status("LOC_CLOUD_CONFLICT")
			show_conflict()
		"older_server": _set_status("LOC_CLOUD_OLDER")

func _valid_remote(data: Dictionary) -> bool:
	if not data.get("value") is String or int(data.get("version", 0)) < 1: return false
	var decoded: Variant = JSON.parse_string(data.value)
	if not decoded is Dictionary or decoded.get("schema") != 1 or not decoded.get("progress") is Dictionary: return false
	for key in UserSession._empty_progress():
		var value: Variant = decoded.progress.get(key)
		if not (value is int or value is float) or float(value) < 0 or not is_finite(float(value)): return false
	return true

func _adopt(data: Dictionary, legacy_import: bool = false) -> void:
	if not _valid_remote(data):
		_set_status("LOC_CLOUD_BAD_SAVE")
		return
	var decoded: Dictionary = JSON.parse_string(data.value)
	var progress := _normalized(decoded.progress)
	var gains := _merge_event_achievements(progress, record.get("progress", {}))
	var next := {"version": 1, "profile_id": profile_id, "progress": progress, "cloud": {"user_key": str(client.cloud_user(profile_id)), "base_version": 0 if legacy_import else int(data.version), "dirty": legacy_import or gains, "revision": int(record.get("cloud", {}).get("revision", 0)) + 1, "saved_at": Time.get_unix_time_from_system(), "server_updated_at": int(data.get("updatedAt", 0))}}
	if not _persist(next):
		_set_status("LOC_CLOUD_DOWNLOAD_ERROR")
		return
	record = next
	UserSession.progress = progress.duplicate(true)
	UserSession.progress_changed.emit()
	if legacy_import:
		_set_status("LOC_CLOUD_RESTORED_LEGACY")
	elif gains:
		_set_status("LOC_CLOUD_MERGED")
	else:
		_set_status("LOC_CLOUD_SYNC_VERSION", {"version": data.version})

func attach_menu(scene: Node) -> void:
	var button := Button.new()
	button.name = "CloudSave"
	button.text = "LOC_CLOUD_MENU"
	button.position = Vector2(24, 492)
	button.size = Vector2(310, 44)
	button.disabled = UserSession.primary.is_empty()
	button.pressed.connect(show_panel)
	scene.add_child(button)
	status_label = Label.new()
	status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status_label.position = Vector2(24, 449)
	status_label.size = Vector2(370, 40)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	_refresh_status_label()
	scene.add_child(status_label)
	if not integrity_warning.is_empty():
		var warning := Label.new()
		warning.position = Vector2(796, 374)
		warning.custom_minimum_size.x = 330
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.text = integrity_warning
		warning.add_theme_font_size_override("font_size", 15)
		warning.add_theme_color_override("font_color", Color(1, 0.73, 0.35))
		warning.add_theme_constant_override("outline_size", 6)
		warning.add_theme_color_override("font_outline_color", Color.BLACK)
		scene.add_child(warning)

func _input(event: InputEvent) -> void:
	if is_instance_valid(modal) and event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()

func close_modal(restore_pause: bool = true) -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	ControllerInput.modal_root = null
	if restore_pause and is_instance_valid(modal_scene) and get_tree().current_scene == modal_scene and not UserSession.primary.is_empty(): get_tree().paused = modal_was_paused
	modal_scene = null
	ControllerInput.refresh_context()

func _begin_modal(title: String) -> void:
	var was_paused := modal_was_paused if is_instance_valid(modal) else get_tree().paused
	close_modal(false)
	modal_was_paused = was_paused
	modal_scene = get_tree().current_scene
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 110
	modal = Control.new()
	modal.name = "CloudDialog"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	layer.add_child(modal)
	# Free the CanvasLayer as well when replacing/closing the dialog.
	modal.tree_exited.connect(layer.queue_free)
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.75)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(blocker)
	var panel := PanelContainer.new()
	panel.position = Vector2(206, 74)
	panel.size = Vector2(740, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.065)
	style.border_color = Color(0.8, 0.67, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	modal.add_child(panel)
	modal_column = VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 12)
	panel.add_child(modal_column)
	_text(title, 28)
	ControllerInput.modal_root = modal

func _text(value: String, font_size: int = 18) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 660
	modal_column.add_child(label)

func _button(text: String, name: String, callback: Callable, unavailable: bool = false) -> void:
	var button := Button.new()
	button.name = name
	button.text = text
	button.custom_minimum_size.y = 40
	button.disabled = unavailable
	button.pressed.connect(callback)
	modal_column.add_child(button)

func _focus_modal() -> void:
	ControllerInput.refresh_context()

func _stats(data: Dictionary) -> String:
	return Localization.message("LOC_CLOUD_STATS", {
		"rounds": Localization.number(data.get("rounds", 0)),
		"wins": Localization.number(data.get("wins", 0)),
		"stage": Localization.number(data.get("best_stage", 1)),
		"chips": Localization.number(data.get("best_bankroll", 500)),
	})

func show_panel() -> void:
	if profile_id.is_empty(): return
	_begin_modal("LOC_CLOUD_MENU")
	_text(Localization.message("LOC_CLOUD_KEY", {"profile": UserSession.primary.name, "user": client.cloud_user(profile_id)}))
	_text(Localization.message(status, status_args))
	_text("LOC_CLOUD_MENU_HELP")
	_button("LOC_CLOUD_CHECK", "Sync", _sync_from_panel, busy or not UserSession.online)
	_button("LOC_CLOUD_SAVE", "SaveCloud", save_clicked, record.is_empty() or not bool(record.get("cloud", {}).get("dirty", false)) or busy or not UserSession.online)
	_button("LOC_CLOUD_CLEAR", "ClearLocal", show_clear_confirmation, record.is_empty() or busy)
	_button("LOC_PREMIUM_CHIPS", "PremiumChips", show_premium)
	_button("LOC_CLOSE", "CloseCloud", close_modal)
	_focus_modal()

func show_license_details() -> void:
	var key := LicenseService.active_key()
	if key.is_empty(): return
	_begin_modal("LOC_LICENSE_GAME")
	_text(Localization.message("LOC_PROFILE_NAME", {"name": UserSession.primary.name}))
	_text("LOC_LICENSE_OFFLINE_MODE" if LicenseService.offline else "LOC_LICENSE_VERIFIED")
	var key_display := LineEdit.new()
	key_display.text = key
	key_display.editable = false
	key_display.selecting_enabled = true
	key_display.custom_minimum_size.y = 42
	modal_column.add_child(key_display)
	_button("LOC_LICENSE_COPY", "CopyKey", func(): DisplayServer.clipboard_set(key))
	_button("LOC_CLOSE", "CloseLicense", close_modal)
	_focus_modal()

func show_premium() -> void:
	await _premium_request()

func _premium_request(amount: int = 0) -> void:
	if premium_busy or not LicenseService.authorized or profile_id.is_empty(): return
	premium_busy = true
	_begin_modal("LOC_PREMIUM_CHIPS")
	_text("LOC_PREMIUM_LOADING")
	_button("LOC_BACK", "Back", show_panel)
	_focus_modal()
	var opened := modal
	var id := profile_id
	var request_client := LicenseService.client
	var response: Dictionary
	var balance: Variant
	var message := ""
	if amount != 0:
		response = await request_client.add_premium_chips(id, amount)
		if response.get("ok") == true:
			balance = response.get("value")
		elif response.get("error") == "rejected" or response.get("httpCode") == 422:
			message = Localization.message("LOC_PREMIUM_REJECTED", {"amount": Localization.number(amount)})
	if balance == null and is_instance_valid(opened) and opened == modal:
		response = await request_client.load_premium_chips(id)
		if response.get("ok") == true:
			balance = response.get("value") if response.get("found", false) else 0
	premium_busy = false
	if not is_instance_valid(opened) or opened != modal: return
	_begin_modal("LOC_PREMIUM_CHIPS")
	_text(Localization.message("LOC_PREMIUM_BALANCE", {"chips": Localization.number(int(balance))}) if balance != null else "LOC_PREMIUM_UNAVAILABLE")
	if not message.is_empty(): _text(message)
	elif amount != 0 and balance != null: _text("LOC_PREMIUM_READ")
	_button("LOC_PREMIUM_ADD", "Add50", _premium_request.bind(50), not UserSession.online)
	if OS.is_debug_build():
		_button("LOC_PREMIUM_TEST_ADD", "Add5000", _premium_request.bind(5000), not UserSession.online)
	_button("LOC_BACK", "Back", show_panel)
	_focus_modal()

func _sync_from_panel() -> void:
	await synchronize()
	if status == "LOC_CLOUD_CONFLICT": return
	if is_instance_valid(modal): show_panel()

func save_clicked() -> void:
	if record.is_empty() and not integrity_warning.is_empty():
		_set_status("LOC_CLOUD_SIGNATURE_REFUSED")
		return
	if busy or not UserSession.online or record.is_empty() or not bool(record.cloud.get("dirty", false)): return
	var token := generation
	var id := profile_id
	if remote.is_empty():
		await synchronize()
		if token != generation or id != profile_id: return
		if remote.is_empty() or record.is_empty() or not bool(record.get("cloud", {}).get("dirty", false)): return
	if _valid_remote(remote) and int(remote.version) > int(record.cloud.base_version):
		show_conflict()
		return
	var snapshot := {"profile": profile_id, "value": _payload(record.progress), "expected": int(record.cloud.base_version), "generation": generation, "revision": int(record.cloud.revision)}
	await _send_snapshot(snapshot)

func _send_snapshot(snapshot: Dictionary) -> void:
	if busy or not UserSession.online or snapshot.generation != generation or snapshot.profile != profile_id: return
	busy = true
	_set_status("LOC_CLOUD_UPLOADING")
	close_modal()
	var result: Dictionary = await client.save_snapshot(profile_id, snapshot.value, snapshot.expected)
	busy = false
	if snapshot.generation != generation or snapshot.profile != profile_id:
		if queued_sync:
			queued_sync = false
			call_deferred("synchronize")
		return
	if result.get("ok", false) and int(result.get("version", 0)) > int(snapshot.expected):
		record = _read_record(profile_id)
		record.cloud.base_version = int(result.version)
		record.cloud.server_updated_at = int(result.get("updatedAt", 0))
		record.cloud.dirty = int(record.cloud.revision) != int(snapshot.revision)
		_persist(record)
		remote = {"ok": true, "found": true, "version": int(result.version), "value": snapshot.value, "updatedAt": int(result.get("updatedAt", 0))}
		if record.cloud.dirty:
			_set_status("LOC_CLOUD_NEWER_CHANGES")
		else:
			_set_status("LOC_CLOUD_SYNC_VERSION", {"version": result.version})
	elif result.get("error") == "version_conflict" and _valid_remote(result):
		remote = result.duplicate(true)
		remote["found"] = true
		_set_status("LOC_CLOUD_CONFLICT")
		show_conflict()
	else:
		_set_status("LOC_CLOUD_NOT_SENT")

func show_conflict() -> void:
	if not _valid_remote(remote): return
	_begin_modal("LOC_CLOUD_CONFLICT_TITLE")
	var cloud_progress: Dictionary = JSON.parse_string(remote.value).progress
	_text(Localization.message("LOC_CLOUD_LOCAL_VERSION", {"version": record.cloud.base_version, "stats": _stats(record.progress)}))
	_text(Localization.message("LOC_CLOUD_REMOTE_VERSION", {"version": remote.version, "stats": _stats(cloud_progress)}))
	_text(Localization.message("LOC_CLOUD_CONFLICT_DATES", {
		"local": Localization.date_time(int(record.cloud.get("saved_at", 0))),
		"remote": Localization.date_time(int(remote.get("updatedAt", 0)) / 1000),
	}))
	_button("LOC_CLOUD_KEEP_LOCAL", "KeepLocal", _keep_local)
	_button("LOC_CLOUD_KEEP_REMOTE", "KeepCloud", _keep_cloud)
	_button("LOC_CLOUD_LATER", "Later", close_modal)
	_focus_modal()

func _merge_event_achievements(target: Dictionary, source: Dictionary) -> bool:
	var previous := Catalog.event_ids(target)
	var combined := previous.duplicate()
	for id: String in Catalog.event_ids(source):
		if id not in combined: combined.append(id)
	if combined == previous: return false
	target["achievements"] = Catalog.event_ids({"achievements": combined})
	return true

func _keep_local() -> void:
	var next := record.duplicate(true)
	var cloud_progress: Dictionary = JSON.parse_string(remote.value).progress
	var merged := _merge_event_achievements(next.progress, cloud_progress)
	next.cloud.base_version = int(remote.version)
	next.cloud.dirty = true
	if not _persist(next): return
	record = next
	if merged:
		UserSession.progress = record.progress.duplicate(true)
		UserSession.progress_changed.emit()
	await save_clicked()

func _keep_cloud() -> void:
	if not _persist(record, profile_id + ".conflict-local"): return
	_adopt(remote)
	close_modal()

func show_clear_confirmation() -> void:
	_begin_modal("LOC_CLOUD_CLEAR_TITLE")
	_text("LOC_CLOUD_CLEAR_BODY")
	_text("LOC_CLOUD_CLEAR_RECOVERY")
	_button("LOC_CLOUD_CONFIRM_CLEAR", "ConfirmClearLocal", clear_local)
	_button("LOC_CANCEL", "CancelClear", close_modal)
	_focus_modal()

func clear_local() -> void:
	if busy or profile_id.is_empty() or record.is_empty(): return
	if not _persist(record, profile_id + ".cleared-backup"): return
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(profile_id))) != OK:
		_set_status("LOC_CLOUD_CLEAR_ERROR")
		return
	record.clear()
	UserSession.progress = UserSession._empty_progress()
	Achievements.clear_notices()
	UserSession.progress_changed.emit()
	_set_status("LOC_CLOUD_CLEARED")
	close_modal()
