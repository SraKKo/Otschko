extends Control

@onready var back_button : Button = $Back

func _ready() -> void:
	SettingsMenager.apply_crt($CRT/Rect)

func _on_back_pressed() -> void:
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
