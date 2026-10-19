extends Node3D
## Chunk — one recyclable level segment. Holds pooled obstacles under Obstacles/.

const CHUNK_LENGTH: float = 45.0
const CHUNK_WIDTH: float = 9.0
const GROUND_THICKNESS: float = 1.0

@onready var ground: MeshInstance3D = $Ground
@onready var ground_body: StaticBody3D = $Ground/StaticBody3D
@onready var obstacles_root: Node3D = $Obstacles

## Active obstacle instances parented to this chunk (released on recycle).
var _obstacles: Array[Node] = []


func _ready() -> void:
	add_to_group("chunk")
	if obstacles_root == null:
		obstacles_root = Node3D.new()
		obstacles_root.name = "Obstacles"
		add_child(obstacles_root)


## Called by LevelGenerator after positioning a pooled instance.
func on_spawned() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


## Attach a pooled obstacle as a child of this chunk.
func attach_obstacle(obstacle: Node3D) -> void:
	if obstacle == null:
		return
	if obstacle.get_parent() != obstacles_root:
		if obstacle.get_parent() != null:
			obstacle.get_parent().remove_child(obstacle)
		obstacles_root.add_child(obstacle)
	if not _obstacles.has(obstacle):
		_obstacles.append(obstacle)
	if obstacle.has_method("on_spawned"):
		obstacle.call("on_spawned")


## Called before returning to ObjectPool — release all child obstacles.
func on_recycled() -> void:
	release_obstacles()


func release_obstacles() -> void:
	var copy := _obstacles.duplicate()
	_obstacles.clear()
	for obs in copy:
		if obs == null or not is_instance_valid(obs):
			continue
		var pool_id := str(obs.get("pool_id")) if obs.get("pool_id") != null else ""
		if obs.has_method("on_recycled"):
			obs.call("on_recycled")
		if pool_id != "" and ObjectPool.has_pool(pool_id):
			ObjectPool.release(pool_id, obs)
		else:
			obs.queue_free()
