extends SceneTree
## Find which local rotation axes swing Hip_L/Hip_R forward and flex knees.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/player/WitchRunner.tscn") as PackedScene
	var root: Node3D = packed.instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	await process_frame
	var tree: AnimationTree = root.get_node_or_null("AnimationTree") as AnimationTree
	if tree:
		tree.active = false
		tree.process_mode = Node.PROCESS_MODE_DISABLED
	var ap: AnimationPlayer = root.get_node("AnimationPlayer") as AnimationPlayer
	ap.stop()
	ap.process_mode = Node.PROCESS_MODE_DISABLED
	var sk: Skeleton3D = _find_skel(root)
	sk.reset_bone_poses()
	await process_frame
	_dump(sk, "REST")

	var axes: Array[Vector3] = [
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1),
		Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1),
	]
	var axis_names: Array[String] = ["+X", "+Y", "+Z", "-X", "-Y", "-Z"]

	for bone_name in ["Hip_L", "Hip_R", "Knee_L", "Knee_R"]:
		var bi: int = sk.find_bone(bone_name)
		if bi < 0:
			continue
		print("==== ", bone_name, " ====")
		for i in axes.size():
			sk.reset_bone_poses()
			var q: Quaternion = Quaternion(axes[i], deg_to_rad(35.0))
			sk.set_bone_pose_rotation(bi, q)
			## Force skeleton update
			sk.force_update_all_bone_transforms()
			await process_frame
			var ankle_name: String = "Ankle_R" if bone_name.ends_with("_R") else "Ankle_L"
			var toe_name: String = "Toes_R" if bone_name.ends_with("_R") else "Toes_L"
			var knee_name: String = "Knee_R" if bone_name.ends_with("_R") else "Knee_L"
			var ay: float = _wy(sk, ankle_name)
			var az: float = _wz(sk, ankle_name)
			var ky: float = _wy(sk, knee_name)
			var kz: float = _wz(sk, knee_name)
			var ty: float = _wy(sk, toe_name)
			print(
				"  rot35 ", axis_names[i],
				" knee(y,z)=(%.3f,%.3f) ankle(y,z)=(%.3f,%.3f) toes_y=%.3f" % [ky, kz, ay, az, ty]
			)
	quit(0)


func _dump(sk: Skeleton3D, label: String) -> void:
	print("--- ", label, " ---")
	for n in ["Knee_L", "Knee_R", "Ankle_L", "Ankle_R", "Toes_L", "Toes_R"]:
		print("%s y=%.3f z=%.3f" % [n, _wy(sk, n), _wz(sk, n)])


func _wy(sk: Skeleton3D, name: String) -> float:
	var i: int = sk.find_bone(name)
	if i < 0:
		return 999.0
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin.y


func _wz(sk: Skeleton3D, name: String) -> float:
	var i: int = sk.find_bone(name)
	if i < 0:
		return 999.0
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin.z


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f: Skeleton3D = _find_skel(c)
		if f != null:
			return f
	return null
