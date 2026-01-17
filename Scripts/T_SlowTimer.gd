extends Node
class_name T_SlowTimer

@export var chance_to_skip_tick := 0.5  # 50%

func modify_timer_step(_game: Node, step: int) -> int:
	# zwróć 0 -> tick nic nie odejmuje (timer "wolniejszy")
	if randf() < chance_to_skip_tick:
		return 0
	return step
