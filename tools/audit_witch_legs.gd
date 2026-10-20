extends SceneTree
## Dump Witch leg bone rests + sampled run poses (diagnose skyward right leg).


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/player/WitchRunner.tscn") as PackedScene
	var root: Node3D = packed.instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	var sk: Skeleton3D = _find_skel(root)
	if sk == null:
		push_error("no skeleton")
		quit(1)
		return
	print("bone_count=", sk.get_bone_count())
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i)
		var interesting: bool = (
			"Hip" in n or "Knee" in n or "Ankle" in n or "Foot" in n
			or "Toe" in n or "Root" in n or "Leg" in n
		)
		if not interesting:
			continue
		var rest: Transform3D = sk.get_bone_rest(i)
		var parent: int = sk.get_bone_parent(i)
		var pname: String = sk.get_bone_name(parent) if parent >= 0 else "(none)"
		print("BONE ", i, " ", n, " parent=", pname)
		print("  rest.origin=", rest.origin)
		print("  rest.basis.x=", rest.basis.x)
		print("  rest.basis.y=", rest.basis.y)
		print("  rest.basis.z=", rest.basis.z)
		var children: Array = []
		for j in sk.get_bone_count():
			if sk.get_bone_parent(j) == i:
				children.append(sk.get_bone_name(j))
		print("  children=", children)

	var tree: AnimationTree = root.get_node_or_null("AnimationTree") as AnimationTree
	if tree:
		tree.active = false
	var ap: AnimationPlayer = root.get_node("AnimationPlayer") as AnimationPlayer
	ap.play("RESET") if ap.has_animation("RESET") else null
	sk.reset_bone_poses()
	await process_frame
	_print_leg_globals(sk, "REST")

	for t in [0.0, 0.18, 0.36, 0.54, 0.72]:
		ap.play("run")
		ap.seek(t, true)
		await process_frame
		_print_leg_globals(sk, "run t=%.2f" % t)

	## Also sample a few degrees of pure Hip_R swing to learn axis meaning.
	sk.reset_bone_poses()
	var hip_r: int = sk.find_bone("Hip_R")
	var knee_r: int = sk.find_bone("Knee_R")
	var hip_l: int = sk.find_bone("Hip_L")
	if hip_r >= 0:
		for deg in [-40.0, 40.0]:
			sk.reset_bone_poses()
			var q: Quaternion = Quaternion(Vector3(0, 0, 1), deg_to_rad(deg))
			sk.set_bone_pose_rotation(hip_r, q)
			await process_frame
			_print_leg_globals(sk, "Hip_R swingZ=%s" % deg)
		for deg in [-40.0, 40.0]:
			sk.reset_bone_poses()
			var q2: Quaternion = Quaternion(Vector3(1, 0, 0), deg_to_rad(deg))
			sk.set_bone_pose_rotation(hip_r, q2)
			await process_frame
			_print_leg_globals(sk, "Hip_R twistX=%s" % deg)
		for deg in [-40.0, 40.0]:
			sk.reset_bone_poses()
			var q3: Quaternion = Quaternion(Vector3(0, 1, 0), deg_to_rad(deg))
			sk.set_bone_pose_rotation(hip_r, q3)
			await process_frame
			_print_leg_globals(sk, "Hip_R sideY=%s" % deg)
	if hip_l >= 0:
		for deg in [-40.0, 40.0]:
			sk.reset_bone_poses()
			var ql: Quaternion = Quaternion(Vector3(0, 0, 1), deg_to_rad(deg))
			sk.set_bone_pose_rotation(hip_l, ql)
			await process_frame
			_print_leg_globals(sk, "Hip_L swingZ=%s" % deg)
	if knee_r >= 0:
		for deg in [40.0, -40.0]:
			sk.reset_bone_poses()
			var qk: Quaternion = Quaternion(Vector3(0, 0, 1), deg_to_rad(deg))
			sk.set_bone_pose_rotation(knee_r, qk)
			await process_frame
			_print_leg_globals(sk, "Knee_R swingZ=%s" % deg)
	quit(0)


func _print_leg_globals(sk: Skeleton3D, label: String) -> void:
	print("--- ", label, " ---")
	for name in ["Root_M", "Hip_L", "Hip_R", "Knee_L", "Knee_R", "Ankle_L", "Ankle_R", "Toes_L", "Toes_R"]:
		var idx: int = sk.find_bone(name)
		if idx < 0:
			continue
		var gt: Transform3D = sk.global_transform * sk.get_bone_global_pose(idx)
		print(
			"%s y=%.3f z=%.3f x=%.3f" % [
				name, gt.origin.y, gt.origin.z, gt.origin.x
			]
		)


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f: Skeleton3D = _find_skel(c)
		if f != null:
			return f
	return null
