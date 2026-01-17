extends Control

@onready var fullscreen_toggle: CheckButton = $Fullscreen
@onready var master_slider: HSlider = $Master
@onready var music_slider: HSlider = $Music
@onready var sfx_slider: HSlider = $SFX
@onready var back_button: Button = $Back

func _ready():
	# wypełnij UI wartościami z SettingsManager
	fullscreen_toggle.button_pressed = SettingsMenager.fullscreen
	master_slider.value = SettingsMenager.master
	music_slider.value = SettingsMenager.music
	sfx_slider.value = SettingsMenager.sfx

	# podepnij zmiany
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	back_button.pressed.connect(_on_back_pressed)

func _on_fullscreen_toggled(on: bool):
	SettingsMenager.apply_fullscreen(on)
	SettingsMenager.save_settings()

func _on_master_changed(v: float):
	SettingsMenager.master = v
	SettingsMenager.apply_bus_volume("Master", v)
	SettingsMenager.save_settings()

func _on_music_changed(v: float):
	SettingsMenager.music = v
	SettingsMenager.apply_bus_volume("Music", v)
	SettingsMenager.save_settings()

func _on_sfx_changed(v: float):
	SettingsMenager.sfx = v
	SettingsMenager.apply_bus_volume("SFX", v)
	SettingsMenager.save_settings()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
