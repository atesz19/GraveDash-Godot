extends Node
## ScoreManager — tracks score, distance traveled, and highscore for GraveDash.

signal score_changed(new_score: int)
signal distance_changed(new_distance: float)
signal highscore_changed(new_highscore: int)

## Points earned this run (obstacles, pickups, distance bonuses).
var score: int = 0

## Meters traveled this run (driven by player forward motion).
var distance: float = 0.0

## Best score across runs (persisted via SaveSystem when available).
var highscore: int = 0

## Points awarded per meter of distance.
const POINTS_PER_METER: float = 1.0


func _ready() -> void:
	## Load persisted highscore if SaveSystem stub is present.
	if has_node("/root/SaveSystem") and SaveSystem.has_method("get_value"):
		highscore = int(SaveSystem.get_value("highscore", 0))


func reset_run() -> void:
	score = 0
	distance = 0.0
	score_changed.emit(score)
	distance_changed.emit(distance)


## Add raw points (pickups, combos, etc.).
func add_score(points: int) -> void:
	if points == 0:
		return
	score = max(0, score + points)
	score_changed.emit(score)


## Advance distance by `meters` and convert to score.
func add_distance(meters: float) -> void:
	if meters <= 0.0:
		return
	distance += meters
	var earned := int(meters * POINTS_PER_METER)
	if earned > 0:
		score += earned
		score_changed.emit(score)
	distance_changed.emit(distance)


## Persist highscore if this run beat the previous best.
func commit_highscore() -> void:
	if score > highscore:
		highscore = score
		highscore_changed.emit(highscore)
		if has_node("/root/SaveSystem") and SaveSystem.has_method("set_value"):
			SaveSystem.set_value("highscore", highscore)
			if SaveSystem.has_method("save"):
				SaveSystem.save()
