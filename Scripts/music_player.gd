extends Node

@onready var a: AudioStreamPlayer = $A
@onready var b: AudioStreamPlayer = $B

var active: AudioStreamPlayer
var inactive: AudioStreamPlayer
var tween: Tween

const SILENT_DB := -60.0
const TARGET_DB := 0.0

func _ready():
	active = a
	inactive = b
	a.volume_db = SILENT_DB
	b.volume_db = SILENT_DB

# Fade-in na starcie (wywołaj raz, np. z pierwszej sceny)
func play_with_fade_in(stream: AudioStream, fade_time: float = 1.5):
	if stream == null:
		return

	# jeśli już gra ten sam utwór, tylko upewnij się że nie jest wyciszony
	if active.playing and active.stream == stream:
		_fade_to(active, TARGET_DB, fade_time)
		return

	# startujemy od zera na aktywnym
	active.stop()
	active.stream = stream
	active.volume_db = SILENT_DB
	active.play()
	_fade_to(active, TARGET_DB, fade_time)

# Crossfade przy zmianie utworu (menu->game itd.)
func play_crossfade(stream: AudioStream, fade_time: float = 1.0):
	if stream == null:
		return

	# jeśli już gra ten sam stream, nic nie rób
	if active.playing and active.stream == stream:
		return

	# przygotuj nieaktywny
	inactive.stop()
	inactive.stream = stream
	inactive.volume_db = SILENT_DB
	inactive.play()

	# zatrzymaj poprzedni tween
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.tween_property(inactive, "volume_db", TARGET_DB, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(active, "volume_db", SILENT_DB, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func ():
		active.stop()
		# zamiana ról
		var tmp = active
		active = inactive
		inactive = tmp
	)

func stop_fade_out(fade_time: float = 1.0):
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(active, "volume_db", SILENT_DB, fade_time)
	tween.finished.connect(func():
		active.stop()
	)

func _fade_to(p: AudioStreamPlayer, db: float, time: float):
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(p, "volume_db", db, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
