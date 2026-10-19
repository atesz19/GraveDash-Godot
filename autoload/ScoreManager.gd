extends Node
## ScoreManager — live score, distance (meters), and persisted high score.

signal score_changed(new_score: int)
signal distance_changed(new_distance: float)
signal highscore_changed(new_highscore: int)

## Points earned this run (distance + collectibles).
var score: int = 0

## Meters traveled this run (driven by player forward motion).
var distance: float = 0.0

## Best score across runs (persisted via SaveSystem / ConfigFile).
var highscore: int = 0

## Fractional meter accumulator so we don't drop sub-meter distance points.
var _distance_point_carry: float = 0.0

## Points awarded per meter of distance.
const POINTS_PER_METER: float = 1.0
const SAVE_KEY := "highscore"


func _ready() -> void:
	## Defer so SaveSystem._ready has loaded the ConfigFile first.
	call_deferred("_load_highscore")


func _load_highscore() -> void:
	highscore = int(_read_persisted(SAVE_KEY, 0))
	highscore_changed.emit(highscore)


func reset_run() -> void:
	score = 0
	distance = 0.0
	_distance_point_carry = 0.0
	score_changed.emit(score)
	distance_changed.emit(distance)


## Add raw points (soul orbs, coffins, etc.).
func add_score(points: int) -> void:
	if points == 0:
		return
	score = maxi(0, score + points)
	score_changed.emit(score)


## Advance distance by `meters` and convert to score.
func add_distance(meters: float) -> void:
	if meters <= 0.0:
		return
	distance += meters
	_distance_point_carry += meters * POINTS_PER_METER
	var earned := int(_distance_point_carry)
	if earned > 0:
		_distance_point_carry -= float(earned)
		score += earned
		score_changed.emit(score)
	distance_changed.emit(distance)


## Persist highscore if this run beat the previous best.
func commit_highscore() -> void:
	if score <= highscore:
		return
	highscore = score
	highscore_changed.emit(highscore)
	_write_persisted(SAVE_KEY, highscore)


func get_distance_meters() -> int:
	return int(floor(distance))


func _read_persisted(key: String, default: Variant) -> Variant:
	if has_node("/root/SaveSystem") and SaveSystem.has_method("get_value"):
		return SaveSystem.get_value(key, default)
	## Fallback ConfigFile if SaveSystem is missing.
	var cfg := ConfigFile.new()
	if cfg.load("user://gravedash_save.cfg") != OK:
		return default
	return cfg.get_value("save", key, default)


func _write_persisted(key: String, value: Variant) -> void:
	if has_node("/root/SaveSystem") and SaveSystem.has_method("set_value"):
		SaveSystem.set_value(key, value)
		if SaveSystem.has_method("save"):
			SaveSystem.save()
		return
	var cfg := ConfigFile.new()
	cfg.load("user://gravedash_save.cfg")
	cfg.set_value("save", key, value)
	cfg.save("user://gravedash_save.cfg")
