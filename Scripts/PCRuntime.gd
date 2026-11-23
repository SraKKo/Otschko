extends Node
## PC diagnostics and repeatable benchmark. Uses monotonic wall time, including pause.
var label: Label
var last_tick: int
var window_start: int
var frames := 0
var benchmark := false
var sampling := false
var rendered_start: int
var sample_start: int
var frame_times: Array[float] = []
var output_path := "user://benchmark.json"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	label = Label.new()
	label.text = tr("LOC_FPS_PENDING")
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.position = Vector2(12, 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(label)
	last_tick = Time.get_ticks_usec()
	window_start = last_tick
	dev_log("Start gry (%s)" % ("debug" if OS.is_debug_build() else "release"))
	benchmark = "--pc-benchmark" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-output="):
			output_path = argument.trim_prefix("--benchmark-output=")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pc-verify-settings="):
			call_deferred("_verify_settings", argument.trim_prefix("--pc-verify-settings="))
	for argument in OS.get_cmdline_user_args():
		if OS.is_debug_build() and argument.begins_with("--verify-cloud="):
			var cloud_check := preload("res://Scripts/CloudVerification.gd").new()
			add_child(cloud_check)
			cloud_check.call_deferred("run")
	for argument in OS.get_cmdline_user_args():
		if OS.is_debug_build() and argument.begins_with("--verify-users="):
			var user_check := preload("res://Scripts/UserVerification.gd").new()
			add_child(user_check)
			user_check.call_deferred("run")
	if "--verify-controllers" in OS.get_cmdline_user_args():
		var verification := preload("res://Scripts/ControllerVerification.gd").new()
		add_child(verification)
		verification.call_deferred("run")
	for argument in OS.get_cmdline_user_args():
		if OS.is_debug_build() and argument.begins_with("--verify-localization="):
			var locale_check := preload("res://Scripts/LocalizationVerification.gd").new()
			add_child(locale_check)
			locale_check.call_deferred("verify", argument.trim_prefix("--verify-localization="))
	if benchmark:
		call_deferred("_prepare_benchmark")

	if OS.is_debug_build() and "--verify-drm" in OS.get_cmdline_user_args():
		var verification := preload("res://Scripts/DrmVerification.gd").new()
		add_child(verification)
		verification.call_deferred("run")

func dev_log(message: String) -> void:
	if OS.is_debug_build():
		print("[DEV] ", message)

func _input(event: InputEvent) -> void:
	if benchmark:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		SettingsMenager.apply_fullscreen(not SettingsMenager.fullscreen)
		SettingsMenager.save_settings()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := float(now - last_tick) / 1000000.0
	last_tick = now
	frames += 1
	var window_seconds := float(now - window_start) / 1000000.0
	if window_seconds >= 0.5:
		var fps := frames / window_seconds
		label.text = Localization.message("LOC_FPS", {"fps": Localization.decimal(fps, 1), "ms": Localization.decimal(1000.0 / fps, 2)})
		if benchmark:
			label.text += "  •  " + tr("LOC_BENCHMARK")
		frames = 0
		window_start = now
	if sampling:
		frame_times.append(elapsed)
		if now - sample_start >= 30000000:
			_finish_benchmark(now)

func _prepare_benchmark() -> void:
	DisplayServer.window_set_title("Blackjack - benchmark: please wait 40 seconds")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MINIMIZE_DISABLED, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MAXIMIZE_DISABLED, true)
	get_viewport().gui_disable_input = true
	# Override in memory only: the benchmark never saves player preferences.
	SettingsMenager.fullscreen = false
	SettingsMenager.apply_fullscreen(false)
	SettingsMenager.apply_resolution(1)
	SettingsMenager.apply_vsync(false)
	SettingsMenager.crt_enabled = true
	Engine.max_fps = 0
	seed(20261027)
	get_tree().change_scene_to_file("res://Scenes/GameProper.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var game := get_tree().current_scene
	game.set_process_input(false)
	# Exercise the real diagnostic paths before the measurement.
	game.change_bet(10)
	game.on_deal()
	game.round_timer.stop()
	game.player_cards = [0, 9]
	game.dealer_cards = [8, 7]
	game.check_winner()
	await get_tree().create_timer(2.0).timeout
	game.toggle_pause()
	await get_tree().create_timer(0.2, true).timeout
	game.toggle_pause()
	game.change_bet(10)
	seed(20261027)
	game.on_deal()
	game.round_timer.stop()
	# The same static dealt hand with the animated CRT shader in both builds.
	await get_tree().create_timer(5.0).timeout
	frame_times.clear()
	last_tick = Time.get_ticks_usec()
	sample_start = last_tick
	rendered_start = Engine.get_frames_drawn()
	sampling = true

func _finish_benchmark(now: int) -> void:
	sampling = false
	var seconds := float(now - sample_start) / 1000000.0
	var sorted := frame_times.duplicate()
	sorted.sort()
	var slow_count := maxi(1, int(ceil(sorted.size() * 0.01)))
	var slow_total := 0.0
	for index in range(sorted.size() - slow_count, sorted.size()):
		slow_total += sorted[index]
	var result := {
		"build": "debug" if OS.is_debug_build() else "release",
		"scene": "res://Scenes/GameProper.tscn", "duration_seconds": seconds,
		"frames": frame_times.size(), "average_fps": frame_times.size() / seconds,
		"rendered_frames": Engine.get_frames_drawn() - rendered_start,
		"window_mode": DisplayServer.window_get_mode(),
		"one_percent_low_fps": slow_count / slow_total,
		"vsync": DisplayServer.window_get_vsync_mode(), "fps_limit": Engine.max_fps,
		"window_size": str(DisplayServer.window_get_size()), "crt": true,
		"warmup_seconds": 5, "seed": 20261027,
		"engine": Engine.get_version_info().string,
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"),
		"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"os": OS.get_distribution_name(), "timestamp": Time.get_datetime_string_from_system()
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write benchmark: " + output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	await _quit_cleanly()


func _verify_settings(phase: String) -> void:
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	var crt := scene.find_child("CRTfilter", true, false) as CheckButton
	if phase == "write":
		# Use the actual menu controls and their save callbacks.
		crt.button_pressed = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://settings-crt-on.png")
		crt.button_pressed = false
		var sync := scene.find_child("VSync", true, false) as CheckButton
		sync.button_pressed = false
		var full := scene.find_child("Fullscreen", true, false) as CheckButton
		full.button_pressed = false
		var resolution := scene.find_child("Resolution", true, false) as OptionButton
		resolution.select(1)
		resolution.item_selected.emit(1)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://settings-crt-off.png")
	else:
		if SettingsMenager.crt_enabled or SettingsMenager.vsync or SettingsMenager.fullscreen or SettingsMenager.resolution_index != 1 or scene.crt_rect.visible or crt.button_pressed:
			push_error("SETTINGS_RESTART_FAILED")
			get_tree().quit(1)
			return
		for path in ["res://Scenes/StartScreen.tscn", "res://Scenes/GameProper.tscn"]:
			get_tree().change_scene_to_file(path)
			await get_tree().process_frame
			await get_tree().process_frame
			if get_tree().current_scene.get_node("CRT/Rect").visible:
				push_error("CRT_SCENE_FAILED")
				get_tree().quit(1)
				return
	print("SETTINGS_CHECK_OK: " + phase)
	await _quit_cleanly()


func _quit_cleanly() -> void:
	# Let the audio thread release Ogg playback before shutting down the engine.
	if MusicPlayer.tween != null and MusicPlayer.tween.is_valid():
		MusicPlayer.tween.kill()
	for player in [MusicPlayer.a, MusicPlayer.b, SfxPlayer.player]:
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.2, true).timeout
	get_tree().quit()
