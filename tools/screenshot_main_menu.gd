extends SceneTree
## Capture Main Menu viewport PNG (needs a display; not pure headless).


const OUT_PATH := "user://main_menu_premium.png"
const ARTIFACT := "/opt/cursor/artifacts/screenshots/main-menu-premium.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load MainMenu")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	## Let particles / idle settle a few frames.
	for _i in 12:
		await process_frame
	await create_timer(0.6).timeout
	var img: Image = get_root().get_viewport().get_texture().get_image()
	if img == null:
		push_error("FAIL capture image")
		quit(1)
		return
	## Compatibility/OpenGL path already returns top-left origin — do not flip_y.
	var err: Error = img.save_png(OUT_PATH)
	if err != OK:
		push_error("FAIL save png err=%d" % err)
		quit(1)
		return
	var abs_user: String = ProjectSettings.globalize_path(OUT_PATH)
	print("OK saved ", abs_user)
	## Also copy next to artifacts if possible.
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/screenshots")
	var copy_err: Error = DirAccess.copy_absolute(abs_user, ARTIFACT)
	print("OK artifact copy err=", copy_err, " path=", ARTIFACT)
	quit(0)
