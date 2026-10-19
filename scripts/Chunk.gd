extends Node3D
## Chunk — recyclable segment. Holds pooled obstacles + collectibles.

const CHUNK_LENGTH: float = 45.0
const CHUNK_WIDTH: float = 9.0
const GROUND_THICKNESS: float = 1.0

@onready var ground: MeshInstance3D = $Ground
@onready var ground_body: StaticBody3D = $Ground/StaticBody3D
@onready var obstacles_root: Node3D = $Obstacles
@onready var collectibles_root: Node3D = $Collectibles

var _obstacles: Array[Node] = []
var _collectibles: Array[Node] = []


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
