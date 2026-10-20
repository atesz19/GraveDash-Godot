extends CanvasLayer
## PauseOverlay — Esc pause panel with Resume / Main Menu + missions.

const THEME_PATH := "res://resources/ui/GraveDashTheme.tres"

@onready var root: Control = $Root
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var panel: PanelContainer = %PausePanel
@onready var mult_label: Label = %MultLabel
@onready var mission_labels: Array[Label] = [%Mission1, %Mission2, %Mission3]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_res := load(THEME_PATH) as Theme
	if theme_res and panel:
		panel.theme = theme_res
	root.visible = false
	resume_button.pressed.connect(_on_resume)
	menu_button.pressed.connect(_on_menu)
	GameManager.game_paused.connect(_on_paused)
	GameManager.game_resumed.connect(_on_resumed)
	GameManager.game_started.connect(_on_resumed)
	GameManager.game_over.connect(_on_resumed)


func _on_paused() -> void:
	_refresh_progress()
	root.visible = true
	resume_button.grab_focus()


func _on_resumed() -> void:
	root.visible = false


func _refresh_progress() -> void:
	var mult: int = MissionManager.get_multiplier() if MissionManager else 1
	if mult_label:
		mult_label.text = "Multiplier  ×%d" % mult
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


func _on_resume() -> void:
	if AudioManager:
		AudioManager.play_ui_click()
	GameManager.resume_game()


func _on_menu() -> void:
	if AudioManager:
		AudioManager.play_ui_click()
	GameManager.return_to_menu()
