extends SceneTree
## Headless check: MissionManager pool, multiplier steps, ScoreManager formula.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var mm: Node = get_root().get_node_or_null("MissionManager")
	var sm: Node = get_root().get_node_or_null("ScoreManager")
	var gm: Node = get_root().get_node_or_null("GameManager")
	if mm == null:
		push_error("FAIL MissionManager autoload missing")
		quit(1)
		return
	if sm == null:
		push_error("FAIL ScoreManager autoload missing")
		quit(1)
		return
	## Wait deferred boot (fill slots / load).
	await process_frame
	await process_frame
	await process_frame
	var active: Array = mm.call("get_active_missions")
	if active.size() != 3:
		push_error("FAIL expected 3 missions, got %d" % active.size())
		failed += 1
	else:
		print("OK active missions=", active.size())
	var mult: int = int(mm.call("get_multiplier"))
	if mult < 1 or mult > 30:
		push_error("FAIL multiplier out of range %d" % mult)
		failed += 1
	else:
		print("OK multiplier=", mult)
	## Force PLAYING so progress reports apply.
	if gm:
		gm.set("state", gm.get("State").PLAYING)
	## Score formula: raw × mult.
	sm.call("reset_run")
	sm.call("add_distance", 100.0)
	sm.call("add_score", 25)  ## soul points into raw
	sm.call("add_souls", 25)
	sm.call("recompute_score")
	var raw: int = int(sm.get("raw_score"))
	var score: int = int(sm.get("score"))
	var cur_mult: int = int(sm.call("get_multiplier"))
	if raw < 125:
		push_error("FAIL raw_score expected >=125 got %d" % raw)
		failed += 1
	else:
		print("OK raw_score=", raw)
	if score != raw * cur_mult:
		push_error("FAIL score=%d expected raw*mult=%d" % [score, raw * cur_mult])
		failed += 1
	else:
		print("OK score formula raw=%d ×%d = %d" % [raw, cur_mult, score])
	## Dodge / powerup progress hooks.
	var before_dodge: int = _progress_for_type(mm, "dodge")
	mm.call("report_dodge")
	var after_dodge: int = _progress_for_type(mm, "dodge")
	if after_dodge < before_dodge + 1 and _has_type(mm, "dodge"):
		push_error("FAIL dodge progress did not advance")
		failed += 1
	elif _has_type(mm, "dodge"):
		print("OK dodge progress ", before_dodge, "→", after_dodge)
	else:
		print("OK dodge report (no active dodge mission)")
	var before_pu: int = _progress_for_type(mm, "powerups")
	mm.call("report_powerup_used", "ghost_form")
	var after_pu: int = _progress_for_type(mm, "powerups")
	if after_pu < before_pu + 1 and _has_type(mm, "powerups"):
		push_error("FAIL powerup progress did not advance")
		failed += 1
	elif _has_type(mm, "powerups"):
		print("OK powerup progress ", before_pu, "→", after_pu)
	else:
		print("OK powerup report (no active powerup mission)")
	## Multiplier step: every 3 completions → +1, cap 30.
	var completed: int = int(mm.get("missions_completed"))
	var expected_mult: int = mini(30, 1 + int(completed / 3))
	if int(mm.call("get_multiplier")) != expected_mult:
		push_error("FAIL mult derived mismatch got=%d expected=%d completed=%d" % [
			int(mm.call("get_multiplier")), expected_mult, completed
		])
		failed += 1
	else:
		print("OK mult from completed=", completed, " → ×", expected_mult)
	## UI scenes load.
	for path in [
		"res://scenes/ui/HUD.tscn",
		"res://scenes/ui/MainMenu.tscn",
		"res://scenes/ui/GameOverUI.tscn",
		"res://scenes/ui/PauseOverlay.tscn",
	]:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("FAIL load %s" % path)
			failed += 1
		else:
			var n: Node = packed.instantiate()
			get_root().add_child(n)
			await process_frame
			print("OK instantiate ", path)
			n.queue_free()
	if failed > 0:
		quit(1)
	print("Mission/score system OK")
	quit(0)


func _has_type(mm: Node, mission_type: String) -> bool:
	var active: Array = mm.call("get_active_missions")
	for item in active:
		if item is Dictionary and str((item as Dictionary).get("type", "")) == mission_type:
			return true
	return false


func _progress_for_type(mm: Node, mission_type: String) -> int:
	var active: Array = mm.call("get_active_missions")
	var total: int = 0
	for item in active:
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			if str(d.get("type", "")) == mission_type:
				total += int(d.get("progress", 0))
	return total
