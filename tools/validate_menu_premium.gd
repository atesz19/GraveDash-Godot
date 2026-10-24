extends SceneTree
## Headless: premium Main Menu polish — dense edges, character, chrome, atmosphere.


const LANE_CLEAR_X: float = 4.4
const MIN_EDGE_PROPS: int = 60
const MIN_CHUNKS: int = 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var packed: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load MainMenu")
		quit(1)
		return
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var world: Node3D = root.get_node_or_null("MenuWorld") as Node3D
	if world == null:
		push_error("FAIL MenuWorld")
		quit(1)
		return

	var track: Node = world.get_node_or_null("Track")
	var chunks: int = track.get_child_count() if track else 0
	if chunks < MIN_CHUNKS:
		push_error("FAIL track_chunks=%d want>=%d" % [chunks, MIN_CHUNKS])
		failed += 1
	else:
		print("OK track_chunks=", chunks)

	var edge: Node3D = world.get_node_or_null("EdgeDecor") as Node3D
	var edge_n: int = edge.get_child_count() if edge else 0
	if edge_n < MIN_EDGE_PROPS:
		push_error("FAIL EdgeDecor sparse count=%d" % edge_n)
		failed += 1
	else:
		print("OK EdgeDecor count=", edge_n)
	if edge:
		for child in edge.get_children():
			if child is Node3D:
				var x: float = absf((child as Node3D).position.x)
				if x < LANE_CLEAR_X:
					push_error("FAIL edge in lane x=%.2f" % (child as Node3D).position.x)
					failed += 1

	var witch_slot: Node3D = world.get_node_or_null("WitchSlot") as Node3D
	if witch_slot == null or witch_slot.get_child_count() < 1:
		push_error("FAIL witch")
		failed += 1
	else:
		var witch: Node3D = witch_slot.get_child(0) as Node3D
		var sc: float = witch.scale.x if witch else 0.0
		if sc < 1.2:
			push_error("FAIL witch scale=%.2f" % sc)
			failed += 1
		else:
			print("OK witch scale=", sc)

	for light_name in ["WitchSpot", "WitchRim", "FillLight", "GroundFill", "MoonLight"]:
		if world.get_node_or_null(light_name) == null:
			push_error("FAIL light %s" % light_name)
			failed += 1
		else:
			print("OK light ", light_name)

	var atmo: Node = world.get_node_or_null("MenuAtmosphere")
	if atmo == null:
		push_error("FAIL MenuAtmosphere")
		failed += 1
	else:
		print("OK MenuAtmosphere")

	for must in ["Brand", "StartButton", "ShopButton", "SettingsButton", "QuitButton",
			"SoulWalletLabel", "HighScoreLabel", "MultChip", "MissionBar1", "MissionBar2", "MissionBar3",
			"HomeLayer", "MissionsPanel"]:
		if root.find_child(must, true, false) == null:
			push_error("FAIL missing %s" % must)
			failed += 1
		else:
			print("OK ", must)

	var brand: Label = root.find_child("Brand", true, false) as Label
	if brand:
		var fs: int = brand.get_theme_font_size("font_size")
		if fs < 80:
			push_error("FAIL brand font_size=%d" % fs)
			failed += 1
		else:
			print("OK brand font_size=", fs)

	var start_btn: Button = root.find_child("StartButton", true, false) as Button
	var shop_btn: Button = root.find_child("ShopButton", true, false) as Button
	if start_btn and shop_btn:
		if start_btn.custom_minimum_size.x <= shop_btn.custom_minimum_size.x:
			push_error("FAIL START not dominant")
			failed += 1
		else:
			print("OK START dominant")

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_menu_premium")
	quit(0)
