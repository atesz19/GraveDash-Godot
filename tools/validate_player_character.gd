extends SceneTree
## Headless: load HoodedRunner + verify animation library.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/player/HoodedRunner.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load HoodedRunner")
		quit(1)
		return
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	## Allow @onready + _ready animation build.
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
			push_error("FAIL missing anim: %s" % n)
			failed += 1
		else:
			print("OK anim %s len=%.2f" % [n, ap.get_animation(n).length])
	var meshes: int = _count_meshes(root)
	print("mesh_instances=%d" % meshes)
	if meshes < 8:
		push_error("FAIL too few meshes")
		failed += 1
	if root.has_method("play"):
		root.call("play", "run", true)
		print("current=%s" % str(root.call("get_current_animation")))
	## Player scene still loads Visual instance.
	var player_packed: PackedScene = load("res://scenes/player/Player.tscn") as PackedScene
	if player_packed == null:
		push_error("FAIL load Player")
		failed += 1
	else:
		var player: Node = player_packed.instantiate()
		var vis: Node = player.get_node_or_null("Visual")
		var col: Node = player.get_node_or_null("CollisionShape3D")
		if vis == null:
			push_error("FAIL Player missing Visual")
			failed += 1
		else:
			print("Player Visual OK")
		if col == null:
			push_error("FAIL Player missing CollisionShape3D")
			failed += 1
		else:
			print("Player CollisionShape OK")
		## Don't add player (needs autoloads); free it.
		player.free()
	if failed > 0:
		quit(1)
	else:
		print("Player character OK")
		quit(0)


func _count_meshes(n: Node) -> int:
	var c: int = 0
	if n is MeshInstance3D:
		c += 1
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c
