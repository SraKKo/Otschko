extends Control

@onready var fullscreen_toggle: CheckButton = $Fullscreen
@onready var master_slider: HSlider = $Master
@onready var music_slider: HSlider = $Music
@onready var sfx_slider: HSlider = $SFX
@onready var back_button: Button = $Back
@onready var crt_rect: ColorRect = $CRT/Rect
@onready var crt_toggle: CheckButton = $CRTFilter



func _ready():
	SettingsMenager.apply_crt(crt_rect)

	crt_toggle.button_pressed = SettingsMenager.crt_enabled
	crt_toggle.toggled.connect(_on_crt_filter_toggled)


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
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
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
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")

func _on_crt_filter_toggled(_toggled_on: bool) -> void:
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	SettingsMenager.crt_enabled = true
	SettingsMenager.save_settings()
