extends Node
## One authority for last input, hot-plug, cursor, prompts and focus.
signal device_changed(family: String, device: int)
const PromptIcon = preload("res://Scripts/InputPromptIcon.gd")
const AXIS_DEADZONE := 0.35
const MOUSE_THRESHOLD := 3.0
var family := "keyboard"
var active_device := -1
var device_names: Dictionary = {}
var switching_enabled := true
var disconnect_notice := false
var device_label: Label
var prompt_bar: PanelContainer
var hint_label: Label
var prompt_icon: Control
var notice: Label
var focus_frame: Panel
var controls: Array[Control] = []
var context := ""
var current_scene: Node
var vibration_requests := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_actions()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for id in Input.get_connected_joypads(): device_names[id] = Input.get_joy_name(id)
	_build_overlay()
	device_changed.connect(_on_device_changed)
	_on_device_changed(family, active_device)

func _bind(action: String, key: int, button: int) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action, AXIS_DEADZONE)
	if key > 0:
		var keyboard := InputEventKey.new()
		keyboard.physical_keycode = key
		if not InputMap.action_has_event(action, keyboard): InputMap.action_add_event(action, keyboard)
	if button >= 0:
		var joy := InputEventJoypadButton.new()
		joy.device = -1
		joy.button_index = button
		if not InputMap.action_has_event(action, joy): InputMap.action_add_event(action, joy)

func _configure_actions() -> void:
	_bind("game_deal", KEY_SPACE, JOY_BUTTON_A)
	_bind("game_hit", KEY_H, JOY_BUTTON_X)
	_bind("game_hold", KEY_J, JOY_BUTTON_B)
	_bind("game_split", KEY_K, JOY_BUTTON_Y)
	_bind("bet_increase", KEY_E, JOY_BUTTON_RIGHT_SHOULDER)
	_bind("bet_decrease", KEY_Q, JOY_BUTTON_LEFT_SHOULDER)
	_bind("pause", KEY_ESCAPE, JOY_BUTTON_START)
	_bind("ui_accept", KEY_ENTER, JOY_BUTTON_A)
	_bind("ui_accept", KEY_SPACE, -1)
	_bind("ui_cancel", KEY_ESCAPE, JOY_BUTTON_B)
	for direction in ["up", "down", "left", "right"]:
		var buttons := {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT}
		_bind("ui_" + direction, 0, buttons[direction])
		InputMap.action_set_deadzone("ui_" + direction, AXIS_DEADZONE)
		var axis := InputEventJoypadMotion.new()
		axis.device = -1
		axis.axis = JOY_AXIS_LEFT_X if direction in ["left", "right"] else JOY_AXIS_LEFT_Y
		axis.axis_value = -1.0 if direction in ["left", "up"] else 1.0
		if not InputMap.action_has_event("ui_" + direction, axis): InputMap.action_add_event("ui_" + direction, axis)

func controller_family(controller_name: String) -> String:
	var text := controller_name.to_lower()
	for token in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if token in text: return "playstation"
	for token in ["nintendo", "switch", "joy-con", "joycon", "pro controller"]:
		if token in text: return "switch"
	for token in ["xbox", "xinput", "microsoft", "x-box"]:
		if token in text: return "xbox"
	return "generic"

func _input(event: InputEvent) -> void:
	if not switching_enabled or PCRuntime.benchmark: return
	if event is InputEventJoypadButton and event.pressed:
		_select_device(controller_family(str(device_names.get(event.device, Input.get_joy_name(event.device)))), event.device)
	elif event is InputEventJoypadMotion:
		# Trigger resting values and stick drift must not steal the active device.
		if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] and absf(event.axis_value) >= AXIS_DEADZONE:
			_select_device(controller_family(str(device_names.get(event.device, Input.get_joy_name(event.device)))), event.device)
	elif event is InputEventKey and event.pressed and not event.echo:
		_select_device("keyboard", -1)
	elif event is InputEventMouseButton and event.pressed:
		_select_device("keyboard", -1)
	elif event is InputEventMouseMotion and event.relative.length() >= MOUSE_THRESHOLD:
		_select_device("keyboard", -1)
	if event is InputEventKey and event.echo: return
	var scene := get_tree().current_scene
	if scene == null: return
	if event.is_action_pressed("pause") and _is_game():
		if not get_tree().paused or scene.pause_menu.visible:
			scene.toggle_pause()
			refresh_context()
			get_viewport().set_input_as_handled()
		return
	if _is_game() and get_tree().paused and event.is_action_pressed("ui_cancel") and scene.pause_menu.visible and not scene.trinket_choice.visible:
		scene.toggle_pause()
		refresh_context()
		get_viewport().set_input_as_handled()
		return
	if _is_game() and not get_tree().paused:
		var bindings := {"game_deal": "DealButton", "game_hit": "HitButton", "game_hold": "HoldButton", "game_split": "SplitButton", "bet_increase": "BetButtons/BetPlus10Button", "bet_decrease": "BetButtons/BetMinus10Button"}
		for action in bindings:
			if event.is_action_pressed(action):
				var button := scene.get_node(bindings[action]) as BaseButton
				if button.is_visible_in_tree() and not button.disabled: button.pressed.emit()
				get_viewport().set_input_as_handled()
				return
	elif event.is_action_pressed("ui_cancel") and not _is_game() and scene.name != "StartScreen":
		# Let an open resolution popup consume Cancel itself.
		var option := scene.find_child("Resolution", true, false) as OptionButton
		if option == null or not option.get_popup().visible:
			get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_ensure_focus()

