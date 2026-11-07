extends SceneTree
## Capture Soul Shop tabs (Skins + Upgrades) as PNGs (needs a display; not pure headless).

const OUT_DIR := "/opt/cursor/artifacts/screenshots"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var sm: Node = get_root().get_node("ScoreManager")
	var um: Node = get_root().get_node("UpgradeManager")
	await process_frame
	sm.set("total_souls", 1450)
	um.set("levels", {"ghost_duration": 2, "magnet_radius": 1, "big_soul_value": 5, "head_start": 1})
	var root: Node = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	for _i in 10:
		await process_frame
	root.call("_on_shop")
	await create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	get_root().get_viewport().get_texture().get_image().save_png(OUT_DIR + "/shop-skins.png")
	root.call("_show_shop_tab", "upgrades")
	await create_timer(0.4).timeout
	get_root().get_viewport().get_texture().get_image().save_png(OUT_DIR + "/shop-upgrades.png")
	print("saved shop screenshots")
	quit(0)
