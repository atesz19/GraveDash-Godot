extends Node
## ObjectPool — generic scene instance pooling for chunks, obstacles, VFX.
## Usage:
##   ObjectPool.register_pool("chunk_graveyard", preload("res://scenes/levels/Chunk_Graveyard_01.tscn"), 6)
##   var chunk := ObjectPool.acquire("chunk_graveyard")
##   ObjectPool.release("chunk_graveyard", chunk)

## pool_id → { scene: PackedScene, free: Array[Node], active: Array[Node] }
var _pools: Dictionary = {}


## Register (or expand) a named pool. Pre-instantiates `initial_size` nodes under this autoload.
func register_pool(pool_id: String, scene: PackedScene, initial_size: int = 4) -> void:
	if scene == null:
		push_error("ObjectPool.register_pool: scene is null for '%s'" % pool_id)
		return

	if not _pools.has(pool_id):
		_pools[pool_id] = {
			"scene": scene,
			"free": [],
			"active": [],
		}

	var entry: Dictionary = _pools[pool_id]
	entry["scene"] = scene
	for i in initial_size:
		var node := _instantiate(pool_id)
		_deactivate(node)
		entry["free"].append(node)


## Take an instance from the pool (creates one if empty). Returns null on unknown pool.
func acquire(pool_id: String) -> Node:
	if not _pools.has(pool_id):
		push_warning("ObjectPool.acquire: unknown pool '%s'" % pool_id)
		return null

	var entry: Dictionary = _pools[pool_id]
	var node: Node
	if entry["free"].is_empty():
		node = _instantiate(pool_id)
	else:
		node = entry["free"].pop_back()

	entry["active"].append(node)
	_activate(node)
	return node


## Return an instance to the free list. Safe to call with null / already-freed nodes.
func release(pool_id: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not _pools.has(pool_id):
		push_warning("ObjectPool.release: unknown pool '%s'" % pool_id)
		node.queue_free()
		return

	var entry: Dictionary = _pools[pool_id]
	var active: Array = entry["active"]
	var idx := active.find(node)
	if idx >= 0:
		active.remove_at(idx)

	## Detach from world parent so it lives under the pool again.
	if node.get_parent() != null and node.get_parent() != self:
		node.get_parent().remove_child(node)
	if node.get_parent() != self:
		add_child(node)

	_deactivate(node)
	if not entry["free"].has(node):
		entry["free"].append(node)


## Release every active instance in a pool (e.g. on game over / restart).
func release_all(pool_id: String) -> void:
	if not _pools.has(pool_id):
		return
	var entry: Dictionary = _pools[pool_id]
	## Copy to avoid mutating while iterating.
	var active_copy: Array = entry["active"].duplicate()
	for node in active_copy:
		release(pool_id, node)


func get_active_count(pool_id: String) -> int:
	if not _pools.has(pool_id):
		return 0
	return _pools[pool_id]["active"].size()


func get_free_count(pool_id: String) -> int:
	if not _pools.has(pool_id):
		return 0
	return _pools[pool_id]["free"].size()


func has_pool(pool_id: String) -> bool:
	return _pools.has(pool_id)


func clear_pool(pool_id: String) -> void:
	if not _pools.has(pool_id):
		return
	var entry: Dictionary = _pools[pool_id]
	for node in entry["active"] + entry["free"]:
		if is_instance_valid(node):
			node.queue_free()
	_pools.erase(pool_id)


func _instantiate(pool_id: String) -> Node:
	var scene: PackedScene = _pools[pool_id]["scene"]
	var node := scene.instantiate()
	add_child(node)
	return node


func _activate(node: Node) -> void:
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is Area3D:
		(node as Area3D).monitoring = true
		(node as Area3D).monitorable = true


func _deactivate(node: Node) -> void:
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Area3D:
		(node as Area3D).monitoring = false
		(node as Area3D).monitorable = false
	## Keep pooled nodes under this autoload while idle.
	if node.get_parent() != self:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		add_child(node)
