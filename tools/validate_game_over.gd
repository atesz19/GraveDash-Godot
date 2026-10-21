extends SceneTree
## Headless smoke: GameOverUI loads, unique nodes resolve, count-up + NEW BEST path.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var packed: PackedScene = load("res://scenes/ui/GameOverUI.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load GameOverUI")
		quit(1)
		return
	var ui: CanvasLayer = packed.instantiate() as CanvasLayer
	get_root().add_child(ui)
	await process_frame
	await process_frame

	for must in [
		"Root", "Dim", "Panel", "Title", "DistanceLabel", "SoulsLabel",
		"ScoreLabel", "MultLabel", "BestLabel", "NewBestBadge",
		"RestartButton", "MenuButton", "AdButton", "Mission1",
	]:
		if ui.get_node_or_null("%" + must) == null and ui.find_child(must, true, false) == null:
			push_error("FAIL missing %s" % must)
			failed += 1
		else:
			print("OK ", must)

	var theme_ok := false
	var root_ctrl: Control = ui.get_node_or_null("%Root") as Control
	if root_ctrl and root_ctrl.theme:
		theme_ok = String(root_ctrl.theme.resource_path).ends_with("MainMenuTheme.tres")
	if not theme_ok:
		push_error("FAIL MainMenuTheme not applied on Root")
		failed += 1
	else:
		print("OK MainMenuTheme")

	var sm: Node = get_root().get_node_or_null("ScoreManager")
	var gm: Node = get_root().get_node_or_null("GameManager")
	var mm: Node = get_root().get_node_or_null("MissionManager")
	if sm == null or gm == null:
		push_warning("Autoloads missing in -s context; skipping live overlay path")
	else:
		ui.set("_best_at_run_start", 50)
		sm.set("score", 120)
		sm.set("run_souls", 14)
		sm.set("highscore", 120)
		sm.set("total_souls", 40)
		sm.set("distance", 85.0)
		if mm and mm.has_method("get_multiplier"):
			print("OK multiplier=", mm.call("get_multiplier"))
		ui.call("_show_overlay")
		await process_frame
		await process_frame
		var root_vis: Control = ui.get_node("%Root") as Control
		if root_vis == null or not root_vis.visible:
			push_error("FAIL overlay not visible")
			failed += 1
		else:
			print("OK overlay visible")
		var badge: Control = ui.get_node("%NewBestBadge") as Control
		if badge == null or not badge.visible:
			push_error("FAIL NEW BEST badge hidden on beat")
			failed += 1
		else:
			print("OK NEW BEST badge")
		var ad: Button = ui.get_node("%AdButton") as Button
		if ad == null or not ad.disabled:
			push_error("FAIL AdButton should be disabled")
			failed += 1
		else:
			print("OK AdButton disabled")
		## Let count-up advance briefly.
		await create_timer(0.2).timeout
		var score_lbl: Label = ui.get_node("%ScoreLabel") as Label
		if score_lbl == null or score_lbl.text == "":
			push_error("FAIL ScoreLabel empty")
			failed += 1
		else:
			print("OK ScoreLabel=", score_lbl.text)

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_game_over")
	quit(0)
