extends CanvasLayer
## PauseOverlay — Esc pause panel with Resume / Main Menu.

const THEME_PATH := "res://resources/ui/GraveDashTheme.tres"

@onready var root: Control = $Root
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var panel: PanelContainer = %PausePanel


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
	root.visible = true
	resume_button.grab_focus()


func _on_resumed() -> void:
	root.visible = false


func _on_resume() -> void:
	GameManager.resume_game()


func _on_menu() -> void:
	GameManager.return_to_menu()
