extends Control

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func show_menu():
	visible = true

func hide_menu():
	visible = false

func _on_resume_button_pressed():
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().paused = false
	hide_menu()

func _on_quit_button_pressed():
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
