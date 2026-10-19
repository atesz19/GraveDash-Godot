extends CanvasLayer
## GameOverUI — minimal dark overlay shown when GameManager enters GAME_OVER.
## Restart reloads the main scene via GameManager.restart_run().

@onready var panel: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/VBox/Title
@onready var score_label: Label = $Root/Center/Panel/VBox/ScoreLabel
@onready var distance_label: Label = $Root/Center/Panel/VBox/DistanceLabel
@onready var best_label: Label = $Root/Center/Panel/VBox/BestLabel
@onready var restart_button: Button = $Root/Center/Panel/VBox/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_started.connect(_on_game_started)
	## Hide if we somehow boot mid-game-over.
	if GameManager.state == GameManager.State.GAME_OVER:
		_show_overlay()


func _on_game_over() -> void:
	_show_overlay()


func _on_game_started() -> void:
	panel.visible = false


func _show_overlay() -> void:
	score_label.text = "Score  %d" % ScoreManager.score
	if distance_label:
		distance_label.text = "Distance  %d m" % ScoreManager.get_distance_meters()
	best_label.text = "Best   %d" % ScoreManager.highscore
	panel.visible = true
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	panel.visible = false
	GameManager.restart_run()
