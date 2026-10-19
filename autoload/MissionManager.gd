extends Node
## MissionManager — 3 active missions, completion → multiplier (max 30×).
## Save keys: score_multiplier, missions_completed, active_missions (JSON).

signal missions_changed
signal mission_completed(mission_id: String, title: String)
signal multiplier_changed(new_multiplier: int)

const SLOT_COUNT: int = 3
const MULT_EVERY: int = 3
const MULT_MAX: int = 30
const MULT_START: int = 1

const SAVE_KEY_MULT: String = "score_multiplier"
const SAVE_KEY_COMPLETED: String = "missions_completed"
const SAVE_KEY_ACTIVE: String = "active_missions"

## type: distance | souls | dodge | powerups
const POOL: Array[Dictionary] = [
	{"id": "run_100", "type": "distance", "target": 100, "title": "Run 100 m"},
	{"id": "run_250", "type": "distance", "target": 250, "title": "Run 250 m"},
	{"id": "run_500", "type": "distance", "target": 500, "title": "Run 500 m"},
	{"id": "run_1000", "type": "distance", "target": 1000, "title": "Run 1000 m"},
	{"id": "souls_5", "type": "souls", "target": 5, "title": "Collect 5 souls"},
	{"id": "souls_15", "type": "souls", "target": 15, "title": "Collect 15 souls"},
	{"id": "souls_30", "type": "souls", "target": 30, "title": "Collect 30 souls"},
	{"id": "souls_50", "type": "souls", "target": 50, "title": "Collect 50 souls"},
	{"id": "dodge_5", "type": "dodge", "target": 5, "title": "Dodge 5 obstacles"},
	{"id": "dodge_15", "type": "dodge", "target": 15, "title": "Dodge 15 obstacles"},
	{"id": "dodge_30", "type": "dodge", "target": 30, "title": "Dodge 30 obstacles"},
	{"id": "power_1", "type": "powerups", "target": 1, "title": "Use 1 power-up"},
	{"id": "power_3", "type": "powerups", "target": 3, "title": "Use 3 power-ups"},
	{"id": "power_5", "type": "powerups", "target": 5, "title": "Use 5 power-ups"},
]

var multiplier: int = MULT_START
var missions_completed: int = 0
## Each: {id, type, target, progress, title}
var active: Array[Dictionary] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Per-run counters (missions can span runs — progress persists on active slots).
var _run_distance_at_slot: Array[float] = [0.0, 0.0, 0.0]
var _run_souls_at_slot: Array[int] = [0, 0, 0]


func _ready() -> void:
	_rng.randomize()
	call_deferred("_boot")


func _boot() -> void:
	_load()
	if active.is_empty():
		_fill_all_slots()
		_save()
	missions_changed.emit()
	multiplier_changed.emit(multiplier)
	if ScoreManager and not ScoreManager.distance_changed.is_connected(_on_distance_changed):
		ScoreManager.distance_changed.connect(_on_distance_changed)
	if ScoreManager and not ScoreManager.run_souls_changed.is_connected(_on_run_souls_changed):
		ScoreManager.run_souls_changed.connect(_on_run_souls_changed)
	if GameManager and not GameManager.game_started.is_connected(_on_game_started):
		GameManager.game_started.connect(_on_game_started)


func get_multiplier() -> int:
	return clampi(multiplier, MULT_START, MULT_MAX)


func get_active_missions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in active:
		out.append(m.duplicate(true))
	return out


func format_mission_line(mission: Dictionary) -> String:
	var title: String = str(mission.get("title", "Mission"))
	var progress: int = int(mission.get("progress", 0))
	var target: int = int(mission.get("target", 1))
	progress = mini(progress, target)
	return "%s  (%d/%d)" % [title, progress, target]


func report_dodge() -> void:
	_add_progress("dodge", 1)


func report_powerup_used(_powerup_id: String = "") -> void:
	_add_progress("powerups", 1)


