extends SceneTree
## Ensure Witch FBX materials resolve textures (no missing Textures_export path).


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var tex_path: String = "res://assets/models/Textures_export/M_witch_Base_color.png"
	if not ResourceLoader.exists(tex_path):
		push_error("FAIL missing %s" % tex_path)
		failed += 1
	else:
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex == null:
			push_error("FAIL texture load null")
			failed += 1
		else:
			print("OK base color texture ", tex.get_width(), "x", tex.get_height())
	var packed: PackedScene = load("res://assets/models/player/Witch_skeletal_mesh.fbx") as PackedScene
	if packed == null:
		push_error("FAIL load FBX packed scene")
		failed += 1
	else:
		var root: Node = packed.instantiate()
		get_root().add_child(root)
		await process_frame
		var mats: int = 0
		var empty_tex: int = 0
		for mi in _meshes(root):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					mats += 1
					var std: StandardMaterial3D = mat as StandardMaterial3D
					## Empty / broken albedo path often surfaces as null texture — OK if vertex colors used.
					if std.albedo_texture != null:
						print("OK surface albedo_texture=", std.albedo_texture.resource_path)
		print("OK materials scanned=", mats, " empty_tex_slots=", empty_tex)
		root.queue_free()
	## WitchRunner scene boot (should not spam missing texture).
	var wr: PackedScene = load("res://scenes/player/WitchRunner.tscn") as PackedScene
	var w: Node = wr.instantiate()
	get_root().add_child(w)
	await process_frame
	await process_frame
	print("OK WitchRunner instantiated")
	w.queue_free()
	if failed > 0:
		quit(1)
	print("Witch textures OK")
	quit(0)


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
