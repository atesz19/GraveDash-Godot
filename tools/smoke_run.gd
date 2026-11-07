extends SceneTree
## Headless gameplay smoke: runs Main past the Haunted Castle switch with the player
## phasing through hazards, then checks pool / node counts stay bounded (no leaks).
##   godot --headless --path . --script res://tools/smoke_run.gd
## Exit 0 = pass. Engine errors are printed to stderr; grep the log for "ERROR".

const GHOST_MASK: int = 1
const TARGET_M: float = 1900.0
const MAX_FRAMES: int = 40000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gm: Node = get_root().get_node("GameManager")
	var pool: Node = get_root().get_node("ObjectPool")
	var score: Node = get_root().get_node("ScoreManager")
	var biomes: Node = get_root().get_node("BiomeManager")
	gm.call("start_game")
	var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var gen: Node = main.get_node("LevelGenerator")
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	var frames := 0
	var peak_nodes := 0
	var baseline_nodes := -1
	while float(score.get("distance")) < TARGET_M and frames < MAX_FRAMES:
		player.collision_mask = GHOST_MASK
		player.set("is_ghost", true)
		await process_frame
		frames += 1
		if not bool(player.get("is_alive")) or not bool(gm.call("is_playing")):
			push_error("SMOKE FAIL: run ended early at %.0f m" % float(score.get("distance")))
			quit(1)
			return
		if frames % 600 == 0:
			var n := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			if baseline_nodes < 0:
				baseline_nodes = n
			peak_nodes = maxi(peak_nodes, n)
			print("smoke %5d f  %6.0f m  biome=%s  chunks=%d  nodes=%d  souls active/free=%d/%d" % [
				frames, float(score.get("distance")), str(biomes.get("current_biome")),
				gen.get_child_count(), n,
				int(pool.call("get_active_count", "collectible_soul")),
				int(pool.call("get_free_count", "collectible_soul")),
			])
	var dist := float(score.get("distance"))
	var ok := dist >= TARGET_M and str(biomes.get("current_biome")) == "haunted_castle"
	## Allow growth for the castle pools + scatter, but not unbounded.
	if baseline_nodes > 0 and peak_nodes > baseline_nodes * 2:
		push_error("SMOKE FAIL: node count grew %d -> %d" % [baseline_nodes, peak_nodes])
		ok = false
	print("SMOKE %s distance=%.0f frames=%d nodes base/peak=%d/%d" % [
		"PASS" if ok else "FAIL", dist, frames, baseline_nodes, peak_nodes])
	quit(0 if ok else 1)
