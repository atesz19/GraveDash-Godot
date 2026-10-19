extends CanvasLayer
## HUD — live Score, distance (m), High Score, and Ghost Form timer.

@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var best_label: Label = $Margin/VBox/BestLabel
@onready var ghost_row: HBoxContainer = $Margin/VBox/GhostRow
@onready var ghost_icon: ColorRect = $Margin/VBox/GhostRow/GhostIcon
@onready var ghost_label: Label = $Margin/VBox/GhostRow/GhostLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.distance_changed.connect(_on_distance_changed)
	ScoreManager.highscore_changed.connect(_on_highscore_changed)
	ghost_row.visible = false
	_refresh_all()
	## Bind to player once it exists (Main may instantiate HUD before Player finishes _ready).
	call_deferred("_bind_player")


func _bind_player() -> void:
	var player := GameManager.player
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("ghost_form_changed"):
		if not player.ghost_form_changed.is_connected(_on_ghost_form_changed):
			player.ghost_form_changed.connect(_on_ghost_form_changed)
		## Sync if ghost already active (unlikely at boot).
		if player.has_method("is_ghost_form") and player.is_ghost_form():
			_on_ghost_form_changed(true, player.ghost_time_remaining)


func _refresh_all() -> void:
	_on_score_changed(ScoreManager.score)
	_on_distance_changed(ScoreManager.distance)
	_on_highscore_changed(ScoreManager.highscore)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score  %d" % new_score


func _on_distance_changed(new_distance: float) -> void:
	distance_label.text = "Distance  %d m" % int(floor(new_distance))


func _on_highscore_changed(new_highscore: int) -> void:
	best_label.text = "Best  %d" % new_highscore


func _on_ghost_form_changed(active: bool, remaining: float) -> void:
	ghost_row.visible = active
	if active:
		ghost_label.text = "GHOST  %.1fs" % remaining
		## Pulse icon alpha slightly with time.
		var pulse := 0.65 + 0.35 * absf(sin(remaining * 4.0))
		ghost_icon.color = Color(0.55, 0.2, 0.85, pulse)