func _on_game_started() -> void:
	## Snapshot run baselines so distance/soul missions advance by delta this run.
	_run_distance_at_slot.clear()
	_run_souls_at_slot.clear()
	for i in active.size():
		var m: Dictionary = active[i]
		m["progress_at_run_start"] = int(m.get("progress", 0))
		active[i] = m
		_run_distance_at_slot.append(ScoreManager.distance if ScoreManager else 0.0)
		_run_souls_at_slot.append(ScoreManager.run_souls if ScoreManager else 0)
	missions_changed.emit()


func _on_distance_changed(new_distance: float) -> void:
	if not GameManager or not GameManager.is_playing():
		return
	_sync_distance_progress(new_distance)


func _sync_distance_progress(new_distance: float) -> void:
	var changed: bool = false
	for i in active.size():
		var m: Dictionary = active[i]
		if str(m.get("type", "")) != "distance":
			continue
		var baseline: float = 0.0
		if i < _run_distance_at_slot.size():
			baseline = _run_distance_at_slot[i]
		var prior: int = int(m.get("progress", 0))
		## progress_at_run_start stored in mission when slotted / on game start.
		var at_start: int = int(m.get("progress_at_run_start", prior))
		var gained: int = maxi(0, int(floor(new_distance - baseline)))
		var next_p: int = at_start + gained
		if next_p != prior:
			m["progress"] = next_p
			active[i] = m
			changed = true
			_check_complete(i)
	if changed:
		missions_changed.emit()
		_save()


func _on_run_souls_changed(new_run_souls: int) -> void:
	if not GameManager or not GameManager.is_playing():
		return
	var changed: bool = false
	for i in active.size():
		var m: Dictionary = active[i]
		if str(m.get("type", "")) != "souls":
			continue
		var baseline: int = 0
		if i < _run_souls_at_slot.size():
			baseline = _run_souls_at_slot[i]
		var at_start: int = int(m.get("progress_at_run_start", int(m.get("progress", 0))))
		var gained: int = maxi(0, new_run_souls - baseline)
		var next_p: int = at_start + gained
		if next_p != int(m.get("progress", 0)):
			m["progress"] = next_p
			active[i] = m
			changed = true
			_check_complete(i)
	if changed:
		missions_changed.emit()
		_save()


func _add_progress(mission_type: String, amount: int) -> void:
	if amount <= 0:
		return
	if not GameManager or not GameManager.is_playing():
		return
	var changed: bool = false
	for i in active.size():
		var m: Dictionary = active[i]
		if str(m.get("type", "")) != mission_type:
			continue
		var next_p: int = int(m.get("progress", 0)) + amount
		m["progress"] = next_p
		active[i] = m
		changed = true
		_check_complete(i)
	if changed:
		missions_changed.emit()
		_save()


func _check_complete(index: int) -> void:
	if index < 0 or index >= active.size():
		return
	var m: Dictionary = active[index]
	var progress: int = int(m.get("progress", 0))
	var target: int = int(m.get("target", 1))
	if progress < target:
		return
	var mid: String = str(m.get("id", ""))
	var title: String = str(m.get("title", mid))
	missions_completed += 1
	_recompute_multiplier()
	mission_completed.emit(mid, title)
	## Replace slot with a fresh mission from the pool.
	active[index] = _make_mission(_pick_template(mid))
	_stamp_run_baselines_for_index(index)
	_save()
	missions_changed.emit()


func _recompute_multiplier() -> void:
	var next_m: int = MULT_START + int(missions_completed / MULT_EVERY)
	next_m = clampi(next_m, MULT_START, MULT_MAX)
	if next_m != multiplier:
		multiplier = next_m
		multiplier_changed.emit(multiplier)
		if ScoreManager and ScoreManager.has_method("recompute_score"):
			ScoreManager.recompute_score()


func _fill_all_slots() -> void:
	active.clear()
	var used: Dictionary = {}
	for i in SLOT_COUNT:
		var tmpl: Dictionary = _pick_template_excluding(used)
		var mid: String = str(tmpl.get("id", "m%d" % i))
		used[mid] = true
		active.append(_make_mission(tmpl))
	_run_distance_at_slot.clear()
	_run_souls_at_slot.clear()
	for i in active.size():
		_run_distance_at_slot.append(0.0)
		_run_souls_at_slot.append(0)


