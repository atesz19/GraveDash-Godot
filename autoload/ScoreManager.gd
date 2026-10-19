extends Node
## ScoreManager — live score, distance (meters), high score, and soul wallet.

signal score_changed(new_score: int)
signal distance_changed(new_distance: float)
signal highscore_changed(new_highscore: int)
signal run_souls_changed(new_run_souls: int)
signal total_souls_changed(new_total: int)

## Points earned this run (distance + collectibles).
var score: int = 0

## Meters traveled this run (driven by player forward motion).
var distance: float = 0.0

## Best score across runs (persisted via SaveSystem / ConfigFile).
var highscore: int = 0

## Soul collectible points earned this run (banked into wallet on game over).
var run_souls: int = 0

## Persistent soul currency wallet (shop / meta progress).
var total_souls: int = 0

## Fractional meter accumulator so we don't drop sub-meter distance points.
var _distance_point_carry: float = 0.0
## Prevent double-banking the same run.
var _souls_banked_this_run: bool = false

## Points awarded per meter of distance.
const POINTS_PER_METER: float = 1.0
const SAVE_KEY_HIGHSCORE: String = "highscore"
const SAVE_KEY_TOTAL_SOULS: String = "total_souls"
## Legacy key kept for older saves.
const SAVE_KEY := "highscore"


func _ready() -> void:
	## Defer so SaveSystem._ready has loaded the ConfigFile first.
	call_deferred("_load_persisted")


func _load_persisted() -> void:
	highscore = int(_read_persisted(SAVE_KEY_HIGHSCORE, 0))
	total_souls = int(_read_persisted(SAVE_KEY_TOTAL_SOULS, 0))
	highscore_changed.emit(highscore)
	total_souls_changed.emit(total_souls)


func _load_highscore() -> void:
	## Kept for compatibility with older call sites.
	_load_persisted()


func reset_run() -> void:
	score = 0
	distance = 0.0
	run_souls = 0
	_distance_point_carry = 0.0
	_souls_banked_this_run = false
	score_changed.emit(score)
	distance_changed.emit(distance)
	run_souls_changed.emit(run_souls)


## Add raw points (soul orbs, coffins, distance conversion, etc.).
func add_score(points: int) -> void:
	if points == 0:
		return
	score = maxi(0, score + points)
	score_changed.emit(score)


## Soul collectible currency for this run (also still adds to score via callers).
func add_souls(points: int) -> void:
	if points <= 0:
		return
	run_souls = maxi(0, run_souls + points)
	run_souls_changed.emit(run_souls)


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
	_write_persisted(SAVE_KEY_HIGHSCORE, highscore)


## Bank this run's collectible souls into the persistent wallet (once per run).
func commit_run_souls() -> void:
	if _souls_banked_this_run:
		return
	_souls_banked_this_run = true
	if run_souls <= 0:
		return
	total_souls = maxi(0, total_souls + run_souls)
	total_souls_changed.emit(total_souls)
	_write_persisted(SAVE_KEY_TOTAL_SOULS, total_souls)


func spend_souls(amount: int) -> bool:
	if amount <= 0:
		return true
	if total_souls < amount:
		return false
	total_souls -= amount
	total_souls_changed.emit(total_souls)
	_write_persisted(SAVE_KEY_TOTAL_SOULS, total_souls)
	return true


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
