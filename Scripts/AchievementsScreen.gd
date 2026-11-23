extends Control

const Catalog := preload("res://Scripts/AchievementCatalog.gd")
const GOLD := Color(0.97, 0.81, 0.43)
const MUTED := Color(0.76, 0.84, 0.80)

var summary: Label
var rows: GridContainer

func _ready() -> void:
	if UserSession.primary.is_empty() or not LicenseService.authorized:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/StartScreen.tscn")
		return
	var background := TextureRect.new()
	background.texture = preload("res://Sprites/MainMenuBg.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.modulate = Color(0.38, 0.43, 0.40)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := _label("LOC_ACHIEVEMENTS", 29, GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var back := Button.new()
	back.name = "Back"
	back.text = "LOC_BACK_MENU"
	back.custom_minimum_size = Vector2(186, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn"))
	header.add_child(back)
	summary = _label("", 17, MUTED)
	summary.name = "Summary"
	summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(summary)

	rows = GridContainer.new()
	rows.name = "Entries"
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 12)
	rows.add_theme_constant_override("v_separation", 8)
	content.add_child(rows)
	UserSession.progress_changed.connect(_refresh)
	Localization.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var data := UserSession.progress
	var earned := Catalog.earned(data)
	summary.text = Localization.message("LOC_ACH_TOTAL", {"name": UserSession.primary.name, "current": earned.size(), "total": Catalog.ENTRIES.size()})
	for entry: Dictionary in Catalog.ENTRIES:
		_add_entry(entry, entry.id in earned, data, earned.size())

func _add_entry(entry: Dictionary, unlocked: bool, data: Dictionary, total: int) -> void:
	var hidden: bool = entry.get("hidden", false) and not unlocked
	var card := PanelContainer.new()
	card.name = entry.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 77
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.18, 0.12) if unlocked else Color(0.035, 0.10, 0.07)
	style.border_color = GOLD if unlocked else Color(0.24, 0.38, 0.31)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	rows.add_child(card)

	var details := VBoxContainer.new()
	card.add_child(details)
	var header := HBoxContainer.new()
	details.add_child(header)
	var title := _label("LOC_ACH_HIDDEN" if hidden else str(entry.name), 19, GOLD if unlocked else Color.WHITE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var status := "LOC_ACH_EARNED" if unlocked else "LOC_ACH_LOCKED"
	if entry.has("stat"):
		status = "%d / %d" % [Catalog.value(entry, data), int(entry.target)]
	elif entry.id == "completion":
		status = "%d / %d" % [mini(total, Catalog.ENTRIES.size() - 1), Catalog.ENTRIES.size() - 1]
	var state := _label(status, 15, GOLD if unlocked else MUTED)
	state.name = "State"
	header.add_child(state)
	var description := _label("LOC_ACH_SECRET" if hidden else str(entry.description), 15, MUTED)
	description.name = "Description"
	details.add_child(description)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
