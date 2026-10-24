extends Node3D
## Chunk — recyclable segment. Holds pooled obstacles + collectibles.

const CHUNK_LENGTH: float = 45.0
const CHUNK_WIDTH: float = 9.0
const GROUND_THICKNESS: float = 1.0
## Shoulder densify — keep clear of the 3 play lanes (|x| >= EDGE_MIN_X).
const EDGE_MIN_X: float = 5.2
const EDGE_PROP_SCENES: Array[String] = [
	"res://scenes/levels/props/DecorGravestone_01.tscn",
	"res://scenes/levels/props/DecorGravestone_02.tscn",
	"res://scenes/levels/props/DecorGravestone_03.tscn",
	"res://scenes/levels/props/DecorGravestone_04.tscn",
	"res://scenes/levels/props/DecorFallenCross.tscn",
	"res://scenes/levels/props/DecorFence.tscn",
	"res://scenes/levels/props/DecorCoffin.tscn",
	"res://scenes/levels/props/DecorRock.tscn",
	"res://scenes/levels/props/DecorBush.tscn",
	"res://scenes/levels/props/DecorDeadTree.tscn",
	"res://scenes/levels/props/Torch.tscn",
]

@onready var ground: MeshInstance3D = $Ground
@onready var ground_body: StaticBody3D = $Ground/StaticBody3D
@onready var obstacles_root: Node3D = $Obstacles
@onready var collectibles_root: Node3D = $Collectibles

## Set by LevelGenerator when acquired (so release uses the correct pool after biome switch).
var pool_id: String = ""

var _obstacles: Array[Node] = []
var _collectibles: Array[Node] = []
var _edge_scatter_done: bool = false


func _ready() -> void:
	add_to_group("chunk")
	if obstacles_root == null:
		obstacles_root = Node3D.new()
		obstacles_root.name = "Obstacles"
		add_child(obstacles_root)
	if collectibles_root == null:
		collectibles_root = Node3D.new()
		collectibles_root.name = "Collectibles"
		add_child(collectibles_root)


func on_spawned() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_ensure_edge_scatter()


func attach_obstacle(obstacle: Node3D) -> void:
	_attach_to(obstacle, obstacles_root, _obstacles)


func attach_collectible(collectible: Node3D) -> void:
	_attach_to(collectible, collectibles_root, _collectibles)


func _attach_to(node: Node3D, root: Node3D, list: Array[Node]) -> void:
	if node == null:
		return
	if node.get_parent() != root:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		root.add_child(node)
	if not list.has(node):
		list.append(node)
	if node.has_method("on_spawned"):
		node.call("on_spawned")


## Collectible picked itself up — drop our ref (it already scored / will release).
func notify_collectible_picked(collectible: Node) -> void:
	_collectibles.erase(collectible)
	_release_item(collectible)


## Holy Light / external clear — recycle an obstacle back into its pool.
func notify_obstacle_destroyed(obstacle: Node) -> void:
	_obstacles.erase(obstacle)
	_release_item(obstacle)


func _release_item(item: Node) -> void:
	if item == null or not is_instance_valid(item):
		return
	var pool_id := str(item.get("pool_id")) if item.get("pool_id") != null else ""
	if item.has_method("on_recycled"):
		item.call("on_recycled")
	if pool_id != "" and ObjectPool.has_pool(pool_id):
		ObjectPool.release(pool_id, item)
	elif is_instance_valid(item):
		item.queue_free()


func on_recycled() -> void:
	release_obstacles()
	release_collectibles()


func release_obstacles() -> void:
	_release_list(_obstacles)


func release_collectibles() -> void:
	_release_list(_collectibles)


func _release_list(list: Array[Node]) -> void:
	var copy := list.duplicate()
	list.clear()
	for item in copy:
		if item == null or not is_instance_valid(item):
			continue
		var pool_id := str(item.get("pool_id")) if item.get("pool_id") != null else ""
		if item.has_method("on_recycled"):
			item.call("on_recycled")
		if pool_id != "" and ObjectPool.has_pool(pool_id):
			ObjectPool.release(pool_id, item)
		else:
			item.queue_free()


func _ensure_edge_scatter() -> void:
	## Once per chunk instance — densify shoulders so gameplay matches menu density.
	if _edge_scatter_done:
		return
	if get_node_or_null("EdgeScatter") != null:
		_edge_scatter_done = true
		return
	var packed_props: Array[PackedScene] = []
	for path in EDGE_PROP_SCENES:
		var ps: PackedScene = load(path) as PackedScene
		if ps:
			packed_props.append(ps)
	if packed_props.is_empty():
		return
	var root := Node3D.new()
	root.name = "EdgeScatter"
	add_child(root)
	## Seed from chunk Z so recycled placements stay stable per world slot.
	var seed_z: int = int(round(global_position.z / CHUNK_LENGTH))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_z * 7919 + 104729)
	## ~7 shoulder props in Z gaps between baked Props (|x| >= 5.2).
	var slots: Array[Dictionary] = [
		{"side": -1.0, "x": 5.45, "z": 21.5, "kind": 5},
		{"side": 1.0, "x": 5.55, "z": 13.5, "kind": 0},
		{"side": -1.0, "x": 5.7, "z": 5.5, "kind": 7},
		{"side": 1.0, "x": 5.4, "z": -3.5, "kind": 8},
		{"side": -1.0, "x": 6.1, "z": -9.5, "kind": 4},
		{"side": 1.0, "x": 5.65, "z": -15.5, "kind": 2},
		{"side": -1.0, "x": 5.35, "z": -21.0, "kind": 10},
	]
	## Prefer graves / fence / rock / bush / torch over large trees for fill.
	var kind_cycle: Array[int] = [0, 1, 2, 3, 5, 7, 8, 4, 6, 10]
	for i in slots.size():
		var slot: Dictionary = slots[i]
		## Skip ~1 slot per chunk for variety (still 6–7 props typical).
		if i == (absi(seed_z) % slots.size()) and slots.size() > 6:
			continue
		var kind: int = kind_cycle[(absi(seed_z) + i * 3) % kind_cycle.size()]
		kind = clampi(kind, 0, packed_props.size() - 1)
		var node: Node3D = packed_props[kind].instantiate() as Node3D
		if node == null:
			continue
		root.add_child(node)
		var side: float = float(slot["side"])
		var x: float = maxf(EDGE_MIN_X, float(slot["x"]) + rng.randf_range(-0.15, 0.2))
		var z: float = float(slot["z"]) + rng.randf_range(-0.4, 0.4)
		node.position = Vector3(side * x, 0.0, z)
		var yaw: float = side * (90.0 if kind == 5 else float((absi(seed_z) * 17 + i * 29) % 50) - 25.0)
		node.rotation_degrees.y = yaw
		if kind == 10:
			node.scale = Vector3.ONE * 1.05
	_edge_scatter_done = true
