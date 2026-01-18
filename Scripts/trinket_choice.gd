extends Control
class_name TrinketChoice

signal chosen(trinket: TrinketDef)

@onready var b1: TextureButton = $Panel/HBox/Option1
@onready var b2: TextureButton = $Panel/HBox/Option2
@onready var b3: TextureButton = $Panel/HBox/Option3

var options: Array[TrinketDef] = []

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	b1.pressed.connect(func(): _pick(0))
	b2.pressed.connect(func(): _pick(1))
	b3.pressed.connect(func(): _pick(2))

func open():
	# pauza gry (zatrzyma timer itd.)
	get_tree().paused = true
	visible = true

	_roll_3_unique()
	_apply_icons()

func close():
	visible = false
	get_tree().paused = false

func _roll_3_unique():
	options.clear()

	# bierzemy pulę z TrinketDb
	var pool: Array[TrinketDef] = TrinketDb.trinkets.duplicate()
	pool = pool.filter(func(t): return t != null)

	# jeśli chcesz wykluczyć już posiadane/equipped, odfiltruj tu:
	pool = pool.filter(func(t): return not inventory.owned.has(t))  # jeśli masz owned

	pool.shuffle()

	for i in range(min(3, pool.size())):
		options.append(pool[i])

func _apply_icons():
	_set_button_def(b1, options[0] if options.size() > 0 else null)
	_set_button_def(b2, options[1] if options.size() > 1 else null)
	_set_button_def(b3, options[2] if options.size() > 2 else null)

func _set_button_def(btn: TextureButton, def: TrinketDef):
	if def == null:
		btn.visible = false
		return
	btn.visible = true
	btn.texture_normal = def.icon
	# opcjonalnie: tooltip
	btn.tooltip_text = def.display_name + "\n" + def.description

func _pick(idx: int):
	SfxPlayer.play(preload("res://Sounds/SFX/ClickTrinket.ogg"))
	if idx < 0 or idx >= options.size():
		return
	var def := options[idx]

	emit_signal("chosen", def)
	close()
