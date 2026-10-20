extends SceneTree
## Headless check: both ankles stay near ground; no skyward right leg.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: Node3D = (load("res://scenes/player/WitchRunner.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame

	## Isolate AnimationPlayer — AnimationTree owns the skeleton otherwise.
	var tree: AnimationTree = root.get_node_or_null("AnimationTree") as AnimationTree
	if tree:
		tree.active = false
		tree.queue_free()
		await process_frame

	var sk: Skeleton3D = _find_skel(root)
	var ap: AnimationPlayer = root.get_node("AnimationPlayer") as AnimationPlayer
	ap.active = true
	ap.process_mode = Node.PROCESS_MODE_ALWAYS

	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	await process_frame
	var rest_l: float = _y(sk, "Ankle_L")
	var rest_r: float = _y(sk, "Ankle_R")
	print("REST Ankle L/R y=%.3f/%.3f z=%.3f/%.3f" % [rest_l, rest_r, _z(sk, "Ankle_L"), _z(sk, "Ankle_R")])

	## Probe rest∘delta Hip swings (same signed local Z).
	print("--- probe Hip rest*delta Z ---")
	for bone_name in ["Hip_L", "Hip_R"]:
		var bi: int = sk.find_bone(bone_name)
		var rest_q: Quaternion = sk.get_bone_rest(bi).basis.get_rotation_quaternion()
		var ankle: String = "Ankle_R" if bone_name.ends_with("_R") else "Ankle_L"
		for deg in [-40.0, -20.0, 0.0, 20.0, 40.0]:
			sk.reset_bone_poses()
			sk.set_bone_pose_rotation(bi, rest_q * Quaternion(Vector3(0, 0, 1), deg_to_rad(deg)))
			sk.force_update_all_bone_transforms()
			print(
				"  %s Z%+.0f ankle y/z=%.3f/%.3f" % [bone_name, deg, _y(sk, ankle), _z(sk, ankle)]
			)

	print("--- probe Knee rest*delta Z ---")
	for bone_name in ["Knee_L", "Knee_R"]:
		var bi2: int = sk.find_bone(bone_name)
		var rest_q2: Quaternion = sk.get_bone_rest(bi2).basis.get_rotation_quaternion()
		var ankle2: String = "Ankle_R" if bone_name.ends_with("_R") else "Ankle_L"
		for deg in [0.0, 30.0, 60.0, -30.0]:
			sk.reset_bone_poses()
			sk.set_bone_pose_rotation(bi2, rest_q2 * Quaternion(Vector3(0, 0, 1), deg_to_rad(deg)))
			sk.force_update_all_bone_transforms()
			print(
				"  %s Z%+.0f ankle y/z=%.3f/%.3f" % [bone_name, deg, _y(sk, ankle2), _z(sk, ankle2)]
			)

	var fail: int = 0
	fail += await _sample_clip(ap, sk, "run", [0.0, 0.12, 0.18, 0.36, 0.54, 0.72], rest_l, rest_r, 0.55)
	fail += await _sample_clip(ap, sk, "idle", [0.0, 1.2, 2.4], rest_l, rest_r, 0.35)
	fail += await _sample_clip(ap, sk, "ghost", [0.0, 0.5, 1.0], rest_l, rest_r, 0.65)
	fail += await _sample_clip(ap, sk, "jump", [0.0, 0.12, 0.3, 0.55, 0.78, 0.95], rest_l, rest_r, 0.85)
	fail += await _sample_clip(ap, sk, "slide", [0.0, 0.3, 0.85], rest_l, rest_r, 1.1)
	## Death collapses toward the floor — allow deeper ankles, still reject skyward.
	fail += await _sample_clip(ap, sk, "death", [0.0, 0.5, 1.15], rest_l, rest_r, 1.4, -0.55)

	print("--- run plant / stride ---")
	var zs_l: Array[float] = []
	var zs_r: Array[float] = []
	for t in [0.0, 0.18, 0.36, 0.54]:
		await _apply(ap, sk, "run", float(t))
		var yl: float = _y(sk, "Ankle_L")
		var yr: float = _y(sk, "Ankle_R")
		var zl: float = _z(sk, "Ankle_L")
		var zr: float = _z(sk, "Ankle_R")
		zs_l.append(zl)
		zs_r.append(zr)
		print("  t=%.2f AnkleL y/z=%.3f/%.3f AnkleR y/z=%.3f/%.3f" % [t, yl, zl, yr, zr])
		if yr > rest_r + 0.55 or yl > rest_l + 0.55:
			print("  FAIL skyward ankle")
			fail += 1
		if yr < -0.05 or yl < -0.05:
			print("  FAIL ankle underground")
			fail += 1

	if zs_l.size() >= 3:
		var phase_ok: bool = (zs_l[0] - zs_r[0]) * (zs_l[2] - zs_r[2]) < 0.0
		print("opposite_phase_ok=", phase_ok, " dz0=", zs_l[0] - zs_r[0], " dz36=", zs_l[2] - zs_r[2])
		if not phase_ok:
			fail += 1

	## Confirm clips still registered for AnimationTree after rebuild path.
	for clip in ["idle", "run", "jump", "slide", "ghost", "death"]:
		if not ap.has_animation(clip):
			print("FAIL missing clip ", clip)
			fail += 1

	if fail > 0:
		print("VERIFY_FAIL count=", fail)
		quit(1)
	else:
		print("VERIFY_OK")
		quit(0)


func _sample_clip(
	ap: AnimationPlayer,
	sk: Skeleton3D,
	clip: String,
	times: Array,
	rest_l: float,
	rest_r: float,
	max_lift: float,
	min_y: float = -0.35
) -> int:
	var fail: int = 0
	print("--- ", clip, " ---")
	for t in times:
		await _apply(ap, sk, clip, float(t))
		var yl: float = _y(sk, "Ankle_L")
		var yr: float = _y(sk, "Ankle_R")
		print("  t=%.2f Ankle L/R y=%.3f/%.3f z=%.3f/%.3f" % [float(t), yl, yr, _z(sk, "Ankle_L"), _z(sk, "Ankle_R")])
		if yr > rest_r + max_lift:
			print("  FAIL Ankle_R too high (skyward)")
			fail += 1
		if yl > rest_l + max_lift:
			print("  FAIL Ankle_L too high")
			fail += 1
		if yr < min_y or yl < min_y:
			print("  FAIL ankle far underground")
			fail += 1
	return fail


func _apply(ap: AnimationPlayer, sk: Skeleton3D, clip: String, t: float) -> void:
	sk.reset_bone_poses()
	ap.stop()
	ap.play(clip)
	ap.seek(t, true)
	ap.advance(0.0)
	sk.force_update_all_bone_transforms()
	await process_frame


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
