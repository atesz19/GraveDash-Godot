extends SceneTree
## Headless: pattern-fairness validator.
##   godot --headless --path . --script res://tools/validate_fairness.gd [-- quick]
##
## 1. Every section, at the low / mid / high speed of every band it can appear in:
##    layout_errors() is empty and RouteSolver finds a passable route from EACH start lane
##    (the previous section can leave the player anywhere).
## 2. Robustness: the layout built for speed v is still passable at v ±6 % (speed
##    prediction error, ramp acceleration inside a section).
## 3. Seams: long runs streamed through the real director (pick_section + band ramp),
##    solved across consecutive sections so section joins are fair too.

const Patterns = preload("res://scripts/levels/ChunkPatterns.gd")
const Solver = preload("res://scripts/levels/RouteSolver.gd")
const Geo = preload("res://scripts/levels/TrackGeometry.gd")

const SEAM_RUNS: int = 6
const RUN_METERS: float = 3600.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var quick: bool = OS.get_cmdline_user_args().has("quick")
	var t0: int = Time.get_ticks_msec()
	var failed: int = 0
	var checks: int = 0
	var sections: Array[Dictionary] = Patterns.all_sections()
	print("sections=%d" % sections.size())
	for s in sections:
		var id: String = str(s["id"])
		var speeds: Array[float] = []
		for b in range(int(s["band_min"]), int(s["band_max"]) + 1):
			var r: Vector2 = Patterns.band_speed_range(b)
			for v in [r.x, (r.x + r.y) * 0.5, r.y]:
				if not _has_speed(speeds, v):
					speeds.append(v)
		var worst: String = ""
		for v in speeds:
			var lay: Dictionary = Patterns.build_layout(s, v)
			for e in Patterns.layout_errors(lay):
				push_error("FAIL layout %s" % e)
				failed += 1
			var starts: Array = [0, 1, 2]
			if quick:
				starts = [1]
			for sl in starts:
				checks += 1
				var res: Dictionary = Solver.solve(lay, v, sl)
				if not bool(res["ok"]):
					push_error("FAIL unfair %s v=%.1f start_lane=%d stuck at d=%.1f/%.1f" % [
						id, v, sl, float(res["fail_d"]), float(lay["length"])])
					failed += 1
			for vv in [v * 0.94, v * 1.06]:
				checks += 1
				var rob: Dictionary = Solver.solve(lay, vv, 1)
				if not bool(rob["ok"]):
					push_error("FAIL fragile %s built@%.1f run@%.1f stuck at d=%.1f" % [
						id, v, vv, float(rob["fail_d"])])
					failed += 1
			var r1: Dictionary = Solver.solve(lay, v, 1)
			if bool(r1["ok"]):
				worst = "%d actions @%.1f" % [(r1["actions"] as Array).size(), v]
		print("section %-24s bands %d-%d speeds=%d len@max=%.0fm souls=%d  %s" % [
			id, int(s["band_min"]), int(s["band_max"]), speeds.size(),
			float(Patterns.build_layout(s, speeds[speeds.size() - 1])["length"]),
			Patterns.soul_value(Patterns.build_layout(s, speeds[0])), worst])
	failed += _seam_runs(SEAM_RUNS if not quick else 2)
	print("fairness checks=%d failed=%d time=%.1fs" % [checks, failed, float(Time.get_ticks_msec() - t0) / 1000.0])
	if failed > 0:
		push_error("FAIRNESS FAILED (%d)" % failed)
		quit(1)
		return
	print("PASS validate_fairness")
	quit(0)


func _has_speed(list: Array[float], v: float) -> bool:
	for x in list:
		if absf(x - v) < 0.25:
			return true
	return false


func _seam_runs(runs: int) -> int:
	var failed: int = 0
	var band_hits: Array[int] = [0, 0, 0, 0, 0]
	for run in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + run
		var dist: float = 0.0
		var history: Array = []
		var prev: Dictionary = {}
		var biome: String = "graveyard"
		var seams: int = 0
		while dist < RUN_METERS:
			if dist > 1300.0:
				biome = "haunted_castle"
			var band: int = Patterns.band_for_distance(dist)
			band_hits[band] += 1
			var s: Dictionary = Patterns.pick_section(rng, band, biome, history)
			history.append(s["id"])
			var v: float = Geo.speed_at_distance(dist)
			var lay: Dictionary = Patterns.build_layout(s, v)
			if not prev.is_empty():
				var joined: Dictionary = Solver.concat([prev, lay])
				for vv in [float(prev["speed"]), v]:
					var res: Dictionary = Solver.solve(joined, vv, 1)
					if not bool(res["ok"]):
						push_error("FAIL seam run=%d %s -> %s v=%.1f stuck at d=%.1f (prev len %.1f)" % [
							run, prev["id"], lay["id"], vv, float(res["fail_d"]), float(prev["length"])])
						failed += 1
				seams += 1
			prev = lay
			dist += float(lay["length"])
		print("seam run %d: %d seams, last=%s" % [run, seams, history.slice(maxi(0, history.size() - 6))])
	print("band picks: %s" % str(band_hits))
	return failed
