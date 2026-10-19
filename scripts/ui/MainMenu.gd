extends Control
## MainMenu — boot scene. Start → gameplay, Settings (audio mutes), Quit.

const THEME_PATH := "res://resources/ui/GraveDashTheme.tres"

@onready var high_score_label: Label = %HighScoreLabel
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: Control = %SettingsPanel
@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var settings_back: Button = %SettingsBackButton
@onready var main_panel: Control = %MainPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_res := load(THEME_PATH) as Theme
	if theme_res:
		theme = theme_res
	_refresh_highscore()
	_sync_audio_toggles()
	settings_panel.visible = false
	main_panel.visible = true
	start_button.pressed.connect(_on_start)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	settings_back.pressed.connect(_on_settings_back)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	if not ScoreManager.highscore_changed.is_connected(_on_highscore_changed):
		ScoreManager.highscore_changed.connect(_on_highscore_changed)
	start_button.grab_focus()


func _refresh_highscore() -> void:
	high_score_label.text = "High Score  %d" % ScoreManager.highscore


func _on_highscore_changed(value: int) -> void:
	high_score_label.text = "High Score  %d" % value


func _sync_audio_toggles() -> void:
	## Pressed = muted.
	music_toggle.set_pressed_no_signal(AudioManager.is_music_muted())
	sfx_toggle.set_pressed_no_signal(AudioManager.is_sfx_muted())
	_update_toggle_text()


func _update_toggle_text() -> void:
	music_toggle.text = "Music: Muted" if music_toggle.button_pressed else "Music: On"
	sfx_toggle.text = "SFX: Muted" if sfx_toggle.button_pressed else "SFX: On"


func _on_start() -> void:
	GameManager.go_to_gameplay()


func _on_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	_sync_audio_toggles()
	settings_back.grab_focus()


func _on_settings_back() -> void:
	settings_panel.visible = false
	main_panel.visible = true
	settings_button.grab_focus()


func _on_music_toggled(pressed: bool) -> void:
	AudioManager.set_music_muted(pressed)
	_update_toggle_text()


func _on_sfx_toggled(pressed: bool) -> void:
	AudioManager.set_sfx_muted(pressed)
	_update_toggle_text()


func _on_quit() -> void:
	get_tree().quit()
