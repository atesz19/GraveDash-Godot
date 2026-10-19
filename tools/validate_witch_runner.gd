extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/player/WitchRunner.tscn") as PackedScene
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	var failed: int = 0
	var ap: AnimationPlayer = root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	for n in ["idle", "run", "jump", "slide", "death"]:
		if ap == null or not ap.has_animation(n):
			push_error("FAIL missing anim %s" % n)
			failed += 1
		else:
			print("OK anim ", n)
	## Materials: no dark override, vertex colors enabled
	var vcol_ok := false
	var dark_override := false
	for mi in _meshes(root):
		if mi.material_override != null:
			var om: Material = mi.material_override
			if om is StandardMaterial3D:
				var sm: StandardMaterial3D = om as StandardMaterial3D
				if sm.albedo_color.r < 0.15 and sm.albedo_color.g < 0.15 and sm.albedo_color.b < 0.15 and not sm.vertex_color_use_as_albedo:
					dark_override = true
		for s in mi.mesh.get_surface_count() if mi.mesh else 0:
			var mat: Material = mi.get_active_material(s)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).vertex_color_use_as_albedo:
				var arr: Array = mi.mesh.surface_get_arrays(s)
				if arr.size() > Mesh.ARRAY_COLOR and arr[Mesh.ARRAY_COLOR] != null:
					vcol_ok = true
	if dark_override:
		push_error("FAIL dark material_override without vertex colors")
		failed += 1
	if not vcol_ok:
		push_error("FAIL no vertex-colored surfaces active")
		failed += 1
	else:
		print("OK vertex colors active")
	var aabb := _aabb(root)
	print("aabb size=", aabb.size)
	if aabb.size.y < 0.5:
		push_error("FAIL model too small")
		failed += 1
	if failed > 0:
		quit(1)
	print("WitchRunner visibility OK")
	quit(0)


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _aabb(n: Node) -> AABB:
	var first := true
	var out := AABB()
	for mi in _meshes(n):
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out
