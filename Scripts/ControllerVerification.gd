extends Node
## Integration checks use synthesized Godot events; these do not emulate physical USB hardware.
var results: Array[Dictionary] = []
var failed := false
var output := "user://controller-check.json"

func check(condition: bool, description: String) -> void:
	results.append({"test": description, "passed": condition})
	if not condition:
		failed = true
		push_error("CONTROLLER_CHECK_FAILED: " + description)

func frames(count: int = 3) -> void:
	for index in range(count): await get_tree().process_frame

func joy(button: int, device: int = 12) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func motion(value: float, device: int = 12, axis_index: int = JOY_AXIS_RIGHT_X) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis_index
	event.axis_value = value
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.axis_value = 0.0
	Input.parse_input_event(event)
	await frames()

func mouse(amount: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(amount, 0)
	Input.parse_input_event(event)
	await frames()

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var movement := InputEventMouseMotion.new()
	movement.position = point
	movement.global_position = point
	movement.relative = Vector2(8, 0)
	get_viewport().push_input(movement, true)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.position = point
	button.global_position = point
	button.pressed = true
	get_viewport().push_input(button, true)
	await frames(1)
	button = button.duplicate()
	button.pressed = false
	get_viewport().push_input(button, true)
	await frames()

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://controller-" + name + ".png")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--controller-output="): output = arg.trim_prefix("--controller-output=")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MINIMIZE_DISABLED, true)
	await frames()
	var router := ControllerInput
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Menu starts with visible mouse")
	check(router.family == "keyboard", "Startup scheme is keyboard/mouse")
	check(router.controller_family("Xbox Wireless Controller") == "xbox", "Xbox identification")
	check(router.controller_family("DualSense Wireless Controller") == "playstation", "PlayStation identification")
	check(router.controller_family("Nintendo Switch Pro Controller") == "switch", "Nintendo identification")
	check(router.controller_family("Unrecognized USB controller") == "generic", "Unknown pad fallback")
	router.device_names[12] = "Xbox Wireless Controller"
	await motion(0.1)
	check(router.family == "keyboard", "Stick drift does not switch devices")
	await motion(0.8)
	check(router.family == "xbox" and router.active_device == 12, "Stick activates Xbox scheme")
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Pad hides menu cursor")
	check(router.prompt_icon.family == "xbox" and "Naciśnij A" in router.hint_label.text, "Xbox icon and text")
	await mouse(1)
	check(router.family == "xbox", "Mouse noise does not steal active device")
	await screenshot("xbox-menu")
	await motion(0.8, 12, JOY_AXIS_LEFT_Y)
	check(get_viewport().gui_get_focus_owner() == get_tree().current_scene.get_node("Settings"), "Left stick navigates menu on nonzero controller ID")
	await joy(JOY_BUTTON_DPAD_UP)
	await joy(JOY_BUTTON_DPAD_DOWN)
	check(get_viewport().gui_get_focus_owner() == get_tree().current_scene.get_node("Settings"), "D-pad navigates main menu")
	await joy(JOY_BUTTON_A)
	check(get_tree().current_scene.name == "Settings", "Pad opens Settings with Accept")
	await screenshot("settings")
	var settings := get_tree().current_scene
	var vibration := settings.find_child("Controllervibration", true, false) as CheckButton
	check(vibration != null, "Vibration option exists")
	var previous := SettingsMenager.vibration_enabled
	if vibration == null:
		get_tree().quit(1)
		return
	vibration.grab_focus()
	await joy(JOY_BUTTON_A)
	check(SettingsMenager.vibration_enabled != previous, "Pad toggles vibration through real menu")
	var saved := ConfigFile.new()
	saved.load(SettingsMenager.PATH)
	check(saved.get_value("controller", "vibration_enabled") == SettingsMenager.vibration_enabled, "Vibration option is persisted to settings file")
	vibration.button_pressed = previous
	var crt := settings.find_child("CRTfilter", true, false) as CheckButton
	var crt_previous := SettingsMenager.crt_enabled
	crt.grab_focus()
	await joy(JOY_BUTTON_A)
	check(SettingsMenager.crt_enabled != crt_previous and settings.crt_rect.visible == SettingsMenager.crt_enabled, "Controller toggles live CRT setting")
	crt.button_pressed = crt_previous
	await joy(JOY_BUTTON_B)
	check(get_tree().current_scene.name == "StartScreen", "Pad Cancel returns to main menu")
	await joy(JOY_BUTTON_A)
	check(get_tree().current_scene.scene_file_path == "res://Scenes/GameProper.tscn", "Pad starts gameplay")
	var game := get_tree().current_scene
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Pad hides gameplay cursor without capturing mouse")
	await click(game.get_node("BetButtons/BetPlus10Button"))
	check(game.bet == 10, "Mouse clicks gameplay bet button")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and router.family == "keyboard", "Mouse restores visible cursor during gameplay")
	await click(game.get_node("BetButtons/BetMinus10Button"))
	check(game.bet == 0, "Mouse clicks gameplay decrease button")
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.bet == 10, "Shoulder action increases bet")
	await joy(JOY_BUTTON_LEFT_SHOULDER)
	check(game.bet == 0, "Left shoulder decreases bet")
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	await joy(JOY_BUTTON_A)
	game.round_timer.stop()
	check(game.in_round and game.player_cards.size() == 2, "Pad deals cards through shared action")
	router.device_names[13] = "DualSense Wireless Controller"
	await motion(0.8, 13)
	check(router.family == "playstation" and router.prompt_icon.family == "playstation", "Live switch to PlayStation icon")
	check("Krzyżyk: Rozdaj" in router.hint_label.text, "PlayStation gameplay text")
	await screenshot("playstation-game")
	await joy(JOY_BUTTON_START, 13)
	await screenshot("playstation-pause")
	await joy(JOY_BUTTON_B, 13)
	check(not get_tree().paused, "Controller Cancel resumes from pause")
	game.player_cards = [1, 2]
	await joy(JOY_BUTTON_X, 13)
	check(game.player_cards.size() == 3, "PlayStation west button performs Hit")
	# Force a valid pair to exercise the real Split action deterministically.
	game.player_cards = [4, 17]
	game.split_button.visible = true
	await joy(JOY_BUTTON_Y, 13)
	check(game.split_active and game.player_hand1.size() == 2 and game.player_hand2.size() == 2, "North button performs Split")
	await joy(JOY_BUTTON_B, 13)
	check(game.current_hand == 2, "East button holds first split hand")
	var requests := router.vibration_requests
	SettingsMenager.vibration_enabled = true
	game.show_result("WIN")
	check(router.vibration_requests == requests + 1, "Result requests vibration when enabled")
	SettingsMenager.vibration_enabled = false
	game.show_result("WIN")
	check(router.vibration_requests == requests + 1, "Vibration disabled blocks request")
	SettingsMenager.vibration_enabled = previous
	router._on_joy_connection_changed(12, false)
	check(not get_tree().paused, "Disconnect of inactive pad does not pause")
	router._on_joy_connection_changed(13, false)
	await frames()
	check(get_tree().paused and router.notice.visible, "Active controller disconnect pauses and displays message")
	await screenshot("disconnected")
	router._on_joy_connection_changed(13, true)
	await frames()
	check(get_tree().paused and not router.notice.visible, "Reconnect hides notice and does not auto-resume")
	router.device_names[13] = "DualSense Wireless Controller"
	await joy(JOY_BUTTON_START, 13)
	check(not get_tree().paused, "Player manually resumes with controller Start")
	router._on_joy_connection_changed(13, false)
	await key(KEY_H)
	check(get_tree().paused and not router.notice.visible and router.family == "keyboard", "Keyboard fallback clears notice but keeps pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Keyboard pause shows cursor")
	await key(KEY_ESCAPE)
	check(not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape resumes with clickable mouse cursor")
	router.device_names[14] = "Nintendo Switch Pro Controller"
	await motion(0.8, 14)
	check(router.family == "switch" and "B: Rozdaj" in router.hint_label.text, "Nintendo uses its physical south button label B")
	router.switching_enabled = false
	await key(KEY_F9)
	check(router.family == "switch", "Explicit input zone lock prevents switching")
	router.switching_enabled = true
	await mouse(8)
	check(router.family == "keyboard", "Mouse movement restores keyboard scheme")
	await key(KEY_ESCAPE)
	check(get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause exposes keyboard mouse cursor")
	await screenshot("keyboard-pause")
	await key(KEY_ESCAPE)
	# Reward selection is a paused menu and must be fully controller navigable.
	game.trinket_choice.open()
	await frames()
	router.device_names[12] = "Xbox Wireless Controller"
	await motion(0.8)
	check(router.controls.size() == 3, "Reward menu exposes all choices to focus")
	var owned := inventory.owned.size()
	await joy(JOY_BUTTON_A)
	check(not game.trinket_choice.visible and inventory.owned.size() == owned + 1, "Controller accepts a reward without mouse")
	check(not get_tree().paused, "Reward selection resumes gameplay")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
	await frames()
	await mouse(8)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse returns in menu after gameplay")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "physical_controllers": Input.get_connected_joypads(), "checks": results, "method": "Synthesized Godot input events and connection callbacks, not a physical USB test"}, "\t"))
	file.close()
	print("CONTROLLER_CHECK_" + ("FAILED" if failed else "OK") + ": " + str(results.size()))
	if failed:
		get_tree().quit(1)
	else:
		await PCRuntime._quit_cleanly()
