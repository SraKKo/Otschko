extends Node
class_name SettingsManager

const PATH := "user://settings.cfg"

var fullscreen: bool = false
var master: float = 1.0
var music: float = 1.0
var sfx: float = 1.0

func _ready():
	load_settings()
	apply_all()

func apply_all():
	apply_fullscreen(fullscreen)
	apply_bus_volume("Master", master)
	apply_bus_volume("Music", music)
	apply_bus_volume("SFX", sfx)

func apply_fullscreen(on: bool):
	fullscreen = on
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


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
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.save(PATH)

func load_settings():
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return

	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	master = float(cfg.get_value("audio", "master", master))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
