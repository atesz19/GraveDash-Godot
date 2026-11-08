extends SceneTree
## Capture the Main Menu with each skin equipped (needs a display; not pure headless).
## Does not persist: sets SkinManager state in memory only.

const OUT_DIR := "/opt/cursor/artifacts/screenshots"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var sm: Node = get_root().get_node("SkinManager")
	await process_frame
	var ids: PackedStringArray = PackedStringArray()
	for skin in sm.call("get_catalog"):
		ids.append(str(skin.get("id", "")))
	sm.set("owned_ids", ids)
	var menu: Node = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	for id in ids:
		sm.set("equipped_id", id)
		menu.get_node("MenuWorld").call("_spawn_witch")
		menu.get_node("MenuWorld").call("_play_witch", "idle")
		await create_timer(0.8).timeout
		get_root().get_viewport().get_texture().get_image().save_png("%s/menu-skin-%s.png" % [OUT_DIR, id])
		print("saved menu-skin-", id)
	menu.queue_free()
	for id in ["witch", "skeleton_minion", "skeleton_mage"]:
		sm.set("equipped_id", id)
		var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
		get_root().add_child(main)
		await create_timer(1.2).timeout
		get_root().get_viewport().get_texture().get_image().save_png("%s/gameplay-skin-%s.png" % [OUT_DIR, id])
		print("saved gameplay-skin-", id)
		main.queue_free()
		await process_frame
	quit(0)
