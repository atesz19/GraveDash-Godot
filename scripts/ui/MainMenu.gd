extends Node
## MainMenu — live 3D graveyard backdrop, shop, soul wallet, start transition.

const THEME_PATH := "res://resources/ui/GraveDashTheme.tres"
const SAVE_KEY_LUCKY_CHARM := "shop_lucky_charm"
const COST_SKIN := 50
const COST_MAGNET := 120
const COST_DEMO := 25

@onready var menu_world: Node3D = $MenuWorld
@onready var chrome: Control = %Chrome
@onready var main_panel: Control = %MainPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var shop_panel: Control = %ShopPanel
@onready var high_score_label: Label = %HighScoreLabel
@onready var mult_label: Label = %MultLabel
@onready var mission_box: VBoxContainer = %MissionBox
@onready var mission_labels: Array[Label] = [%Mission1, %Mission2, %Mission3]
@onready var soul_wallet_label: Label = %SoulWalletLabel
@onready var start_button: Button = %StartButton
@onready var shop_button: Button = %ShopButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var settings_back: Button = %SettingsBackButton
@onready var shop_balance_label: Label = %ShopBalanceLabel
@onready var shop_status_label: Label = %ShopStatusLabel
@onready var shop_back: Button = %ShopBackButton
@onready var buy_skin_button: Button = %BuySkinButton
@onready var buy_magnet_button: Button = %BuyMagnetButton
@onready var buy_demo_button: Button = %BuyDemoButton
@onready var demo_desc: Label = %DemoDesc
@onready var transition_fade: ColorRect = %TransitionFade
@onready var vignette_top: ColorRect = %VignetteTop
@onready var vignette_bottom: ColorRect = %VignetteBottom

var _starting: bool = false
var _ui_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.state = GameManager.State.MENU
	_refresh_highscore()
	_refresh_multiplier()
	_refresh_missions()
	_refresh_souls()
	_sync_audio_toggles()
	_show_main()
	_refresh_shop_state()
	start_button.pressed.connect(_on_start)
	shop_button.pressed.connect(_on_shop)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	settings_back.pressed.connect(_on_settings_back)
	shop_back.pressed.connect(_on_shop_back)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	buy_skin_button.pressed.connect(_on_buy_skin)
	buy_magnet_button.pressed.connect(_on_buy_magnet)
	buy_demo_button.pressed.connect(_on_buy_demo)
	if not ScoreManager.highscore_changed.is_connected(_on_highscore_changed):
		ScoreManager.highscore_changed.connect(_on_highscore_changed)
	if not ScoreManager.total_souls_changed.is_connected(_on_total_souls_changed):
		ScoreManager.total_souls_changed.connect(_on_total_souls_changed)
	if MissionManager:
		if not MissionManager.multiplier_changed.is_connected(_on_multiplier_changed):
			MissionManager.multiplier_changed.connect(_on_multiplier_changed)
		if not MissionManager.missions_changed.is_connected(_on_missions_changed):
			MissionManager.missions_changed.connect(_on_missions_changed)
	start_button.grab_focus()


func _refresh_highscore() -> void:
	high_score_label.text = "High Score  %d" % ScoreManager.highscore


func _refresh_multiplier() -> void:
	var mult: int = MissionManager.get_multiplier() if MissionManager else 1
	if mult_label:
		mult_label.text = "Multiplier  ×%d" % mult


func _refresh_missions() -> void:
	if MissionManager == null:
		return
	var missions: Array[Dictionary] = MissionManager.get_active_missions()
	for i in mission_labels.size():
		var label: Label = mission_labels[i]
		if label == null:
			continue
		if i < missions.size():
			label.visible = true
			label.text = MissionManager.format_mission_line(missions[i])
		else:
			label.visible = false


func _on_multiplier_changed(_value: int) -> void:
	_refresh_multiplier()


func _on_missions_changed() -> void:
	_refresh_missions()


func _refresh_souls() -> void:
	var total: int = ScoreManager.total_souls
	soul_wallet_label.text = "Souls  %d" % total
	if shop_balance_label:
		shop_balance_label.text = "Balance  %d souls" % total


func _on_highscore_changed(value: int) -> void:
	high_score_label.text = "High Score  %d" % value


