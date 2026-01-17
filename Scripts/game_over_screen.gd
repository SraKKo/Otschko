extends Node2D
@onready var crt_rect: ColorRect = $CRT/Rect



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SettingsMenager.apply_crt(crt_rect)



func _on_quit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
