extends SceneTree
## Headless: no black veil / dense fog / crushed castle exposure during play.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var packed: PackedScene = load("res://scenes/levels/BiomeTransition.tscn") as PackedScene
	var trans: CanvasLayer = packed.instantiate() as CanvasLayer
	get_root().add_child(trans)
	await process_frame
	var veil: ColorRect = trans.get_node_or_null("Veil") as ColorRect
	if veil == null:
		push_error("FAIL veil missing")
		failed += 1
	elif veil.visible or veil.modulate.a > 0.01 or veil.color.a > 0.01:
		push_error("FAIL veil not inert visible=%s a=%.2f color.a=%.2f" % [veil.visible, veil.modulate.a, veil.color.a])
		failed += 1
	else:
		print("OK veil inert")

	var src := FileAccess.open("res://scripts/levels/BiomeTransition.gd", FileAccess.READ)
	var body := src.get_as_text() if src else ""
	if "fog_density =" in body or "modulate:a\", 1.0" in body:
		push_error("FAIL BiomeTransition still ramps fog/veil to black")
		failed += 1
	else:
		print("OK BiomeTransition no fog/veil ramp")

	var castle: Environment = load("res://resources/biomes/haunted_castle_environment.tres") as Environment
	var grave: Environment = load("res://resources/biomes/graveyard_environment.tres") as Environment
	if castle == null or grave == null:
		push_error("FAIL env load")
		failed += 1
	else:
		if castle.fog_density > 0.035:
			push_error("FAIL castle fog_density too high %.3f" % castle.fog_density)
			failed += 1
		else:
			print("OK castle fog_density=", castle.fog_density)
		if castle.adjustment_brightness < 0.92:
			push_error("FAIL castle brightness crushed %.2f" % castle.adjustment_brightness)
			failed += 1
		else:
			print("OK castle brightness=", castle.adjustment_brightness)
		if castle.tonemap_exposure < 0.95:
			push_error("FAIL castle exposure crushed %.2f" % castle.tonemap_exposure)
			failed += 1
		else:
			print("OK castle exposure=", castle.tonemap_exposure)

	var bm: Node = get_root().get_node_or_null("BiomeManager")
	if bm:
		var data: Dictionary = bm.call("get_biome_data", "haunted_castle")
		var moon_e: float = float(data.get("moon_energy", 0.0))
		if moon_e < 0.55:
			push_error("FAIL castle moon_energy too low %.2f" % moon_e)
			failed += 1
		else:
			print("OK castle moon_energy=", moon_e)
		## Simulate transition path.
		bm.call("start_run_biome")
		bm.set("_castle_trigger_m", 10.0)
		bm.set("_castle_reached", false)
		bm.set("_transitioning", false)
		## Fake playing + distance.
		var gm: Node = get_root().get_node_or_null("GameManager")
		var sm: Node = get_root().get_node_or_null("ScoreManager")
		if gm and sm and gm.has_method("is_playing"):
			## Bind a throwaway WorldEnvironment so clamps apply.
			var we := WorldEnvironment.new()
			we.environment = grave.duplicate() as Environment
			get_root().add_child(we)
			var light := DirectionalLight3D.new()
			get_root().add_child(light)
			bm.call("bind_world", we, light)
			bm.call("start_run_biome")
			trans.call("play_transition", "haunted_castle")
			await process_frame
			if veil.visible or veil.modulate.a > 0.01:
				push_error("FAIL veil active after transition")
				failed += 1
			else:
				print("OK veil stays off after transition")
			var env: Environment = we.environment
			if env.fog_density > 0.035:
				push_error("FAIL post-transition fog %.3f" % env.fog_density)
				failed += 1
			else:
				print("OK post-transition fog=", env.fog_density)
			if light.light_energy < 0.55:
				push_error("FAIL post-transition moon %.2f" % light.light_energy)
				failed += 1
			else:
				print("OK post-transition moon=", light.light_energy)

	var torch_src := FileAccess.open("res://scripts/props/Torch.gd", FileAccess.READ)
	var torch_body := torch_src.get_as_text() if torch_src else ""
	if "0.82" in torch_body and "flicker" in torch_body:
		## Old deep flicker floor.
		if "clampf(flicker, 0.92" not in torch_body:
			push_error("FAIL torch flicker still dips hard")
			failed += 1
		else:
			print("OK torch flicker clamped")
	elif "clampf(flicker, 0.92" in torch_body:
		print("OK torch flicker clamped")
	else:
		push_error("FAIL torch clamp missing")
		failed += 1

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_no_blackout")
	quit(0)
