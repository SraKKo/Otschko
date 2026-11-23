extends Node

var failures: Array[String] = []
var checks := 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print("DRM ", "OK " if condition else "FAIL ", message)

func frames() -> void:
	for index in range(4): await get_tree().process_frame

func scene() -> Node:
	return get_tree().current_scene

func run() -> void:
	if not LicenseService.verification_mode:
		get_tree().quit(2)
		return
	await frames()
	expect(LicenseService.host_allowed("html-classic.itch.zone"), "itch.io CDN is permitted")
	expect(not LicenseService.host_allowed("itch.io.example.com"), "Copied web build is rejected by hostname check")
	var phase := "write"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--drm-phase="): phase = arg.trim_prefix("--drm-phase=")
	if phase == "write":
		var old_progress := UserSession._empty_progress()
		old_progress.rounds = 7
		UserSession._write_json(RoamingSave._path("ala"), {"version": 1, "profile_id": "ala", "progress": old_progress})
		UserSession.login("ala")
		await frames()
		expect(scene().name == "LicenseGate" and not LicenseService.authorized, "Unlicensed profile is blocked")
		if scene().name != "LicenseGate":
			get_tree().quit(1)
			return
		var gate := scene()
		await gate._buy()
		await frames()
		expect(scene().name == "StartScreen" and LicenseService.authorized, "Purchase issues and activates a key")
		expect(UserSession.progress.rounds == 7 and FileAccess.file_exists(RoamingSave._path("ala") + ".signed"), "Previous save migrates to a signed envelope")
		var ala: Dictionary = UserSession.primary.duplicate()
		var key: String = LicenseService._cached(ala).key
		var duplicate := await LicenseService.activate(UserSession.profiles[1], key)
		expect(duplicate.get("error") == "already_activated", "Ala's key is rejected for Olek")
		var client := LicenseService.client
		var rejected: Dictionary = await client.add_premium_chips("ala", 5000)
		expect(rejected.get("httpCode") == 422, "Server refuses +5000")
		var accepted: Dictionary = await client.add_premium_chips("ala", 50)
		expect(accepted.get("ok") == true and int(accepted.get("value", 0)) == 50, "Server applies +50 without counting rejected request")
		scene()._on_play_pressed()
		await frames()
		var game := scene()
		expect(game.scene_file_path == "res://Scenes/GameProper.tscn" and game.money == 500, "Licensed profile can start the game")
		var event := InputEventKey.new()
		event.keycode = KEY_F7
		event.pressed = true
		game._input(event)
		expect(game.money == 0 and not game.integrity_notice.text.is_empty(), "F7 damages masked chips and triggers visible response")
		UserSession.record_round(true, 1, 510)
		var path := RoamingSave._path("ala")
		var data: Dictionary = UserSession._read_json(path)
		var payload: Dictionary = JSON.parse_string(data.payload)
		payload.progress["rounds"] = 9999
		data.payload = JSON.stringify(payload)
		UserSession._write_json(path, data)
		event.keycode = KEY_F9
		UserSession._input(event)
		expect(not UserSession.online, "F9 saves the offline simulation state")
	else:
		expect(not UserSession.online, "F9 survives game restart")
		UserSession.login("ala")
		await frames()
		expect(scene().name == "StartScreen" and LicenseService.authorized and LicenseService.offline, "Recently verified user can play offline")
		expect(UserSession.progress.rounds == 0 and not RoamingSave.integrity_warning.is_empty(), "Edited local save is rejected at login")
		var ala: Dictionary = UserSession.primary.duplicate()
		var key: String = LicenseService._cached(ala).key
		LicenseService._store(ala, key, int(Time.get_unix_time_from_system()) - LicenseService.GRACE_SECONDS - 1)
		var expired := await LicenseService.check(ala)
		expect(expired.get("error") == "offline_expired", "Seven-day offline authorization expires")
		UserSession.logout("Test", true)
		await frames()
		UserSession.login("olek")
		await frames()
		expect(scene().name == "LicenseGate" and not LicenseService.authorized, "Unlicensed offline user stays blocked")
	get_tree().change_scene_to_file("res://Scenes/ProfileGate.tscn")
	for player: AudioStreamPlayer in [MusicPlayer.a, MusicPlayer.b, SfxPlayer.player]:
		player.stop()
	await get_tree().create_timer(0.25).timeout
	print("DRM_RESULT ", checks, " checks / ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
