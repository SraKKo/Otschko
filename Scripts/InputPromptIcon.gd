extends Control
## Native vector prompt: no font dependency for PlayStation symbols.
var family := "keyboard":
	set(value):
		family = value
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var color := Color(0.35, 0.88, 0.48)
	if family == "keyboard":
		draw_style_box(_key_style(), Rect2(Vector2(1, 6), size - Vector2(2, 12)))
		draw_line(Vector2(10, 17), Vector2(10, 23), Color.WHITE, 2)
		draw_line(Vector2(10, 23), Vector2(size.x - 10, 23), Color.WHITE, 2)
		draw_line(Vector2(size.x - 10, 17), Vector2(size.x - 10, 23), Color.WHITE, 2)
		return
	if family == "playstation": color = Color(0.45, 0.72, 1)
	if family == "switch": color = Color(1, 0.45, 0.4)
	if family == "generic": color = Color(0.9, 0.85, 0.5)
	draw_circle(center, 15, Color(0.06, 0.09, 0.08))
	draw_arc(center, 15, 0, TAU, 40, color, 2, true)
	if family == "playstation":
		draw_line(center - Vector2(6, 6), center + Vector2(6, 6), color, 3, true)
		draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), color, 3, true)
	else:
		var text := "B" if family == "switch" else ("1" if family == "generic" else "A")
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func _key_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.17, 0.15)
	style.border_color = Color(0.8, 0.85, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