func _make_mission(tmpl: Dictionary) -> Dictionary:
	return {
		"id": str(tmpl.get("id", "mission")),
		"type": str(tmpl.get("type", "distance")),
		"target": int(tmpl.get("target", 1)),
		"progress": 0,
		"progress_at_run_start": 0,
		"title": str(tmpl.get("title", "Mission")),
	}


func _pick_template(exclude_id: String = "") -> Dictionary:
	var used: Dictionary = {}
	if exclude_id != "":
		used[exclude_id] = true
	for m in active:
		used[str(m.get("id", ""))] = true
	return _pick_template_excluding(used)


func _pick_template_excluding(used: Dictionary) -> Dictionary:
	var choices: Array[Dictionary] = []
	for tmpl in POOL:
		var tid: String = str(tmpl.get("id", ""))
		if used.has(tid):
			continue
		choices.append(tmpl)
	if choices.is_empty():
		## Fallback: allow repeats from pool.
		return POOL[_rng.randi_range(0, POOL.size() - 1)].duplicate(true)
	return choices[_rng.randi_range(0, choices.size() - 1)].duplicate(true)


func _stamp_run_baselines_for_index(index: int) -> void:
	while _run_distance_at_slot.size() <= index:
		_run_distance_at_slot.append(0.0)
	while _run_souls_at_slot.size() <= index:
		_run_souls_at_slot.append(0)
	_run_distance_at_slot[index] = ScoreManager.distance if ScoreManager else 0.0
	_run_souls_at_slot[index] = ScoreManager.run_souls if ScoreManager else 0
	if index < active.size():
		var m: Dictionary = active[index]
		m["progress_at_run_start"] = int(m.get("progress", 0))
		active[index] = m


func _load() -> void:
	multiplier = clampi(int(_read(SAVE_KEY_MULT, MULT_START)), MULT_START, MULT_MAX)
	missions_completed = maxi(0, int(_read(SAVE_KEY_COMPLETED, 0)))
	## Keep multiplier consistent with completed count.
	var derived: int = clampi(MULT_START + int(missions_completed / MULT_EVERY), MULT_START, MULT_MAX)
	if derived > multiplier:
		multiplier = derived
	active.clear()
	var raw: Variant = _read(SAVE_KEY_ACTIVE, "")
	var raw_s: String = str(raw) if raw != null else ""
	if raw_s != "":
		var parsed: Variant = JSON.parse_string(raw_s)
		if parsed is Array:
			for item in parsed as Array:
				if item is Dictionary:
					var d: Dictionary = (item as Dictionary).duplicate(true)
					if not d.has("progress_at_run_start"):
						d["progress_at_run_start"] = int(d.get("progress", 0))
					active.append(d)
	while active.size() > SLOT_COUNT:
		active.pop_back()
	while active.size() < SLOT_COUNT:
		active.append(_make_mission(_pick_template()))


func _save() -> void:
	_write(SAVE_KEY_MULT, multiplier)
	_write(SAVE_KEY_COMPLETED, missions_completed)
	var serial: Array = []
	for m in active:
		serial.append({
			"id": str(m.get("id", "")),
			"type": str(m.get("type", "")),
			"target": int(m.get("target", 1)),
			"progress": int(m.get("progress", 0)),
			"title": str(m.get("title", "")),
		})
	_write(SAVE_KEY_ACTIVE, JSON.stringify(serial))


func _read(key: String, default: Variant) -> Variant:
	if SaveSystem and SaveSystem.has_method("get_value"):
		return SaveSystem.get_value(key, default)
	return default


func _write(key: String, value: Variant) -> void:
	if SaveSystem == null:
		return
	SaveSystem.set_value(key, value)
	if SaveSystem.has_method("save"):
		SaveSystem.save()
