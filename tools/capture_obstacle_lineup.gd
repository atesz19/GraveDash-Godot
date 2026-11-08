extends SceneTree
## Obstacle lineup PNG: every obstacle kind placed in front of the gameplay camera on a
## frozen run, so silhouettes / materials can be reviewed. Needs a display (not --headless):
##   godot --path . --script res://tools/capture_obstacle_lineup.gd -- <out_dir> [castle]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://captures")
	var castle: bool = args.has("castle")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var gm: Node = get_root().get_node("GameManager")
	var biomes: Node = get_root().get_node("BiomeManager")
	gm.call("start_game")
	if castle:
		biomes.call("apply_transition_biome", "haunted_castle")
		biomes.call("finish_transition", "haunted_castle")
	var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var gen: Node3D = main.get_node("LevelGenerator") as Node3D
	for _i in 4:
		await process_frame
	if castle:
		gen.call("reset_generator")
		for _i in 2:
			await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	gen.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_root().get_tree().get_nodes_in_group("obstacle") + get_root().get_tree().get_nodes_in_group("train"):
		(n as Node3D).visible = false
	for n in get_root().get_tree().get_nodes_in_group("collectible"):
		(n as Node3D).visible = false

	var pz: float = player.global_position.z
	var setups: Array = [
		["res://scenes/obstacles/ObstacleTrain.tscn", 0, 9.0, {"cars": 2, "ramp": false}],
	] if args.has("train") else [
		["res://scenes/obstacles/ObstacleTrain.tscn", 0, 26.0, {"cars": 2, "ramp": false}],
		["res://scenes/obstacles/ObstacleLow.tscn", 1, 11.0, {}],
		["res://scenes/obstacles/ObstacleHigh.tscn", 1, 22.0, {}],
		["res://scenes/obstacles/ObstacleBlock.tscn", 2, 30.0, {}],
		["res://scenes/obstacles/ObstacleCart.tscn", 2, 14.0, {}],
		["res://scenes/obstacles/ObstacleTrain.tscn", 1, 40.0, {"cars": 3, "ramp": true}],
	]
	var holder := Node3D.new()
	main.add_child(holder)
	for s in setups:
		var n: Node3D = (load(str(s[0])) as PackedScene).instantiate() as Node3D
		n.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(n)
		n.call("configure", int(s[1]), 0.0, s[3])
		if n.has_method("on_spawned"):
			n.call("on_spawned")
		n.global_position = Vector3(n.global_position.x, 0.0, pz - float(s[2]))
	for _i in 8:
		await process_frame
	var name: String = "obstacle-lineup-%s%s.png" % ["castle" if castle else "graveyard", "-train" if args.has("train") else ""]
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir.path_join(name))
	print("capture %s err=%d" % [out_dir.path_join(name), err])
	quit(0)
