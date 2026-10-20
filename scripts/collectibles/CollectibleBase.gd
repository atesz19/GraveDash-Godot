extends Area3D
## CollectibleBase — pooled pickup Area3D. Layer 4 (pickups), detects player layer 2.
## On body_entered → ScoreManager.add_score → release back to ObjectPool.

signal collected(points: int, collectible_id: String)

const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]
const FLOAT_Y: float = 1.05
const MAGNET_RANGE: float = 14.0
const MAGNET_SPEED: float = 22.0
const SOUL_IDS: Array[String] = ["soul_orb", "big_soul", "golden_coffin"]

## Set by LevelGenerator when acquired from the pool.
var pool_id: String = ""
var collectible_id: String = "soul_orb"
var points: int = 1
var lane_index: int = 1
var local_z: float = 0.0

var _picked: bool = false
var _bob_t: float = 0.0
var _base_y: float = FLOAT_Y
## Yaw spin rate (rad/s). Ability orbs spin a bit faster for readability.
var spin_speed: float = 1.6
var _visual: Node3D = null


func _ready() -> void:
	add_to_group("collectible")
	add_to_group("powerup")
	collision_layer = 8  ## physics layer 4 — pickups
	collision_mask = 2   ## player
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_visual = get_node_or_null("Visual") as Node3D


func _process(delta: float) -> void:
	if _picked or not visible:
		return
	if _try_magnet_pull(delta):
		## Keep spinning while being pulled so the prop stays lively.
		_spin_visual(delta)
		return
	_bob_t += delta
	position.y = _base_y + sin(_bob_t * 3.0) * 0.14
	_spin_visual(delta)


func _spin_visual(delta: float) -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.rotate_y(delta * spin_speed)
	else:
		rotate_y(delta * spin_speed)


func _try_magnet_pull(delta: float) -> bool:
	if not SOUL_IDS.has(collectible_id):
		return false
	var player := GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		return false
	if not bool(player.get("has_magnet")):
		return false
	if not bool(player.get("is_alive")):
		return false
	var target := player.global_position + Vector3(0.0, 1.0, 0.0)
	var dist := global_position.distance_to(target)
	if dist > MAGNET_RANGE:
		return false
	var step := (MAGNET_SPEED + (MAGNET_RANGE - dist) * 1.5) * delta
	global_position = global_position.move_toward(target, step)
	return true


func _on_body_entered(body: Node3D) -> void:
	if _picked:
		return
	if not (body is CharacterBody3D):
		return
	if not body.is_in_group("player") and not body.has_method("die"):
		return
	if not GameManager.is_playing():
		return
	_pickup(body)


func _pickup(_body: Node3D) -> void:
	_picked = true
	monitoring = false
	ScoreManager.add_score(points)
	if SOUL_IDS.has(collectible_id) and points > 0:
		ScoreManager.add_souls(points)
		if AudioManager:
			AudioManager.play_soul_pickup()
	collected.emit(points, collectible_id)
	## Tell parent chunk to drop its reference, then return to the pool.
	var parent_chunk := _find_chunk()
	if parent_chunk and parent_chunk.has_method("notify_collectible_picked"):
		parent_chunk.call("notify_collectible_picked", self)
	elif pool_id != "" and ObjectPool.has_pool(pool_id):
		on_recycled()
		ObjectPool.release(pool_id, self)


func _find_chunk() -> Node:
	var n: Node = get_parent()
	while n:
		if n.is_in_group("chunk"):
			return n
		n = n.get_parent()
	return null


func configure(lane: int, z_offset: float) -> void:
	lane_index = clampi(lane, 0, LANE_POSITIONS.size() - 1)
	local_z = z_offset
	_base_y = FLOAT_Y
	position = Vector3(LANE_POSITIONS[lane_index], _base_y, local_z)
	_picked = false
	_bob_t = randf() * TAU


func on_spawned() -> void:
	_picked = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	monitoring = true
	set_deferred("monitoring", true)


func on_recycled() -> void:
	_picked = false
	monitoring = false
	visible = false
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	_bob_t = 0.0
	if _visual != null and is_instance_valid(_visual):
		_visual.rotation = Vector3.ZERO
