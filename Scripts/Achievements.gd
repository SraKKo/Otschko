extends Node

const Catalog := preload("res://Scripts/AchievementCatalog.gd")
var notice: PanelContainer
var notice_title: Label
var notice_timer: Timer
var pending: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 105
	add_child(layer)
	notice = PanelContainer.new()
	layer.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notice.offset_left = -390
	notice.offset_right = -24
	notice.offset_top = 58
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.hide()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.10, 0.075, 0.98)
	style.border_color = Color(0.83, 0.68, 0.36)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	notice.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(content)
	var heading := Label.new()
	heading.text = "LOC_ACH_UNLOCKED"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.95, 0.79, 0.45))
	content.add_child(heading)
	notice_title = Label.new()
	notice_title.add_theme_font_size_override("font_size", 22)
	content.add_child(notice_title)
	notice_timer = Timer.new()
	notice_timer.one_shot = true
	add_child(notice_timer)
	notice_timer.timeout.connect(_next_notice)
	inventory.equipped_changed.connect(_check_equipped)
	UserSession.logged_out.connect(func(_reason: String): clear_notices())

func grant(id: String) -> void:
	if UserSession.primary.is_empty() or not LicenseService.authorized: return
	var before := Catalog.earned(UserSession.progress)
	if not record_event(UserSession.progress, id): return
	UserSession.save_progress()
	publish_new(before)
	UserSession.progress_changed.emit()

func record_event(data: Dictionary, id: String) -> bool:
	var unlocked := Catalog.event_ids(data)
	if id in unlocked: return false
	for entry: Dictionary in Catalog.ENTRIES:
		if entry.id == id and Catalog.is_event(entry):
			unlocked.append(id)
			data["achievements"] = Catalog.event_ids({"achievements": unlocked})
			return true
	return false

func publish_new(before: Array[String]) -> void:
	var earned := Catalog.earned(UserSession.progress)
	for entry: Dictionary in Catalog.ENTRIES:
		if entry.id in earned and entry.id not in before:
			pending.append(entry.name)
	if notice_timer.is_stopped(): _next_notice()

func clear_notices() -> void:
	pending.clear()
	notice_timer.stop()
	notice.hide()

func _next_notice() -> void:
	if pending.is_empty():
		notice.hide()
		return
	notice_title.text = pending.pop_front()
	notice.show()
	notice_timer.start(2.8)

func _check_equipped() -> void:
	var distinct := {}
	for trinket: TrinketDef in inventory.equipped:
		distinct[trinket.id] = true
	if distinct.size() >= 3: grant("three_trinkets")
