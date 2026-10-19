extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/player/WitchRunner.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load WitchRunner")
		quit(1)
		return
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	var ap: AnimationPlayer = root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		push_error("FAIL no AnimationPlayer")
		quit(1)
		return
	var needed: Array[String] = ["idle", "run", "jump", "slide", "death"]
	var failed: int = 0
	for n in needed:
		if not ap.has_animation(n):
			push_error("FAIL missing anim %s" % n)
			failed += 1
		else:
			var a: Animation = ap.get_animation(n)
			print("OK %s len=%.2f tracks=%d" % [n, a.length, a.get_track_count()])
			if a.get_track_count() < 3:
				push_error("FAIL sparse tracks on %s" % n)
				failed += 1
	var skel: Skeleton3D = _find_skel(root)
	if skel == null:
		push_error("FAIL no skeleton")
		failed += 1
	else:
		print("skeleton bones=%d" % skel.get_bone_count())
		## Play run briefly and ensure hip pose changes.
		root.call("play", "run", true)
		await process_frame
		ap.seek(0.3, true)
		await process_frame
		var hip: int = skel.find_bone("Hip_L")
		if hip >= 0:
			var pose: Quaternion = skel.get_bone_pose_rotation(hip)
			print("Hip_L pose after seek=", pose)
			if pose.is_equal_approx(Quaternion.IDENTITY):
				push_warning("Hip_L still identity — tracks may not bind")
	## Player scene Visual swap
	var player_packed: PackedScene = load("res://scenes/player/Player.tscn") as PackedScene
	var player: Node = player_packed.instantiate()
	var vis: Node = player.get_node_or_null("Visual")
	if vis == null:
		push_error("FAIL Player Visual missing")
		failed += 1
	else:
		print("Player Visual class=", vis.get_class(), " script=", vis.get_script())
		if not vis.has_method("play"):
			push_error("FAIL Visual has no play()")
			failed += 1
	player.free()
	if failed > 0:
		quit(1)
	else:
		print("WitchRunner OK")
		quit(0)


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f: Skeleton3D = _find_skel(c)
		if f:
			return f
	return null
