extends SceneTree
## Isolate Hip_R pose composition vs Hip_L.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: Node3D = (load("res://scenes/player/WitchRunner.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	var tree: AnimationTree = root.get_node_or_null("AnimationTree")
	if tree:
		tree.active = false
		tree.process_mode = Node.PROCESS_MODE_DISABLED
	var ap: AnimationPlayer = root.get_node("AnimationPlayer")
	ap.stop()
	ap.process_mode = Node.PROCESS_MODE_DISABLED
	var sk: Skeleton3D = _find_skel(root)

	for bone_name in ["Hip_L", "Hip_R"]:
		var bi: int = sk.find_bone(bone_name)
		print("==== ", bone_name, " pose tests ====")
		sk.reset_bone_poses()
		sk.force_update_all_bone_transforms()
		await process_frame
		_print(sk, bone_name, "identity/reset")

		sk.reset_bone_poses()
		sk.set_bone_pose_rotation(bi, Quaternion.IDENTITY)
		sk.force_update_all_bone_transforms()
		await process_frame
		_print(sk, bone_name, "explicit IDENTITY")

		## Small angle only
		for axis_name in ["Z", "Y", "X"]:
			var axis: Vector3 = Vector3(0, 0, 1)
			if axis_name == "Y":
				axis = Vector3(0, 1, 0)
			elif axis_name == "X":
				axis = Vector3(1, 0, 0)
			for deg in [5.0, 15.0, 25.0, -15.0, -25.0]:
				sk.reset_bone_poses()
				sk.set_bone_pose_rotation(bi, Quaternion(axis, deg_to_rad(deg)))
				sk.force_update_all_bone_transforms()
				await process_frame
				var ankle: String = "Ankle_R" if bone_name.ends_with("_R") else "Ankle_L"
				var knee: String = "Knee_R" if bone_name.ends_with("_R") else "Knee_L"
				print(
					"  %s %s° knee_y=%.3f ankle_y=%.3f ankle_z=%.3f" % [
						axis_name, deg, _y(sk, knee), _y(sk, ankle), _z(sk, ankle)
					]
				)

	## Compare rest global bases of hips
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	await process_frame
	for bn in ["Hip_L", "Hip_R"]:
		var i: int = sk.find_bone(bn)
		var gp: Transform3D = sk.get_bone_global_pose(i)
		print(bn, " global_pose.basis.x=", gp.basis.x)
		print(bn, " global_pose.basis.y=", gp.basis.y)
		print(bn, " global_pose.basis.z=", gp.basis.z)
		print(bn, " pose_rotation=", sk.get_bone_pose_rotation(i))
		print(bn, " rest=", sk.get_bone_rest(i).basis)
	quit(0)


func _print(sk: Skeleton3D, bone_name: String, label: String) -> void:
	var knee: String = "Knee_R" if bone_name.ends_with("_R") else "Knee_L"
	var ankle: String = "Ankle_R" if bone_name.ends_with("_R") else "Ankle_L"
	print(label, " knee_y=%.3f ankle_y=%.3f ankle_z=%.3f" % [_y(sk, knee), _y(sk, ankle), _z(sk, ankle)])


func _y(sk: Skeleton3D, n: String) -> float:
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n))).origin.y


func _z(sk: Skeleton3D, n: String) -> float:
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n))).origin.z


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f: Skeleton3D = _find_skel(c)
		if f:
			return f
	return null
