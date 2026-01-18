extends Node

@export var freeze_ticks := 6
var ticks_left := 0

func on_round_start(_game: Node) -> void:
	# reset na start każdej rundy
	ticks_left = freeze_ticks

func modify_timer_step(_game: Node, step: int) -> int:
	# jeśli timer ma "stanąć" – zwracamy 0
	if ticks_left > 0:
		ticks_left -= 1
		return 0

	# normalnie przepuszczamy step (ważne: szanujemy step z innych efektów)
	return step