func _select_device(next_family: String, device: int) -> void:
	if next_family == family and device == active_device: return
	if active_device >= 0 and active_device != device: Input.stop_joy_vibration(active_device)
	family = next_family
	active_device = device
	if disconnect_notice:
		disconnect_notice = false
		notice.visible = false
	device_changed.emit(family, active_device)

func _on_device_changed(_family: String, _device: int) -> void:
	var names := {"keyboard": "Mysz/Klawiatura", "xbox": "Pad Xbox", "playstation": "Pad PlayStation", "switch": "Pad Nintendo Switch", "generic": "Pad"}
	device_label.text = names.get(family, "Pad")
	prompt_icon.family = family
	_update_prompts()
	refresh_cursor()
	if family != "keyboard": _ensure_focus()

func _is_game() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://Scenes/GameProper.tscn"

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var next_context := "game" if _is_game() and not get_tree().paused else "menu"
	if _is_game() and get_tree().paused:
		next_context = "reward" if scene.trinket_choice.visible else "pause"
	if scene != current_scene or next_context != context:
		current_scene = scene
		context = next_context
		refresh_context()
	var focus := get_viewport().gui_get_focus_owner()
	focus_frame.visible = focus != null and focus.is_visible_in_tree() and context != "game"
	if focus_frame.visible:
		focus_frame.position = focus.get_global_rect().position - Vector2(3, 3)
		focus_frame.size = focus.get_global_rect().size + Vector2(6, 6)

func refresh_context() -> void:
	controls.clear()
	var scene := get_tree().current_scene
	if scene == null: return
	var root: Node = scene
	if _is_game():
		if not get_tree().paused:
			var owner := get_viewport().gui_get_focus_owner()
			if owner != null: owner.release_focus()
			refresh_cursor()
			_update_prompts()
			return
		root = scene.trinket_choice if scene.trinket_choice.visible else scene.pause_menu
	for node in root.find_children("*", "Control", true, false):
		if (node is BaseButton or node is HSlider) and node.is_visible_in_tree():
			if node is BaseButton and node.disabled: continue
			node.focus_mode = Control.FOCUS_ALL
			controls.append(node)
	if scene.name == "StartScreen":
		controls.assign([scene.get_node("Play"), scene.get_node("Settings"), scene.get_node("Credits"), scene.get_node("Quit")])
	elif _is_game() and scene.pause_menu.visible and not scene.trinket_choice.visible:
		controls.assign([scene.pause_menu.get_node("ResumeButton"), scene.pause_menu.get_node("QuitButton")])
	for index in range(controls.size()):
		var control := controls[index]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		if not control is HSlider and not control is OptionButton:
			control.focus_neighbor_left = control.get_path_to(previous)
			control.focus_neighbor_right = control.get_path_to(next)
	_ensure_focus()
	refresh_cursor()
	_update_prompts()

func _ensure_focus() -> void:
	if _is_game() and not get_tree().paused: return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and owner.is_visible_in_tree() and controls.has(owner): return
	if not controls.is_empty(): controls[0].grab_focus()

