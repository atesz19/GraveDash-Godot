extends SceneTree
## Headless: SS obstacle hit rules + platform StaticBody + pool registration.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var mock_script := GDScript.new()
	mock_script.source_code = """extends CharacterBody3D
var is_sliding: bool = false
var is_escaping: bool = false
func is_ghost_form() -> bool:
	return false
"""
	if mock_script.reload() != OK:
		push_error("FAIL mock script reload")
		quit(1)
		return

	var player := CharacterBody3D.new()
	player.set_script(mock_script)
	player.add_to_group("player")
	player.position = Vector3(0, 0.05, 0)
	get_root().add_child(player)

	var low: Node = (load("res://scenes/obstacles/ObstacleLow.tscn") as PackedScene).instantiate()
	var high: Node = (load("res://scenes/obstacles/ObstacleHigh.tscn") as PackedScene).instantiate()
	get_root().add_child(low)
	get_root().add_child(high)
	await process_frame
	await process_frame

	player.set("is_sliding", false)
	if not bool(low.call("can_kill_body", player)):
		push_error("FAIL low should kill standing")
		failed += 1
	player.set("is_sliding", true)
	if bool(low.call("can_kill_body", player)):
		push_error("FAIL low should spare sliding")
		failed += 1
	else:
		print("OK low slide rule")

	player.set("is_sliding", false)
	player.global_position.y = 0.05
	if not bool(high.call("can_kill_body", player)):
		push_error("FAIL high should kill grounded")
		failed += 1
	player.global_position.y = 1.6
	if bool(high.call("can_kill_body", player)):
		push_error("FAIL high should spare jump height")
		failed += 1
	else:
		print("OK high jump rule")

	var plat: Node = (load("res://scenes/obstacles/ObstaclePlatform.tscn") as PackedScene).instantiate()
	get_root().add_child(plat)
	await process_frame
	plat.call("configure", 1, 0.0, {"width": 2, "ramp": true, "length": 14.0})
	plat.call("on_spawned")
	var floor_body: StaticBody3D = plat.get_node_or_null("FloorBody") as StaticBody3D
	var ramp_body: StaticBody3D = plat.get_node_or_null("RampBody") as StaticBody3D
	if floor_body == null or floor_body.collision_layer != 1:
		push_error("FAIL platform floor layer")
		failed += 1
	else:
		print("OK platform floor layer")
	if ramp_body == null or not ramp_body.visible:
		push_error("FAIL ramp not enabled")
		failed += 1
	else:
		print("OK platform ramp")
	var lanes: Variant = plat.call("occupied_lanes")
	if not (lanes is Array) or (lanes as Array).size() != 2:
		push_error("FAIL platform occupied_lanes=%s" % str(lanes))
		failed += 1
	else:
		print("OK platform width lanes=", lanes)

	var pool: Node = get_root().get_node_or_null("ObjectPool")
	if pool == null:
		push_error("FAIL ObjectPool autoload missing")
		failed += 1
	else:
		var gen := Node3D.new()
		gen.set_script(load("res://scripts/LevelGenerator.gd"))
		gen.call("_ensure_scenes")
		gen.call("_register_pools")
		for pid in ["obstacle_low", "obstacle_high", "obstacle_platform", "obstacle_gravestone", "obstacle_side"]:
			if not bool(pool.call("has_pool", pid)):
				push_error("FAIL pool missing %s" % pid)
				failed += 1
			else:
				print("OK pool ", pid)
		if bool(pool.call("has_pool", "obstacle_pit")):
			push_error("FAIL pit pool still registered")
			failed += 1
		else:
			print("OK pit pool cleared/absent")

	var ChunkPatternsScript = load("res://scripts/levels/ChunkPatterns.gd")
	for p in ChunkPatternsScript.all_patterns():
		for item in (p.get("obstacles", []) as Array):
			if item is Dictionary and str((item as Dictionary).get("kind", "")) == "obstacle_pit":
				push_error("FAIL pit in pattern %s" % str(p.get("id")))
				failed += 1

	if failed > 0:
		quit(1)
	print("SS obstacles OK")
	quit(0)
