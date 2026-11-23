extends "res://Scripts/ControllerVerification.gd"

func verify(phase: String) -> void:
	Engine.max_fps = 120
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--locale-reports="): directory = argument.trim_prefix("--locale-reports=")
	await frames()
	if phase == "read":
		check(SettingsMenager.language == "en" and tr("LOC_SETTINGS") == "SETTINGS", "English persists after restart")
	else:
		check(SettingsMenager.language == "pl", "A fresh config starts in Polish")
		check(Localization.number(12500) == "12 500" and Localization.decimal(1.25, 2) == "1,25", "Polish number format")
		check(Localization.date_time(0) == "01.01.1970 00:00:00", "Polish date format")
		if phase != "pseudo":
			check(Localization.rounds_played(1) == "1 rozegrana runda", "Polish singular")
			check(Localization.rounds_played(2) == "2 rozegrane rundy", "Polish plural for two")
			check(Localization.rounds_played(12) == "12 rozegranych rund", "Polish plural for twelve")
		else:
			check(TranslationServer.pseudolocalization_enabled, "Expanded-text test mode")
			check(tr("LOC_SETTINGS") != "USTAWIENIA" and "Ala" in Localization.message("LOC_PROFILE_NAME", {"name": "Ala"}), "Pseudolocalization expands text and preserves profile names")
		await key(KEY_ENTER)
		check(get_tree().current_scene.find_child("Language", true, false).is_visible_in_tree(), "Language can be selected before signing in")
		get_tree().change_scene_to_file("res://Scenes/Settings.tscn")
		await frames()
		SettingsMenager.crt_enabled = false
		var settings := get_tree().current_scene
		SettingsMenager.apply_crt(settings.get_node("CRT/Rect"))
		var picker := settings.find_child("Language", true, false) as OptionButton
		check(picker != null and picker.selected == 0, "Settings exposes the language selector")
		await screenshot_at(directory, "settings-" + ("pseudo" if phase == "pseudo" else "pl"))
		if phase != "pseudo":
			picker.select(1)
			picker.item_selected.emit(1)
			await frames()
			check(settings == get_tree().current_scene and Localization.language == "en", "Language changes in the same settings scene")
			check(tr("LOC_SETTINGS") == "SETTINGS" and "Select" in ControllerInput.hint_label.text, "Settings and controller hints switch to English")
			check(Localization.rounds_played(1) == "1 round played" and Localization.rounds_played(2) == "2 rounds played", "English plural")
			check(Localization.number(12500) == "12,500" and Localization.date_time(0) == "01/01/1970 00:00:00", "English number and date formats")
			await screenshot_at(directory, "settings-en")
		UserSession.login("ala")
		await frames()
		await screenshot_at(directory, "menu-" + phase)
		await click(get_tree().current_scene.get_node("Achievements"))
		check(get_tree().current_scene.name == "AchievementsScreen", "Achievements list opens in the selected language")
		await screenshot_at(directory, "achievements-" + phase)
		await click(get_tree().current_scene.find_child("Back", true, false))
		await click(get_tree().current_scene.get_node("Play"))
		var game := get_tree().current_scene
		check(game.scene_file_path == "res://Scenes/GameProper.tscn", "Gameplay scene opens with translated controls")
		if phase != "pseudo":
			check(game.money_label.text == "Chips: 500" and tr(game.hit_button.text) == "HIT", "English gameplay text and numeric display")
		await screenshot_at(directory, "game-" + phase)
		game.show_trinket_reward()
		await frames()
		if phase != "pseudo":
			var reward: TrinketDef = game.trinket_choice.options[0]
			check(game.trinket_choice.b1.tooltip_text.begins_with(tr(reward.display_name) + "\n"), "Reward tooltips use translated names and descriptions")
		await screenshot_at(directory, "trinket-" + phase)
		game.trinket_choice.close()
		get_tree().change_scene_to_file("res://Scenes/GameOverScreen.tscn")
		await frames()
		await screenshot_at(directory, "game-over-" + phase)
		get_tree().change_scene_to_file("res://Scenes/Credits.tscn")
		await frames()
		await screenshot_at(directory, "credits-" + phase)
		await get_tree().create_timer(1.1).timeout
	if failed:
		get_tree().quit(1)
	else:
		print("LOCALIZATION_OK: ", phase, " ", results.size(), " checks")
		await PCRuntime._quit_cleanly()

func screenshot_at(dir: String, name: String) -> void:
	if dir.is_empty(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("09-" + name + ".png"))
