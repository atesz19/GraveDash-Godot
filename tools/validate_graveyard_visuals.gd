extends SceneTree
## Headless: graveyard env/materials/backdrop/torch load without script errors.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	await process_frame
	## Resources
	var env: Environment = load("res://resources/biomes/graveyard_environment.tres") as Environment
	if env == null or env.background_mode != Environment.BG_SKY:
		push_error("FAIL graveyard_environment sky mode")
		failed += 1
	else:
		print("OK environment sky fog=", env.fog_enabled, " glow=", env.glow_enabled)
	var ground: StandardMaterial3D = load("res://resources/biomes/graveyard_ground.tres") as StandardMaterial3D
	if ground == null or ground.normal_texture == null or ground.albedo_texture == null:
		push_error("FAIL graveyard_ground textures")
		failed += 1
	else:
		print("OK ground albedo+normal+roughness")
	var shoulder: StandardMaterial3D = load("res://resources/biomes/graveyard_shoulder.tres") as StandardMaterial3D
	if shoulder == null or not shoulder.detail_enabled:
		push_error("FAIL graveyard_shoulder detail")
		failed += 1
	else:
		print("OK shoulder leaf detail")
	## Scenes
	for path in [
		"res://scenes/levels/Chunk_Graveyard_01.tscn",
		"res://scenes/levels/GraveyardBackdrop.tscn",
		"res://scenes/levels/props/Torch.tscn",
		"res://scenes/levels/Main.tscn",
		"res://scenes/ui/MenuWorld.tscn",
	]:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("FAIL load %s" % path)
			failed += 1
			continue
		var n: Node = packed.instantiate()
		get_root().add_child(n)
		await process_frame
		await process_frame
		print("OK instantiate ", path)
		if path.ends_with("Main.tscn"):
			if n.get_node_or_null("GraveyardBackdrop") == null:
				push_error("FAIL Main missing GraveyardBackdrop")
				failed += 1
			else:
				print("OK Main has GraveyardBackdrop")
			var moon: DirectionalLight3D = n.get_node_or_null("MoonLight") as DirectionalLight3D
			if moon == null or not moon.shadow_enabled:
				push_error("FAIL moonlight shadows")
				failed += 1
			else:
				print("OK moonlight energy=", moon.light_energy)
		if path.ends_with("MenuWorld.tscn"):
			if n.get_node_or_null("Backdrop") == null:
				push_error("FAIL MenuWorld missing Backdrop")
				failed += 1
			else:
				print("OK MenuWorld Backdrop")
		if path.ends_with("Torch.tscn"):
			if n.get_script() == null:
				push_error("FAIL Torch script missing")
				failed += 1
			else:
				print("OK Torch flicker script")
		n.queue_free()
		await process_frame
	if failed > 0:
		quit(1)
	print("Graveyard visuals OK")
	quit(0)
