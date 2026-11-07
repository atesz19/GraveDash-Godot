extends SceneTree
## Capture gameplay PNGs (Graveyard + Haunted Castle). Needs a display (not --headless).
##   godot --path . --script res://tools/capture_gameplay.gd -- <out_dir>
## Player phases through hazards so the run survives long enough to reach castle chunks.

const GHOST_MASK: int = 1


func _initialize() -> void:
	call_deferred("_run")


func _out_dir() -> String:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		return args[0]
	return ProjectSettings.globalize_path("user://captures")


func _run() -> void:
	var out_dir := _out_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var gm: Node = get_root().get_node("GameManager")
	var biomes: Node = get_root().get_node("BiomeManager")
	gm.call("start_game")
	var packed: PackedScene = load("res://scenes/levels/Main.tscn") as PackedScene
	var main: Node = packed.instantiate()
	get_root().add_child(main)
	current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	for _i in 4:
		await process_frame
	player.collision_mask = GHOST_MASK
	player.set("is_ghost", true)
	await create_timer(4.0).timeout
	_save(out_dir.path_join("gameplay-graveyard.png"))
	await create_timer(3.0).timeout
	_save(out_dir.path_join("gameplay-graveyard-2.png"))

	biomes.call("apply_transition_biome", "haunted_castle")
	biomes.call("finish_transition", "haunted_castle")
	## Rebuild the track as castle chunks instead of running past the pre-spawned graveyard ones.
	var gen: Node = main.get_node("LevelGenerator")
	gen.call("reset_generator")
	player.global_position = Vector3(player.global_position.x, player.global_position.y, 18.0)
	player.collision_mask = GHOST_MASK
	player.set("is_ghost", true)
	await create_timer(2.5).timeout
	_save(out_dir.path_join("gameplay-castle.png"))
	quit(0)


func _save(path: String) -> void:
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("capture %s err=%d draw_calls=%d objects=%d primitives=%d" % [
		path, err,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	])
