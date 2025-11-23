extends Node2D

@onready var PlayButton: Button = $Play
@onready var SettingsButton: Button = $Settings
@onready var QuitButton: Button = $Quit

func _on_play_pressed():
	get_tree().change_scene_to_file("res://Scenes/GameProper.tscn")
	
func _on_settings_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