func _on_total_souls_changed(value: int) -> void:
	soul_wallet_label.text = "Souls  %d" % value
	if shop_balance_label:
		shop_balance_label.text = "Balance  %d souls" % value
	_refresh_shop_state()


func _sync_audio_toggles() -> void:
	music_toggle.set_pressed_no_signal(AudioManager.is_music_muted())
	sfx_toggle.set_pressed_no_signal(AudioManager.is_sfx_muted())
	_update_toggle_text()


func _update_toggle_text() -> void:
	music_toggle.text = "Music: Muted" if music_toggle.button_pressed else "Music: On"
	sfx_toggle.text = "SFX: Muted" if sfx_toggle.button_pressed else "SFX: On"


func _show_main() -> void:
	main_panel.visible = true
	settings_panel.visible = false
	shop_panel.visible = false


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	_set_menu_interactive(false)
	_play_start_transition()


func _set_menu_interactive(enabled: bool) -> void:
	start_button.disabled = not enabled
	shop_button.disabled = not enabled
	settings_button.disabled = not enabled
	quit_button.disabled = not enabled


func _play_start_transition() -> void:
	## 1) Witch starts running + camera dolly (MenuWorld).
	if menu_world != null and menu_world.has_method("begin_start_transition"):
		menu_world.call("begin_start_transition")
	## 2) Menu chrome flies out / fades.
	if _ui_tween != null and _ui_tween.is_valid():
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.set_parallel(true)
	_ui_tween.tween_property(chrome, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	_ui_tween.tween_property(chrome, "position:x", -120.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if vignette_top:
		_ui_tween.tween_property(vignette_top, "modulate:a", 0.0, 0.5)
	if vignette_bottom:
		_ui_tween.tween_property(vignette_bottom, "modulate:a", 0.0, 0.5)
	## 3) Soft fade to black, then load gameplay.
	_ui_tween.set_parallel(false)
	_ui_tween.tween_property(transition_fade, "color:a", 1.0, 0.45).set_delay(0.55)
	_ui_tween.tween_callback(_finish_start_transition)


func _finish_start_transition() -> void:
	GameManager.go_to_gameplay()


func _on_shop() -> void:
	main_panel.visible = false
	settings_panel.visible = false
	shop_panel.visible = true
	_refresh_souls()
	_refresh_shop_state()
	shop_status_label.text = ""
	shop_back.grab_focus()


func _on_shop_back() -> void:
	shop_panel.visible = false
	main_panel.visible = true
	shop_button.grab_focus()


func _on_settings() -> void:
	main_panel.visible = false
	shop_panel.visible = false
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


func _refresh_shop_state() -> void:
	var owned: bool = bool(SaveSystem.get_value(SAVE_KEY_LUCKY_CHARM, false))
	if owned:
		buy_demo_button.disabled = true
		buy_demo_button.text = "Owned"
		demo_desc.text = "Demo unlock — owned"
	else:
		buy_demo_button.disabled = ScoreManager.total_souls < COST_DEMO
		buy_demo_button.text = "%d ✦" % COST_DEMO
		demo_desc.text = "Demo unlock — spends %d souls" % COST_DEMO
	## Placeholder rows stay visible with costs; buying stubs.
	buy_skin_button.disabled = false
	buy_skin_button.text = "%d ✦" % COST_SKIN
	buy_magnet_button.disabled = false
	buy_magnet_button.text = "%d ✦" % COST_MAGNET


func _on_buy_skin() -> void:
	shop_status_label.text = "Ashen Skin — coming soon (%d souls)" % COST_SKIN


func _on_buy_magnet() -> void:
	shop_status_label.text = "Magnet upgrade — coming soon (%d souls)" % COST_MAGNET


func _on_buy_demo() -> void:
	var owned: bool = bool(SaveSystem.get_value(SAVE_KEY_LUCKY_CHARM, false))
	if owned:
		shop_status_label.text = "Lucky Charm already owned."
		return
	if not ScoreManager.spend_souls(COST_DEMO):
		shop_status_label.text = "Not enough souls."
		return
	SaveSystem.set_value(SAVE_KEY_LUCKY_CHARM, true)
	SaveSystem.save()
	shop_status_label.text = "Lucky Charm unlocked!"
	_refresh_shop_state()
