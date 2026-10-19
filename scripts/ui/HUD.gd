extends CanvasLayer
## HUD — live Score, distance (m), and High Score during a run.

@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var best_label: Label = $Margin/VBox/BestLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.distance_changed.connect(_on_distance_changed)
	ScoreManager.highscore_changed.connect(_on_highscore_changed)
	_refresh_all()


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
