extends SceneTree
## Headless: menu/chunk edge decor stays off the 3 playable lanes.


const LANE_CLEAR_X: float = 4.4
const PROP_PATHS: Array[String] = [
	"res://scenes/levels/props/DecorFallenCross.tscn",
	"res://scenes/levels/props/DecorFence.tscn",
	"res://scenes/levels/props/DecorCoffin.tscn",
	"res://scenes/levels/props/DecorRock.tscn",
	"res://scenes/levels/props/DecorBush.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	for path in PROP_PATHS:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("FAIL load %s" % path)
			failed += 1
			continue
		var n: Node = packed.instantiate()
		get_root().add_child(n)
		await process_frame
		print("OK prop ", path)
		n.queue_free()
		await process_frame

	var chunk_ps: PackedScene = load("res://scenes/levels/Chunk_Graveyard_01.tscn") as PackedScene
	if chunk_ps == null:
		push_error("FAIL chunk")
		quit(1)
		return
	var chunk: Node3D = chunk_ps.instantiate() as Node3D
	get_root().add_child(chunk)
	await process_frame
	var props: Node3D = chunk.get_node_or_null("Props") as Node3D
	if props == null or props.get_child_count() < 20:
		push_error("FAIL sparse Props count=%d" % (props.get_child_count() if props else -1))
		failed += 1
	else:
		print("OK chunk props=", props.get_child_count())
	for child in props.get_children():
		if child is Node3D:
			var x: float = absf((child as Node3D).position.x)
			if x < LANE_CLEAR_X:
				push_error("FAIL chunk prop in lane x=%.2f name=%s" % [ (child as Node3D).position.x, child.name ])
				failed += 1
	print("OK chunk props outside lanes")

	var menu_ps: PackedScene = load("res://scenes/ui/MenuWorld.tscn") as PackedScene
	var menu: Node3D = menu_ps.instantiate() as Node3D
	get_root().add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	var edge: Node3D = menu.get_node_or_null("EdgeDecor") as Node3D
	if edge == null or edge.get_child_count() < 10:
		push_error("FAIL EdgeDecor count=%d" % (edge.get_child_count() if edge else -1))
		failed += 1
	else:
		print("OK EdgeDecor count=", edge.get_child_count())
	for child in edge.get_children():
		if child is Node3D:
			var x2: float = absf((child as Node3D).position.x)
			if x2 < LANE_CLEAR_X:
				push_error("FAIL menu edge in lane x=%.2f" % (child as Node3D).position.x)
				failed += 1
	var track: Node = menu.get_node_or_null("Track")
	print("OK track_chunks=", track.get_child_count() if track else 0)
	var backdrop: Node = menu.get_node_or_null("Backdrop")
	if backdrop == null:
		push_error("FAIL backdrop")
		failed += 1
	else:
		var left: Node = backdrop.get_node_or_null("LeftBank")
		var kids: int = left.get_child_count() if left else 0
		if kids < 40:
			push_error("FAIL backdrop LeftBank sparse=%d" % kids)
			failed += 1
		else:
			print("OK backdrop LeftBank=", kids)

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_menu_edges")
	quit(0)
