extends SceneTree
## Headless: WitchRunner AnimationTree states + clip library + locomotion API.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
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
	for n in ["idle", "run", "jump", "slide", "death", "ghost"]:
		if ap == null or not ap.has_animation(n):
			push_error("FAIL missing anim %s" % n)
			failed += 1
		else:
			var anim: Animation = ap.get_animation(n)
			print("OK anim ", n, " len=", anim.length, " loop=", anim.loop_mode)
	var tree: AnimationTree = root.get_node_or_null("AnimationTree") as AnimationTree
	if tree == null or not tree.active:
		push_error("FAIL AnimationTree missing/inactive")
		failed += 1
	else:
		print("OK AnimationTree active")
		var sm: AnimationNode = tree.tree_root
		if not (sm is AnimationNodeStateMachine):
			push_error("FAIL tree_root not StateMachine")
			failed += 1
		else:
			var machine: AnimationNodeStateMachine = sm as AnimationNodeStateMachine
			for state_name in ["Idle", "Run", "Jump", "Slide", "Ghost", "Death"]:
				if not machine.has_node(state_name):
					push_error("FAIL state missing %s" % state_name)
					failed += 1
				else:
					print("OK state ", state_name)
	if root.has_method("update_locomotion"):
		root.call("update_locomotion", true, false, true, 18.0, false, true, false, true)
		await process_frame
		root.call("update_locomotion", true, false, false, 18.0, false, true, false, true)
		await process_frame
		root.call("update_locomotion", true, true, true, 18.0, false, true, false, true)
		await process_frame
		root.call("update_locomotion", true, false, true, 14.0, true, true, false, true)
		await process_frame
		root.call("update_locomotion", false, false, true, 0.0, false, false, false, true)
		await process_frame
		var cur: String = str(root.call("get_current_animation"))
		if cur != "death":
			push_error("FAIL expected death got %s" % cur)
			failed += 1
		else:
			print("OK locomotion → death")
	else:
		push_error("FAIL update_locomotion missing")
		failed += 1
	## Player scene still wires Visual.
	var player_packed: PackedScene = load("res://scenes/player/Player.tscn") as PackedScene
	if player_packed:
		var p: Node = player_packed.instantiate()
		get_root().add_child(p)
		await process_frame
		await process_frame
		var vis: Node = p.get_node_or_null("Visual")
		if vis == null or not vis.has_method("update_locomotion"):
			push_error("FAIL Player Visual locomotion API")
			failed += 1
		else:
			print("OK Player Visual=", vis.get_class())
		p.queue_free()
	if failed > 0:
		quit(1)
	print("Witch animations OK")
	quit(0)
