extends CanvasLayer

@onready var vbox: VBoxContainer = $Column

@export var icon_size: Vector2 = Vector2(48, 48)


func _ready():
	inventory.equipped_changed.connect(refresh)
	refresh()


func refresh():
	# usuń wszystkie ikonki
	for c in vbox.get_children():
		c.queue_free()

	# dodaj ikonki tylko dla equipped trinketów
	for def in inventory.equipped:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = icon_size
		icon.texture = def.icon
		icon.tooltip_text = def.display_name + "\n" + def.description

		vbox.add_child(icon)
