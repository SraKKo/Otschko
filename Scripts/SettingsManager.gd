extends Node
class_name SettingsManager

const PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var config_path := PATH
var language := "pl"
var resolution_index: int = 0
var vsync: bool = true
var fullscreen: bool = false
var master: float = 1.0
var music: float = 1.0
var sfx: float = 1.0
var vibration_enabled: bool = true
var crt_enabled: bool = true


func _ready():
	for arg in OS.get_cmdline_user_args():
		if OS.is_debug_build() and arg.begins_with("--settings-file="):
			config_path = arg.trim_prefix("--settings-file=")
	load_settings()
	apply_language(language)
	apply_all()

func apply_language(code: String) -> void:
	language = code if code in Localization.LANGUAGES else "pl"
	Localization.set_language(language)

func language_selector() -> OptionButton:
	var picker := OptionButton.new()
	picker.name = "Language"
	picker.add_item("LOC_LOCALE_PL")
	picker.add_item("LOC_LOCALE_EN")
	picker.select(Localization.LANGUAGES.find(language))
	picker.item_selected.connect(func(index: int):
		apply_language(Localization.LANGUAGES[index])
		save_settings())
	return picker

func apply_all():
	apply_resolution(resolution_index)
	apply_fullscreen(fullscreen)
	apply_vsync(vsync)
	apply_bus_volume("Master", master)
	apply_bus_volume("Music", music)
	apply_bus_volume("SFX", sfx)

func apply_fullscreen(on: bool):
	fullscreen = on
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		apply_resolution(resolution_index)


func apply_resolution(index: int):
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	if not fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
		var screen := DisplayServer.window_get_current_screen()
		var usable := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(usable.position + (usable.size - RESOLUTIONS[resolution_index]) / 2)

func apply_vsync(on: bool):
	vsync = on
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func apply_bus_volume(bus_name: String, linear: float):
	linear = clamp(linear, 0.0, 1.0)

	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("Missing audio bus: " + bus_name)
		return

	var db := linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, linear <= 0.001)

func save_settings():
	var cfg := ConfigFile.new()
	cfg.set_value("controller", "vibration_enabled", vibration_enabled)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "resolution_index", resolution_index)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "crt_enabled", crt_enabled)
	cfg.set_value("locale", "language", language)
	cfg.save(config_path)

func load_settings():
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return

	language = str(cfg.get_value("locale", "language", language))
	vibration_enabled = bool(cfg.get_value("controller", "vibration_enabled", vibration_enabled))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	resolution_index = clampi(int(cfg.get_value("video", "resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	master = float(cfg.get_value("audio", "master", master))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
	crt_enabled = bool(cfg.get_value("video", "crt_enabled", crt_enabled))

func apply_crt(rect: ColorRect):
	if rect == null:
		return
	rect.visible = crt_enabled
