extends Area3D
## ObstacleBase — pooled lethal Area3D. Layer 3 (hazards), detects player layer 2.
## Subclasses override can_kill_body() for jump-over pits / low stones.

signal player_hit(player: Node)

const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]

## Set by LevelGenerator when acquiring from the pool.
var pool_id: String = ""
var lane_index: int = 1
## Local Z offset within the parent chunk (chunk origin = center).
var local_z: float = 0.0


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("obstacle")
	collision_layer = 4  ## physics layer 3 — hazards
	collision_mask = 2   ## detect player (layer 2)
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	if not body.is_in_group("player") and not body.has_method("die"):
		return
	if not GameManager.is_playing():
		return
	## Ghost Form: pass through hazards / enemies.
	if body.has_method("is_ghost_form") and body.call("is_ghost_form"):
		return
	if not can_kill_body(body):
		return
	player_hit.emit(body)
	_kill_player(body)


## Override in subclasses (e.g. pit requires low Y / not mid-jump).
func can_kill_body(body: Node3D) -> bool:
	return true


func _kill_player(body: Node3D) -> void:
	if body.has_method("die"):
		body.call("die")
	elif GameManager and GameManager.has_method("trigger_game_over"):
		GameManager.trigger_game_over()


## Place this obstacle on a lane at a local Z relative to the chunk.
func configure(lane: int, z_offset: float) -> void:
	lane_index = clampi(lane, 0, LANE_POSITIONS.size() - 1)
	local_z = z_offset
	position = Vector3(LANE_POSITIONS[lane_index], 0.0, local_z)


## Called after parenting into a chunk.
func on_spawned() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = true
	# Clear stale overlaps from previous life in the pool.
	set_deferred("monitoring", true)


## Reset motion / state before returning to ObjectPool.
func on_recycled() -> void:
	monitoring = false
	visible = false
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	if has_method("_reset_motion"):
		call("_reset_motion")
