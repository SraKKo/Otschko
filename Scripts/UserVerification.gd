extends "res://Scripts/ControllerVerification.gd"
var user_phase := "write"

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://users-" + name + ".png")

func choose(id: String) -> void:
	var button := get_tree().current_scene.find_child("Profile_" + id, true, false) as Button
	if button == null:
		check(false, "Profile choice exists: " + id)
		return
	await click(button)

func new_round(win: bool) -> void:
	var game := get_tree().current_scene
	game.change_bet(10)
	game.on_deal()
	game.round_timer.stop()
	game.player_cards = [0, 9] if win else [1, 2]
	game.dealer_cards = [8, 7]
	game.check_winner()
	await get_tree().create_timer(1.1).timeout
	game.round_timer.stop()

func run() -> void:
	# Exercise real UI at a steady rate instead of injecting thousands of clicks per second.
	Engine.max_fps = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--verify-users="): user_phase = argument.trim_prefix("--verify-users=")
		if argument.begins_with("--user-output="): output = argument.trim_prefix("--user-output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MINIMIZE_DISABLED, true)
	await frames()
	check(get_tree().current_scene.name == "ProfileGate", "Startup opens press-any-button screen")
	check(UserSession.primary.is_empty(), "Startup never silently assigns a profile")
	check(UserSession.profiles[0].name == "Ala" and UserSession.profiles[1].name == "Olek", "Two initial profiles are available")
	if user_phase == "read":
		check(UserSession.profiles.size() == 3, "Created profile survives a separate process restart")
		await key(KEY_ENTER)
		await choose("ala")
		check(UserSession.progress.rounds == 1 and UserSession.progress.wins == 1 and UserSession.progress.best_bankroll == 510, "Ala data survives restart")
		await click(get_tree().current_scene.get_node("ChangeUser"))
		await choose("olek")
		check(UserSession.progress.rounds == 1 and UserSession.progress.wins == 0 and UserSession.progress.best_bankroll == 500, "Olek data remains separate after restart")
		await click(get_tree().current_scene.get_node("ChangeUser"))
		var marta: Dictionary = UserSession.profiles[2]
		await choose(str(marta.id))
		check(UserSession.primary.name == "Marta" and UserSession.progress.rounds == 0, "New profile reloads with its own data")
		check(UserSession.online, "Network simulation resets to online in a new process")
	else:
		await screenshot("press")
		await mouse(8)
		check(UserSession.phase == "press", "Mouse movement alone cannot claim ownership")
		ControllerInput.device_names[12] = "Xbox Wireless Controller"
		await joy(JOY_BUTTON_START, 12)
		check(UserSession.phase == "choose" and UserSession.pending_device == "pad:12", "First button remembers its controller")
		await screenshot("profiles")
		await joy(JOY_BUTTON_B, 12)
		check(UserSession.phase == "press", "Profile Cancel returns to device-claim screen")
		await joy(JOY_BUTTON_START, 12)
		await joy(JOY_BUTTON_A, 12)
		check(UserSession.primary.get("id") == "ala" and UserSession.primary_device == "pad:12", "Profile login binds the starting controller to Ala")
		check(UserSession.badge.visible and "Ala" in UserSession.badge.text, "User name is visible in menu")
		check(get_tree().current_scene.has_node("ChangeUser"), "Menu provides Change User")
		await screenshot("ala-menu")
		await joy(JOY_BUTTON_A, 12)
		check(get_tree().current_scene.scene_file_path == "res://Scenes/GameProper.tscn", "Primary controller starts the game")
		check(UserSession.badge.visible and "Ala" in UserSession.badge.text, "User name remains visible in gameplay")
		await new_round(true)
		check(UserSession.progress.rounds == 1 and UserSession.progress.wins == 1, "Real round completion updates active profile")
		var saved_path := UserSession.profiles_dir.path_join("ala.json")
		check(FileAccess.file_exists(saved_path), "Round result is saved locally immediately")
		var saved_before := FileAccess.get_file_as_string(saved_path)
		await key(KEY_F9)
		check(not UserSession.online and UserSession.network_notice.visible, "F9 displays readable offline notice")
		check(not get_tree().paused, "Offline mode does not pause gameplay")
		check(FileAccess.get_file_as_string(saved_path) == saved_before, "Network loss does not alter saved data")
		await screenshot("offline")
		await key(KEY_F9)
		check(UserSession.online and not UserSession.network_notice.visible, "Restored network automatically hides notice")
		await key(KEY_F9)
		ControllerInput.device_names[13] = "DualSense Wireless Controller"
		await joy(JOY_BUTTON_RIGHT_SHOULDER, 13)
		check(UserSession.secondary.get("name") == "Olek" and UserSession.secondary.get("device") == "pad:13", "Another device joins Olek as player two")
		check(not get_tree().paused, "Player two joins without stopping the game")
		check("Gracz 2: Olek" in UserSession.badge.text, "Second user is named on screen")
		check(get_tree().current_scene.bet == 0, "Join button does not accidentally perform gameplay action")
		await screenshot("second-player")
		await joy(JOY_BUTTON_RIGHT_SHOULDER, 13)
		check(UserSession.secondary.get("device") == "pad:13", "Repeated input does not duplicate the additional user")
		check(UserSession.primary_device == "pad:12", "Last-input changes do not replace primary ownership")
		await key(KEY_F10)
		check(UserSession.primary_device == "pad:12" and ControllerInput.family == "keyboard", "Mouse-keyboard switching preserves the original owner")
		await key(KEY_ESCAPE)
		check(get_tree().paused, "Pause is active before platform logout")
		inventory.add_trinket(TrinketDb.trinkets[0])
		await key(KEY_F8)
		check(get_tree().current_scene.name == "StartScreen" and UserSession.phase == "menu", "F8 returns immediately to the logged-out main menu")
		check(UserSession.primary.is_empty() and UserSession.secondary.is_empty() and UserSession.primary_device.is_empty(), "Logout clears primary, device and additional user")
		check(not get_tree().paused and not UserSession.badge.visible, "Logout removes identity and clears pause")
		check(inventory.owned.is_empty(), "Logout clears the previous user's session inventory")
		check(FileAccess.get_file_as_string(saved_path) == saved_before, "Offline logout preserves the saved result")
		await screenshot("logged-out-menu")
		check(get_tree().current_scene.get_node("ChangeUser").text == "LOC_SIGN_IN", "Logged-out menu offers sign-in")
		await click(get_tree().current_scene.get_node("Settings"))
		check(get_tree().current_scene.name == "Settings" and UserSession.primary.is_empty(), "Settings remain accessible after logout")
		await key(KEY_ESCAPE)
		check(get_tree().current_scene.name == "StartScreen" and UserSession.primary.is_empty(), "Settings return to logged-out menu")
		await key(KEY_ENTER)
		check(get_tree().current_scene.name == "ProfileGate" and UserSession.primary.is_empty(), "Play requires profile selection after logout")
		check(UserSession.pending_device == "keyboard", "Keyboard can own the next session")
		await key(KEY_DOWN)
		await key(KEY_ENTER)
		check(UserSession.primary.get("id") == "olek", "Keyboard selects Olek")
		check(UserSession.progress.rounds == 0 and UserSession.progress.wins == 0, "Olek does not inherit Ala's data")
		await joy(JOY_BUTTON_RIGHT_SHOULDER, 13)
		check(UserSession.secondary.get("name") == "Ala" and UserSession.secondary.get("device") == "pad:13", "Pad joins a session owned by the keyboard")
		check(UserSession.primary_device == "keyboard" and not get_tree().paused, "Second pad preserves keyboard ownership and uninterrupted play")
		await click(get_tree().current_scene.get_node("Play"))
		await new_round(false)
		check(UserSession.progress.rounds == 1 and UserSession.progress.wins == 0, "Olek records his own result")
		check(FileAccess.get_file_as_string(saved_path) == saved_before, "Saving Olek does not overwrite Ala")
		check(not UserSession.online, "Profiles can be used while offline")
		var game := get_tree().current_scene
		game.toggle_pause()
		await frames()
		await click(game.pause_menu.get_node("QuitButton"))
		await click(get_tree().current_scene.get_node("ChangeUser"))
		check(UserSession.phase == "choose" and UserSession.primary.is_empty(), "Change User opens profile selection")
		await choose("ala")
		check(UserSession.progress.rounds == 1 and UserSession.progress.wins == 1, "Changing back reloads Ala's own data")
		await click(get_tree().current_scene.get_node("ChangeUser"))
		var gate := get_tree().current_scene
		gate.name_edit.text = "   "
		await click(gate.find_child("CreateProfile", true, false))
		check(not gate.error_label.text.is_empty() and UserSession.profiles.size() == 2, "Empty profile names are rejected")
		gate.name_edit.text = "aLA"
		await click(gate.find_child("CreateProfile", true, false))
		check(UserSession.profiles.size() == 2, "Duplicate names are rejected case-insensitively")
		gate.name_edit.text = "Marta"
		await click(gate.find_child("CreateProfile", true, false))
		check(UserSession.profiles.size() == 3 and UserSession.profiles[2].name == "Marta", "Real creation form adds a third profile")
		await choose(str(UserSession.profiles[2].id))
		check(UserSession.primary.get("name") == "Marta" and UserSession.progress.rounds == 0, "New profile starts with separate clean progress")
		check(UserSession.primary_device == "keyboard", "New profile retains the initiating device")
		await key(KEY_F9)
		check(UserSession.online and not UserSession.network_notice.visible, "Network restoration works after user changes")
		await screenshot("marta-menu")
	await key(KEY_F8)
	check(UserSession.primary.is_empty(), "Final logout succeeds")
	check(get_tree().current_scene.name == "StartScreen", "Logout from menu stays in main menu")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "phase": user_phase, "build": "debug" if OS.is_debug_build() else "release", "checks": results, "physical_controllers": Input.get_connected_joypads(), "profiles_dir": UserSession.profiles_dir}, "\t"))
	file.close()
	print("USER_CHECK_" + ("FAILED" if failed else "OK") + ": " + str(results.size()))
	if failed: get_tree().quit(1)
	else: await PCRuntime._quit_cleanly()
