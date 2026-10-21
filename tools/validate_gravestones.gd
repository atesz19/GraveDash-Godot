extends SceneTree
## Headless: PBR gravestone props load with materials; stay off lane centers.


const LANE_CLEAR_X: float = 4.4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	for i in range(1, 5):
		var mat_path := "res://resources/materials/gravestones/gravestone_0%d.tres" % i
		var mat: StandardMaterial3D = load(mat_path) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null or mat.normal_texture == null or mat.roughness_texture == null:
			push_error("FAIL material incomplete %s" % mat_path)
			failed += 1
		else:
			print("OK mat 0%d albedo+normal+rough" % i)
		if i == 2 and mat and mat.metallic_texture == null:
			push_error("FAIL 02 missing metallic")
			failed += 1
		var prop_path := "res://scenes/levels/props/DecorGravestone_0%d.tscn" % i
		var packed: PackedScene = load(prop_path) as PackedScene
		if packed == null:
			push_error("FAIL prop %s" % prop_path)
			failed += 1
			continue
		var n: Node3D = packed.instantiate() as Node3D
		get_root().add_child(n)
		await process_frame
		await process_frame
		var mi := _find_mesh(n)
		if mi == null:
			push_error("FAIL no mesh in %s" % prop_path)
			failed += 1
		else:
			var active: Material = mi.get_active_material(0)
			var ok_mat := active is StandardMaterial3D and (active as StandardMaterial3D).albedo_texture != null
			if not ok_mat:
				push_error("FAIL no PBR override on %s" % prop_path)
				failed += 1
			else:
				var aabb: AABB = mi.global_transform * mi.get_aabb()
				print("OK prop 0%d height=%.2f width=%.2f" % [i, aabb.size.y, aabb.size.x])
				if aabb.size.y < 0.4 or aabb.size.y > 2.5:
					push_error("FAIL unexpected height %.2f" % aabb.size.y)
					failed += 1
		n.queue_free()
		await process_frame

	var decor: PackedScene = load("res://scenes/levels/props/DecorGravestone.tscn") as PackedScene
	var d: Node3D = decor.instantiate() as Node3D
	get_root().add_child(d)
	await process_frame
	await process_frame
	if d.get_child_count() < 1:
		push_error("FAIL random DecorGravestone empty")
		failed += 1
	else:
		print("OK random DecorGravestone child=", d.get_child(0).name)
	d.queue_free()

	var obs: PackedScene = load("res://scenes/obstacles/ObstacleGravestone.tscn") as PackedScene
	var o: Node3D = obs.instantiate() as Node3D
	get_root().add_child(o)
	await process_frame
	await process_frame
	var vis: Node = o.get_node_or_null("Visual")
	if vis == null or vis.get_child_count() < 1:
		push_error("FAIL ObstacleGravestone visual empty")
		failed += 1
	else:
		print("OK ObstacleGravestone visual=", vis.get_child(0).name)
	o.queue_free()

	var menu_ps: PackedScene = load("res://scenes/ui/MenuWorld.tscn") as PackedScene
	var menu: Node3D = menu_ps.instantiate() as Node3D
	get_root().add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	var edge: Node3D = menu.get_node_or_null("EdgeDecor") as Node3D
	var grave_count := 0
	if edge:
		for c in edge.get_children():
			if String(c.name).begins_with("DecorGravestone") or _find_mesh(c) != null:
				if absf((c as Node3D).position.x) < LANE_CLEAR_X:
					push_error("FAIL edge prop in lane x=%.2f" % (c as Node3D).position.x)
					failed += 1
			if String(c.name).begins_with("DecorGravestone"):
				grave_count += 1
	print("OK MenuWorld EdgeDecor graves≈", grave_count, " total=", edge.get_child_count() if edge else 0)

	var chunk_ps: PackedScene = load("res://scenes/levels/Chunk_Graveyard_01.tscn") as PackedScene
	var chunk: Node3D = chunk_ps.instantiate() as Node3D
	get_root().add_child(chunk)
	await process_frame
	await process_frame
	var props: Node = chunk.get_node_or_null("Props")
	var stones := 0
	if props:
		for c in props.get_children():
			if String(c.name).begins_with("Stone"):
				stones += 1
				if absf((c as Node3D).position.x) < LANE_CLEAR_X:
					push_error("FAIL chunk stone in lane")
					failed += 1
	print("OK chunk Stone* count=", stones)

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_gravestones")
	quit(0)


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var found := _find_mesh(c)
		if found:
			return found
	return null
