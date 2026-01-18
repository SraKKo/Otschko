extends Node
class_name SFXPlayer

var player := AudioStreamPlayer.new()

func _ready():
	add_child(player)
	player.bus = "SFX"

func play(stream: AudioStream, volume_db := 0.0):
	if stream == null:
		return
	player.volume_db = volume_db
	player.stream = stream
	player.play()
