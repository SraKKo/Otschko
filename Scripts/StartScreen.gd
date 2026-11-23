extends Node2D

@onready var PlayButton: Button = $Play
@onready var SettingsButton: Button = $Settings
@onready var QuitButton: Button = $Quit
@onready var crt_rect: ColorRect = $CRT/Rect
@onready var credits_button : Button = $Credits
var stats: Label


func _ready() -> void:
	var change := Button.new()
	change.name = "ChangeUser"
	change.text = "LOC_SIGN_IN" if UserSession.primary.is_empty() else "LOC_CHANGE_USER"
	change.position = Vector2(24, 548)
	change.size = Vector2(310, 44)
	change.pressed.connect(UserSession.change_user)
	add_child(change)
	stats = Label.new()
	stats.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	stats.position = Vector2(24, 240)
	stats.add_theme_font_size_override("font_size", 19)
	stats.add_theme_constant_override("outline_size", 5)
	stats.add_theme_color_override("font_outline_color", Color.BLACK)
	_refresh_stats()
	UserSession.progress_changed.connect(_refresh_stats)
	Localization.changed.connect(_refresh_stats)
	add_child(stats)
	RoamingSave.attach_menu(self)
	if LicenseService.authorized:
		var achievements_button := Button.new()
		achievements_button.name = "Achievements"
		achievements_button.text = "LOC_ACHIEVEMENTS"
		achievements_button.position = Vector2(826, 436)
		achievements_button.size = Vector2(300, 44)
		achievements_button.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/AchievementsScreen.tscn"))
		add_child(achievements_button)
	if not LicenseService.active_key().is_empty():
		var license_button := Button.new()
		license_button.name = "LicenseDetails"
		license_button.text = "LOC_LICENSE"
		license_button.position = Vector2(826, 492)
		license_button.size = Vector2(300, 44)
		license_button.pressed.connect(RoamingSave.show_license_details)
		add_child(license_button)
	SettingsMenager.apply_crt(crt_rect)
	MusicPlayer.play_with_fade_in(preload("res://Sounds/Music/MainMenu1.ogg"), 1.25)

func _on_play_pressed():
	if UserSession.primary.is_empty() or not (LicenseService.authorized or UserSession.legacy_check):
		UserSession.change_user()
		return
	inventory.clear()
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/GameProper.tscn")
	
func _on_settings_pressed() -> void:
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_credits_pressed() -> void:
	SfxPlayer.play(preload("res://Sounds/SFX/ClickButton.ogg"))
	get_tree().change_scene_to_file("res://Scenes/Credits.tscn")

func _refresh_stats() -> void:
	if UserSession.primary.is_empty():
		stats.text = tr("LOC_MENU_SIGN_OUT")
	else:
		var progress := UserSession.progress
		var rounds := int(progress.rounds)
		stats.text = Localization.message("LOC_MENU_STATS", {
			"name": UserSession.primary.name,
			"rounds": Localization.rounds_played(rounds),
			"wins": Localization.number(progress.wins),
			"stage": Localization.number(progress.best_stage),
			"chips": Localization.number(progress.best_bankroll),
		})
