extends SceneTree
## Render-check capture for any renderer / aspect ratio. Needs a display (not --headless).
##   godot --path . --rendering-method gl_compatibility --resolution 1680x720 \
##     --script res://tools/capture_render.gd -- <menu|gameplay|castle> <out.png>
## Run once per renderer (forward_plus / mobile / gl_compatibility) and window size.

const GHOST_MASK: int = 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "menu"
	var out: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("user://capture_%s.png" % mode)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _i in 3:
		await process_frame
	if mode == "menu":
		var menu: Node = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
		get_root().add_child(menu)
		current_scene = menu
		for _i in 12:
			await process_frame
		await create_timer(0.8).timeout
	else:
		get_root().get_node("GameManager").call("start_game")
		var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
		get_root().add_child(main)
		current_scene = main
		var player := main.get_node("Player") as CharacterBody3D
		for _i in 4:
			await process_frame
		if mode == "castle":
			var biomes: Node = get_root().get_node("BiomeManager")
			biomes.call("apply_transition_biome", "haunted_castle")
			biomes.call("finish_transition", "haunted_castle")
			main.get_node("LevelGenerator").call("reset_generator")
			player.global_position = Vector3(player.global_position.x, player.global_position.y, 18.0)
		await _run_for(player, 3.0)
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("capture %s %s %dx%d renderer=%s err=%d" % [
		mode, out, img.get_width(), img.get_height(),
		RenderingServer.get_current_rendering_method(), err,
	])
	quit(0 if err == OK else 1)


## Obstacles are Areas that test the player directly, so phase via the ghost flag every frame.
func _run_for(player: CharacterBody3D, seconds: float) -> void:
	var end_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_ms:
		player.collision_mask = GHOST_MASK
		player.set("is_ghost", true)
		await process_frame