func refresh_cursor() -> void:
	if PCRuntime.benchmark: return
	var mode := Input.MOUSE_MODE_VISIBLE
	if family != "keyboard":
		mode = Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != mode: Input.mouse_mode = mode

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		device_names[device] = Input.get_joy_name(device)
		if disconnect_notice:
			disconnect_notice = false
			notice.visible = false
		return # Reconnection never resumes the game or steals the current input scheme.
	device_names.erase(device)
	if device != active_device or family == "keyboard": return
	Input.stop_joy_vibration(device)
	active_device = -1
	if _is_game():
		var game := get_tree().current_scene
		if not get_tree().paused: game.toggle_pause()
		disconnect_notice = true
		notice.visible = true
		refresh_context()
	else:
		_select_device("keyboard", -1)

func rumble() -> void:
	if not SettingsMenager.vibration_enabled or family == "keyboard" or active_device < 0: return
	vibration_requests += 1
	Input.start_joy_vibration(active_device, 0.35, 0.6, 0.22)

func _update_prompts() -> void:
	if hint_label == null: return
	var playing := _is_game() and not get_tree().paused
	prompt_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if playing else Control.PRESET_BOTTOM_WIDE)
	prompt_bar.offset_top = 57 if playing else -44
	prompt_bar.offset_bottom = 87 if playing else 0
	prompt_icon.custom_minimum_size = Vector2(36, 28) if playing else Vector2(44, 40)
	hint_label.add_theme_font_size_override("font_size", 14 if playing else 16)
	if _is_game() and not get_tree().paused:
		var labels := {"keyboard": "Spacja: Rozdaj   H: Dobierz   J: Pas   K: Podziel   Q/E: Zakład -/+10   Esc: Pauza", "xbox": "A: Rozdaj   X: Dobierz   B: Pas   Y: Podziel   LB/RB: Zakład -/+10   Menu: Pauza", "playstation": "Krzyżyk: Rozdaj   Kwadrat: Dobierz   Kółko: Pas   Trójkąt: Podziel   L1/R1: Zakład   Options: Pauza", "switch": "B: Rozdaj   Y: Dobierz   A: Pas   X: Podziel   L/R: Zakład -/+10   +: Pauza", "generic": "Dolny: Rozdaj   Lewy: Dobierz   Prawy: Pas   Górny: Podziel   LB/RB: Zakład   Start: Pauza"}
		hint_label.text = labels.get(family, labels.generic)
	else:
		var accept := {"keyboard": "Spacja / Enter", "xbox": "A", "playstation": "Krzyżyk", "switch": "B", "generic": "dolny przycisk"}
		var back := {"keyboard": "Esc", "xbox": "B", "playstation": "Kółko", "switch": "A", "generic": "prawy przycisk"}
		if _is_game() and get_tree().current_scene.trinket_choice.visible:
			hint_label.text = "Naciśnij %s, aby wybrać nagrodę   |   Strzałki / krzyżak / lewa gałka: Nawigacja" % accept[family]
		else:
			hint_label.text = "Naciśnij %s, aby wybrać   |   %s: Wstecz   |   Strzałki / krzyżak / lewa gałka: Nawigacja" % [accept[family], back[family]]

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	device_label = Label.new()
	device_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	device_label.offset_left = -310
	device_label.offset_right = -14
	device_label.offset_top = 8
	device_label.offset_bottom = 38
	device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	device_label.add_theme_font_size_override("font_size", 19)
	device_label.add_theme_constant_override("outline_size", 5)
	device_label.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(device_label)
	prompt_bar = PanelContainer.new()
	prompt_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_bar.offset_top = -44
	prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.04, 0.03, 0.94)
	style.content_margin_left = 12
	style.content_margin_right = 12
	prompt_bar.add_theme_stylebox_override("panel", style)
	root.add_child(prompt_bar)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	prompt_bar.add_child(row)
	prompt_icon = PromptIcon.new()
	prompt_icon.custom_minimum_size = Vector2(44, 40)
	prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(prompt_icon)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint_label)
	notice = Label.new()
	notice.text = "Podłącz kontroler lub użyj klawiatury"
	notice.position = Vector2(126, 110)
	notice.size = Vector2(900, 70)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 32)
	notice.add_theme_constant_override("outline_size", 12)
	notice.add_theme_color_override("font_outline_color", Color.BLACK)
	notice.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.visible = false
	root.add_child(notice)
	focus_frame = Panel.new()
	focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = Color(1, 0.85, 0.35)
	focus_style.set_border_width_all(3)
	focus_style.set_corner_radius_all(5)
	focus_frame.add_theme_stylebox_override("panel", focus_style)
	focus_frame.visible = false
	root.add_child(focus_frame)
