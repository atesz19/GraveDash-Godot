extends SceneTree
## Headless: compile every res:// GDScript with autoloads registered (zero parse errors).
## godot --headless --path . --script res://tools/validate_scripts_compile.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths: PackedStringArray = PackedStringArray()
	_collect("res://", paths)
	var failed: int = 0
	for path in paths:
		var script: Script = ResourceLoader.load(path) as Script
		if script == null or not script.can_instantiate():
			push_error("FAIL compile %s" % path)
			failed += 1
	print("Compiled %d scripts, failures=%d" % [paths.size(), failed])
	if failed > 0:
		quit(1)
		return
	print("PASS validate_scripts_compile")
	quit(0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub.begins_with(".") or sub == "build":
			continue
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
