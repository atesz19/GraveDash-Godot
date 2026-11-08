extends Node
## Autopilot for headless smoke runs / captures. Plans with RouteSolver over the sections
## LevelGenerator has streamed ahead, then drives PlayerController.queue_action() at the
## planned track distances. Replans from the player's real state every REPLAN_EVERY meters.

const Solver = preload("res://scripts/levels/RouteSolver.gd")
const Geo = preload("res://scripts/levels/TrackGeometry.gd")

const REPLAN_EVERY: float = 24.0
const WINDOW: float = 240.0

var player: CharacterBody3D
var gen: Node
var plans: int = 0
var plan_failures: int = 0
var actions_sent: int = 0
var log_lines: Array[String] = []

var _actions: Array = []
var last_window: Dictionary = {}
var last_origin: float = 0.0
var _last_plan_d: float = -INF
var _last_section_count: int = -1


func _physics_process(_delta: float) -> void:
	if player == null or gen == null or not bool(player.get("is_alive")):
		return
	var d_now: float = float(gen.call("track_d_for_z", player.global_position.z))
	var v: float = float(player.get("run_speed"))
	var lead: float = v / 60.0
	var sent_now: bool = false
	while not _actions.is_empty() and d_now + lead >= float(_actions[0]["d"]):
		var a: Dictionary = _actions.pop_front()
		player.call("queue_action", str(a["action"]))
		actions_sent += 1
		sent_now = true
		log_lines.append("%s@%.1f (now %.1f y=%.2f lane=%d)" % [a["action"], float(a["d"]), d_now, player.global_position.y, int(player.get("current_lane"))])
		if log_lines.size() > 8:
			log_lines.pop_front()
	var sections: Array = gen.call("get_track_sections")
	var need: bool = d_now - _last_plan_d >= REPLAN_EVERY or sections.size() != _last_section_count
	if need and not sent_now and _can_plan(d_now, v):
		_plan(d_now, v, sections)


func _can_plan(d_now: float, v: float) -> bool:
	if not (player.get("_queued") as Dictionary).is_empty():
		return false
	if not player.is_on_floor() or bool(player.get("is_sliding")):
		return false
	var y: float = player.global_position.y
	if absf(y) > 0.05 and absf(y - Geo.TRAIN_ROOF) > 0.05:
		return false
	var lane: int = int(player.get("current_lane"))
	if absf(player.global_position.x - Geo.LANE_X[lane]) > 0.05:
		return false
	if not _actions.is_empty() and float(_actions[0]["d"]) - d_now < v * 0.5:
		return false
	return true


func _plan(d_now: float, v: float, sections: Array) -> void:
	var window: Array = []
	var origin: float = -1.0
	for s in sections:
		var d0: float = float(gen.call("track_d_for_z", float(s["z_start"])))
		var lay: Dictionary = s["layout"]
		if d0 + float(lay["length"]) < d_now:
			continue
		if d0 > d_now + WINDOW:
			break
		if origin < 0.0:
			origin = d0
		window.append(lay)
	if window.is_empty():
		return
	var joined: Dictionary = Solver.concat(window)
	var level: int = 1 if player.global_position.y > 0.05 else 0
	var start: float = maxf(0.0, d_now - origin + 0.6)
	last_window = joined
	last_origin = origin
	var res: Dictionary = Solver.solve(joined, v, int(player.get("current_lane")), start, level)
	plans += 1
	_last_plan_d = d_now
	_last_section_count = sections.size()
	if not bool(res["ok"]):
		plan_failures += 1
		push_warning("autopilot: no route from d=%.1f lane=%d level=%d v=%.1f (stuck at %.1f)" % [
			d_now, int(player.get("current_lane")), level, v, float(res["fail_d"]) + origin])
		for o in joined["obstacles"]:
			if absf(float(o["d"]) + origin - d_now) < 25.0:
				print("  near %s lane=%d d=%.1f" % [o["kind"], int(o["lane"]), float(o["d"]) + origin])
		return
	_actions.clear()
	for a in res["actions"]:
		_actions.append({"d": float(a["d"]) + origin, "action": str(a["action"])})
