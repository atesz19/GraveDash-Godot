extends CanvasLayer
## GameOverUI — dark overlay on GAME_OVER: distance, souls/score, best, Retry / Menu.

const THEME_PATH := "res://resources/ui/GraveDashTheme.tres"

@onready var panel: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/VBox/Title
@onready var score_label: Label = $Root/Center/Panel/VBox/ScoreLabel
@onready var distance_label: Label = $Root/Center/Panel/VBox/DistanceLabel
@onready var best_label: Label = $Root/Center/Panel/VBox/BestLabel
@onready var restart_button: Button = $Root/Center/Panel/VBox/RestartButton
@onready var menu_button: Button = $Root/Center/Panel/VBox/MenuButton
@onready var ad_button: Button = $Root/Center/Panel/VBox/AdButton
@onready var panel_container: PanelContainer = $Root/Center/Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_res := load(THEME_PATH) as Theme
	if theme_res and panel_container:
		panel_container.theme = theme_res
	panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if ad_button:
		## Placeholder — disabled stub for future rewarded continue.
		ad_button.disabled = true
		ad_button.visible = true
		ad_button.tooltip_text = "Coming soon"
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_started.connect(_on_game_started)
	if GameManager.state == GameManager.State.GAME_OVER:
		_show_overlay()


func _on_game_over() -> void:
	_show_overlay()


func _on_game_started() -> void:
	panel.visible = false


func _show_overlay() -> void:
	var run_score: int = ScoreManager.score
	var banked: int = ScoreManager.run_souls
	var wallet: int = ScoreManager.total_souls
	var dist: int = ScoreManager.get_distance_meters()
	var best: int = ScoreManager.highscore
	distance_label.text = "Distance  %d m" % dist
	score_label.text = "Run Score  %d   ·   Banked Souls  +%d" % [run_score, banked]
	best_label.text = "High Score  %d   ·   Wallet  %d" % [best, wallet]
	if best > 0 and run_score >= best:
		best_label.text = "High Score  %d  ★ NEW   ·   Wallet  %d" % [best, wallet]
	panel.visible = true
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	panel.visible = false
	GameManager.restart_run()


func _on_menu_pressed() -> void:
	panel.visible = false
	GameManager.return_to_menu()
