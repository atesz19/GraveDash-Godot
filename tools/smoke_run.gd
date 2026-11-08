extends SceneTree
## Headless gameplay smoke run with an autopilot that must survive the fair routes.
##   godot --headless --fixed-fps 60 --path . --script res://tools/smoke_run.gd [-- seconds=240 ghost]
## --fixed-fps 60 makes every frame exactly one 60 Hz physics tick, so minutes of game time
## run faster than real time with identical physics.
##
## Default: autopilot (RouteSolver plans over streamed sections, real collisions, no
## ability power-ups, no Second Chance). Any death or Second Chance save = FAIL.
## `ghost`: legacy mode, player phases through hazards (pool / leak check only).
## Also checks pool / node counts stay bounded and reports souls collected per run time.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const AutopilotScript = preload("res://tools/autopilot.gd")

const GHOST_MASK: int = 17


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == name:
			return "1"
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _run() -> void:
	var seconds: float = float(_arg("seconds", "240"))
	var ghost: bool = _arg("ghost", "") != ""
	var seed_v: int = int(_arg("seed", "4242"))
	var gm: Node = get_root().get_node("GameManager")
	var pool: Node = get_root().get_node("ObjectPool")
	var score: Node = get_root().get_node("ScoreManager")
	var biomes: Node = get_root().get_node("BiomeManager")
	var upgrades: Node = get_root().get_node_or_null("UpgradeManager")
	var saved_levels: Dictionary = {}
	if upgrades:
		saved_levels = (upgrades.get("levels") as Dictionary).duplicate()
		upgrades.set("levels", {})
	gm.call("start_game")
	var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
	var gen: Node = main.get_node("LevelGenerator")
	gen.set("track_seed", seed_v)
	if not ghost:
		gen.set("ability_powerup_chance", 0.0)
	get_root().add_child(main)
	current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var pilot: Node = null
	if not ghost:
		pilot = AutopilotScript.new()
		pilot.set("player", player)
		pilot.set("gen", gen)
		main.add_child(pilot)
	var frames := 0
	var peak_nodes := 0
	var baseline_nodes := -1
	var souls_at_150 := -1
	var max_frames: int = int(seconds * 60.0)
	var saves := 0
	var ok := true
	while frames < max_frames:
		if ghost:
			player.collision_mask = GHOST_MASK
			player.set("is_ghost", true)
		await process_frame
		frames += 1
		if bool(player.get("is_escaping")):
			saves += 1
		if not bool(player.get("is_alive")) or not bool(gm.call("is_playing")) or saves > 0:
			push_error("SMOKE FAIL: hit at %.0f m (t=%.1fs) pos=%s lane=%d speed=%.1f near=%s" % [
				float(score.get("distance")), float(frames) / 60.0, str(player.global_position),
				int(player.get("current_lane")), float(player.get("run_speed")), _near_obstacles(player)])
			if pilot != null:
				print("last actions: ", pilot.get("log_lines"))
				print("pending: ", (pilot.get("_actions") as Array).slice(0, 4))
				_dump_window(pilot, float(gen.call("track_d_for_z", player.global_position.z)))
			ok = false
			break
		if frames == 150 * 60:
			souls_at_150 = int(score.get("run_souls"))
		if frames % 1800 == 0:
			var n := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			if baseline_nodes < 0:
				baseline_nodes = n
			peak_nodes = maxi(peak_nodes, n)
			print("smoke t=%3ds %6.0f m v=%4.1f biome=%s chunks=%d nodes=%d souls=%d trains=%d plans=%s" % [
				frames / 60, float(score.get("distance")), float(player.get("run_speed")),
				str(biomes.get("current_biome")), gen.get_child_count(), n, int(score.get("run_souls")),
				int(pool.call("get_active_count", "obstacle_train")),
				"-" if pilot == null else "%d/%d fail" % [int(pilot.get("plans")), int(pilot.get("plan_failures"))]])
			print("   pos=%s floor=%s sections=%d" % [player.global_position, player.is_on_floor(), (gen.call("get_track_sections") as Array).size()])
	var dist := float(score.get("distance"))
	if ok and dist < 1500.0:
		push_error("SMOKE FAIL: only %.0f m" % dist)
		ok = false
	if baseline_nodes > 0 and peak_nodes > baseline_nodes * 2:
		push_error("SMOKE FAIL: node count grew %d -> %d" % [baseline_nodes, peak_nodes])
		ok = false
	if pilot != null and int(pilot.get("plan_failures")) > 0:
		push_error("SMOKE FAIL: autopilot found no route %d times" % int(pilot.get("plan_failures")))
		ok = false
	print("SMOKE %s mode=%s game_time=%.0fs distance=%.0f biome=%s souls=%d souls@150s=%d actions=%s nodes base/peak=%d/%d" % [
		"PASS" if ok else "FAIL", "ghost" if ghost else "autopilot", float(frames) / 60.0, dist,
		str(biomes.get("current_biome")), int(score.get("run_souls")), souls_at_150,
		"-" if pilot == null else str(pilot.get("actions_sent")), baseline_nodes, peak_nodes])
	if upgrades:
		upgrades.set("levels", saved_levels)
	main.queue_free()
	await process_frame
	quit(0 if ok else 1)


func _near_obstacles(player: Node3D) -> String:
	var out: Array[String] = []
	for group_name in ["obstacle", "train"]:
		for n in player.get_tree().get_nodes_in_group(group_name):
			var n3 := n as Node3D
			if n3 == null or not n3.visible:
				continue
			var dz: float = n3.global_position.z - player.global_position.z
			if dz > -6.0 and dz < 8.0:
				out.append("%s@x%.1f dz%.1f" % [str(n3.get("pool_id")), n3.global_position.x, dz])
	return ", ".join(out)


func _dump_window(pilot: Node, d_now: float) -> void:
	var win: Dictionary = pilot.get("last_window")
	if win.is_empty():
		return
	var origin: float = float(pilot.get("last_origin"))
	for o in win["obstacles"]:
		var gd: float = float(o["d"]) + origin
		if gd > d_now - 30.0 and gd < d_now + 15.0:
			print("  obs %s lane=%d d=%.1f [%.1f..%.1f]" % [o["kind"], int(o["lane"]), gd, float(o["d0"]) + origin, float(o["d1"]) + origin])
