extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: Node3D = (load("res://scenes/player/WitchRunner.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	## Completely strip animation systems before they tick.
	for child in root.get_children():
		if child is AnimationPlayer or child is AnimationTree:
			child.queue_free()
	await process_frame
	var sk: Skeleton3D = _find_skel(root)
	for bn in ["Hip_L", "Hip_R", "Knee_L", "Knee_R"]:
		var i: int = sk.find_bone(bn)
		sk.reset_bone_pose(i)
		var pose: Transform3D = sk.get_bone_pose(i)
		print(bn, " after reset_bone_pose:")
		print("  pose=", pose)
		print("  pose_rot=", sk.get_bone_pose_rotation(i))
		print("  pose_pos=", sk.get_bone_pose_position(i))
		print("  pose_scale=", sk.get_bone_pose_scale(i))
	sk.force_update_all_bone_transforms()
	await process_frame
	print("AFTER RESET ankles L/R y", _y(sk, "Ankle_L"), _y(sk, "Ankle_R"))

	## Set only rotation identity, keep pose pos/scale from reset
	var hr: int = sk.find_bone("Hip_R")
	sk.reset_bone_pose(hr)
	sk.set_bone_pose_rotation(hr, Quaternion.IDENTITY)
	sk.force_update_all_bone_transforms()
	await process_frame
	print("Hip_R IDENTITY rot only: Ankle_R y=", _y(sk, "Ankle_R"), " pose=", sk.get_bone_pose(hr))

	## Set full identity pose transform
	sk.reset_bone_pose(hr)
	sk.set_bone_pose(hr, Transform3D.IDENTITY)
	sk.force_update_all_bone_transforms()
	await process_frame
	print("Hip_R full IDENTITY pose: Ankle_R y=", _y(sk, "Ankle_R"), " pose=", sk.get_bone_pose(hr))

	## What quaternion equals "reset" pose rotation for Hip_R?
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	await process_frame
	print("reset_all Hip_R pose_rot=", sk.get_bone_pose_rotation(hr), " Ankle_R y=", _y(sk, "Ankle_R"))

	## Try animating Hip_R via set_bone_pose with rest*delta
	var rest: Transform3D = sk.get_bone_rest(hr)
	for deg in [-30.0, 0.0, 30.0]:
		sk.reset_bone_pose(hr)
		var delta: Transform3D = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(deg)), Vector3.ZERO)
		## Wrong: pose should be delta only. Try parent-space aim.
		sk.set_bone_pose_rotation(hr, Quaternion(Vector3(0, 0, 1), deg_to_rad(deg)))
		sk.force_update_all_bone_transforms()
		await process_frame
		print("pose Z ", deg, " Ankle_R y/z=", _y(sk, "Ankle_R"), "/", _z(sk, "Ankle_R"))

	## Use global_pose_override to swing right leg forward
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	await process_frame
	var gp: Transform3D = sk.get_bone_global_pose(hr)
	## Rotate around world X (pitch) to swing leg forward (-Z)
	for deg in [-40.0, 40.0]:
		sk.reset_bone_poses()
		sk.force_update_all_bone_transforms()
		var base: Transform3D = sk.get_bone_global_pose(hr)
		var swung: Transform3D = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(deg)) * base.basis, base.origin)
		sk.set_bone_global_pose_override(hr, swung, 1.0, true)
		sk.force_update_all_bone_transforms()
		await process_frame
		print("global override pitchX ", deg, " Ankle_R y/z=", _y(sk, "Ankle_R"), "/", _z(sk, "Ankle_R"))
		sk.clear_bones_global_pose_override()

	for deg in [-40.0, 40.0]:
		sk.reset_bone_poses()
		sk.force_update_all_bone_transforms()
		var base2: Transform3D = sk.get_bone_global_pose(hr)
		var swung2: Transform3D = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(deg)) * base2.basis, base2.origin)
		sk.set_bone_global_pose_override(hr, swung2, 1.0, true)
		sk.force_update_all_bone_transforms()
		await process_frame
		print("global override rollZ ", deg, " Ankle_R y/z=", _y(sk, "Ankle_R"), "/", _z(sk, "Ankle_R"))
		sk.clear_bones_global_pose_override()

	quit(0)


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
