extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for name in ["Skeleton_Minion", "Skeleton_Rogue", "Skeleton_Warrior", "Skeleton_Mage"]:
		var path := "res://assets/models/skins/%s.fbx" % name
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("FAIL load %s" % path)
			continue
		var root: Node3D = packed.instantiate() as Node3D
		get_root().add_child(root)
		await process_frame
		var sk: Skeleton3D = _find_skel(root)
		print("--- ", name, " ---")
		if sk == null:
			push_error("no skeleton")
		else:
			print("bones=", sk.get_bone_count())
			for i in sk.get_bone_count():
				print("  ", i, " ", sk.get_bone_name(i), " parent=", sk.get_bone_parent(i))
		var meshes := _collect_meshes(root)
		var combined := AABB()
		var first := true
		for mi in meshes:
			var aabb := mi.global_transform * mi.get_aabb()
			if first:
				combined = aabb
				first = false
			else:
				combined = combined.merge(aabb)
			var mat := mi.get_active_material(0)
			var has_tex := mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null
			print("  mesh=", mi.name, " tex=", has_tex)
		print("  AABB size=", combined.size, " pos=", combined.position)
		root.queue_free()
		await process_frame
	quit(0)


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f := _find_skel(c)
		if f:
			return f
	return null


func _collect_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_collect_meshes(c))
	return out
