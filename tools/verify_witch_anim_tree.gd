extends SceneTree
## Confirm AnimationTree state machine still blends after clip re-author.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: Node3D = (load("res://scenes/player/WitchRunner.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	var tree: AnimationTree = root.get_node_or_null("AnimationTree") as AnimationTree
	if tree == null or not tree.active:
		print("FAIL no active AnimationTree")
		quit(1)
		return
	var playback: AnimationNodeStateMachinePlayback = tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		print("FAIL no playback")
		quit(1)
		return
	print("start_node=", playback.get_current_node())
	for state in ["Run", "Jump", "Slide", "Ghost", "Idle", "Death"]:
		playback.travel(state)
		await process_frame
		await process_frame
		print("travel ", state, " -> ", playback.get_current_node())
	var sk: Skeleton3D = null
	for n in root.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	## While Death is current, ankles must not be skyward.
	var ar: float = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Ankle_R"))).origin.y
	var al: float = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Ankle_L"))).origin.y
	print("Death ankles L/R y=%.3f/%.3f" % [al, ar])
	if ar > 1.0 or al > 1.0:
		print("FAIL skyward under AnimationTree")
		quit(1)
		return
	## Run via player API
	if root.has_method("update_locomotion"):
		root.call("reset_pose")
		await process_frame
		root.call("update_locomotion", true, false, true, 13.0, false, true, false, false)
		await process_frame
		await process_frame
		print("locomotion run node=", playback.get_current_node())
		ar = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Ankle_R"))).origin.y
		al = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Ankle_L"))).origin.y
		print("Run ankles L/R y=%.3f/%.3f" % [al, ar])
		if ar > 0.9 or al > 0.9:
			print("FAIL skyward on Run via tree")
			quit(1)
			return
	print("ANIM_TREE_OK")
	quit(0)
