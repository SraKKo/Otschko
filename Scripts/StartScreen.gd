extends Node2D

@onready var PlayButton: Button = $Play
@onready var SettingsButton: Button = $Settings
@onready var QuitButton: Button = $Quit
@onready var crt_rect: ColorRect = $CRT/Rect
@onready var credits_button : Button = $Credits


func _ready() -> void:
	SettingsMenager.apply_crt(crt_rect)
	MusicPlayer.play_with_fade_in(preload("res://Sounds/Music/MainMenu1.ogg"), 1.25)

func _on_play_pressed():
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/GameProper.tscn")
	
func _on_settings_pressed() -> void:
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_credits_pressed() -> void:
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/Credits.tscn")
