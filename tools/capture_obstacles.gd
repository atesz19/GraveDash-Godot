extends SceneTree
## Capture gameplay PNGs of the obstacle set while the autopilot plays a real run.
## Needs a display (not --headless):
##   godot --fixed-fps 60 --path . --script res://tools/capture_obstacles.gd -- <out_dir>
## Shots: hearse train + barriers ahead, riding a train roof, rolling cart, castle section.
## The render loop is off while the run plays and only switched on around each capture.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const AutopilotScript = preload("res://tools/autopilot.gd")

var _player: CharacterBody3D


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
	var upgrades: Node = get_root().get_node_or_null("UpgradeManager")
	var saved_levels: Dictionary = {}
	if upgrades:
		saved_levels = (upgrades.get("levels") as Dictionary).duplicate()
		upgrades.set("levels", {})
	gm.call("start_game")
	var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
	var gen: Node = main.get_node("LevelGenerator")
	gen.set("track_seed", 4242)
	gen.set("ability_powerup_chance", 0.0)
	get_root().add_child(main)
	current_scene = main
	_player = main.get_node("Player") as CharacterBody3D
	var pilot: Node = AutopilotScript.new()
	pilot.set("player", _player)
	pilot.set("gen", gen)
	main.add_child(pilot)

	RenderingServer.render_loop_enabled = false
	var wanted: Array[String] = ["train-ahead", "roof-ride", "cart", "castle"]
	var done: Dictionary = {}
	var frames: int = 0
	var cooldown: int = 0
	while frames < 60 * 200 and done.size() < wanted.size():
		await physics_frame
		await process_frame
		frames += 1
		cooldown -= 1
		if not bool(_player.get("is_alive")):
			push_error("capture: player died at frame %d" % frames)
			break
		if cooldown > 0:
			continue
		var castle: bool = str(biomes.get("current_biome")) == "haunted_castle"
		var shot: String = ""
		if not done.has("train-ahead") and _player.global_position.y < 0.05 and _ahead("train", 10.0, 22.0, true) and _ahead("obstacle", 6.0, 40.0):
			shot = "train-ahead"
		elif not done.has("roof-ride") and _player.global_position.y > Geo.TRAIN_ROOF - 0.05 and frames > 60 * 20:
			shot = "roof-ride"
		elif not done.has("cart") and _cart_rolling_ahead():
			shot = "cart"
		elif castle and not done.has("castle") and _ahead("train", 10.0, 24.0, true) and _ahead("obstacle", 8.0, 35.0):
			shot = "castle"
		if shot != "":
			RenderingServer.render_loop_enabled = true
			for _i in 3:
				await process_frame
			_save(out_dir.path_join("obstacles-%d-%s.png" % [done.size() + 1, shot]))
			done[shot] = true
			cooldown = 60 * 3
			RenderingServer.render_loop_enabled = false
	for w in wanted:
		if not done.has(w):
			push_error("capture: no '%s' shot" % w)
	if upgrades:
		upgrades.set("levels", saved_levels)
	quit(0 if done.size() == wanted.size() else 1)


func _ahead(group: String, near: float, far: float, other_lane: bool = false) -> bool:
	for n in get_root().get_tree().get_nodes_in_group(group):
		var n3 := n as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		if other_lane and absf(n3.global_position.x - _player.global_position.x) < 1.0:
			continue
		var dz: float = _player.global_position.z - n3.global_position.z
		if dz >= near and dz <= far:
			return true
	return false


func _cart_rolling_ahead() -> bool:
	for n in get_root().get_tree().get_nodes_in_group("obstacle"):
		var n3 := n as Node3D
		if n3 == null or str(n3.get("pool_id")) != "obstacle_cart" or not n3.is_visible_in_tree():
			continue
		var dz: float = _player.global_position.z - n3.global_position.z
		if bool(n3.get("_rolling")) and dz >= 14.0 and dz <= 30.0:
			return true
	return false


func _save(path: String) -> void:
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("capture %s err=%d draw_calls=%d primitives=%d" % [
		path, err,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	])
