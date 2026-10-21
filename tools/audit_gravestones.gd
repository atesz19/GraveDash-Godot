extends SceneTree
## Inspect imported gravestone FBX: AABB, materials, texture binding.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in range(1, 5):
		var path := "res://assets/models/gravestones/gravestone_0%d.fbx" % i
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("FAIL load %s" % path)
			continue
		var root: Node3D = packed.instantiate() as Node3D
		get_root().add_child(root)
		await process_frame
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(root, meshes)
		print("--- gravestone_0%d meshes=%d ---" % [i, meshes.size()])
		var combined := AABB()
		var first := true
		for mi in meshes:
			var aabb: AABB = mi.get_aabb()
			var xf_aabb := mi.global_transform * aabb
			if first:
				combined = xf_aabb
				first = false
			else:
				combined = combined.merge(xf_aabb)
			print("  mesh=", mi.name, " aabb=", aabb.size, " pos=", mi.position)
			for s in mi.mesh.get_surface_count() if mi.mesh else 0:
				var mat: Material = mi.get_active_material(s)
				if mat == null and mi.mesh:
					mat = mi.mesh.surface_get_material(s)
				_print_mat(mat)
		print("  COMBINED size=", combined.size, " pos=", combined.position)
		root.queue_free()
		await process_frame
	quit(0)


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes(c, out)


func _print_mat(mat: Material) -> void:
	if mat == null:
		print("    mat=null")
		return
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		print(
			"    Standard albedo_tex=",
			sm.albedo_texture != null,
			" normal=",
			sm.normal_enabled,
			" rough_tex=",
			sm.roughness_texture != null,
			" metal_tex=",
			sm.metallic_texture != null,
			" albedo=",
			sm.albedo_color
		)
	elif mat is BaseMaterial3D:
		print("    BaseMaterial ", mat)
	else:
		print("    mat_type=", mat.get_class(), " ", mat.resource_path)
