extends Node
## ScoreManager — distance + soul raw points × MissionManager multiplier.
## Display/highscore score = raw_score × multiplier.

signal score_changed(new_score: int)
signal distance_changed(new_distance: float)
signal highscore_changed(new_highscore: int)
signal run_souls_changed(new_run_souls: int)
signal total_souls_changed(new_total: int)
signal raw_score_changed(new_raw: int)

## Raw points this run (distance convert + soul collectibles) before multiplier.
var raw_score: int = 0

## Display score = raw_score × current multiplier.
var score: int = 0

## Meters traveled this run (driven by player forward motion).
var distance: float = 0.0

## Best score across runs (persisted; stores multiplied final scores).
var highscore: int = 0

## Soul collectible points earned this run (banked into wallet on game over).
var run_souls: int = 0

## Persistent soul currency wallet (shop / meta progress).
var total_souls: int = 0

var _distance_point_carry: float = 0.0
var _souls_banked_this_run: bool = false

const POINTS_PER_METER: float = 1.0
const SAVE_KEY_HIGHSCORE: String = "highscore"
const SAVE_KEY_TOTAL_SOULS: String = "total_souls"


func _ready() -> void:
	call_deferred("_load_persisted")
	call_deferred("_bind_multiplier")


func _bind_multiplier() -> void:
	if MissionManager and not MissionManager.multiplier_changed.is_connected(_on_multiplier_changed):
		MissionManager.multiplier_changed.connect(_on_multiplier_changed)


func _on_multiplier_changed(_new_mult: int) -> void:
	recompute_score()


func _load_persisted() -> void:
	highscore = int(_read_persisted(SAVE_KEY_HIGHSCORE, 0))
	total_souls = int(_read_persisted(SAVE_KEY_TOTAL_SOULS, 0))
	highscore_changed.emit(highscore)
	total_souls_changed.emit(total_souls)


func _load_highscore() -> void:
	_load_persisted()


func reset_run() -> void:
	raw_score = 0
	score = 0
	distance = 0.0
	run_souls = 0
	_distance_point_carry = 0.0
	_souls_banked_this_run = false
	raw_score_changed.emit(raw_score)
	score_changed.emit(score)
	distance_changed.emit(distance)
	run_souls_changed.emit(run_souls)


func get_multiplier() -> int:
	if MissionManager:
		return MissionManager.get_multiplier()
	return 1


func recompute_score() -> void:
	var mult: int = get_multiplier()
	var next: int = raw_score * mult
	if next != score:
		score = next
		score_changed.emit(score)


func add_score(points: int) -> void:
	if points == 0:
		return
	raw_score = maxi(0, raw_score + points)
	raw_score_changed.emit(raw_score)
	recompute_score()


func add_souls(points: int) -> void:
	if points <= 0:
		return
	run_souls = maxi(0, run_souls + points)
	run_souls_changed.emit(run_souls)


func add_distance(meters: float) -> void:
	if meters <= 0.0:
		return
	distance += meters
	_distance_point_carry += meters * POINTS_PER_METER
	var earned: int = int(_distance_point_carry)
	if earned > 0:
		_distance_point_carry -= float(earned)
		raw_score += earned
		raw_score_changed.emit(raw_score)
		recompute_score()
	distance_changed.emit(distance)


func commit_highscore() -> void:
	recompute_score()
	if score <= highscore:
		return
	highscore = score
	highscore_changed.emit(highscore)
	_write_persisted(SAVE_KEY_HIGHSCORE, highscore)


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
