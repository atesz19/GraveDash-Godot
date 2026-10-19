extends Node3D
## LevelGenerator — endless chunk spawner + lane-aware obstacle placement.
## Keeps CHUNKS_AHEAD segments ahead of the player; recycles via ObjectPool.

const CHUNK_LENGTH: float = 45.0
const CHUNKS_AHEAD: int = 5
const RECYCLE_MARGIN: float = 10.0
const POOL_CHUNK: String = "chunk_graveyard"
const POOL_PIT: String = "obstacle_pit"
const POOL_GRAVESTONE: String = "obstacle_gravestone"
const POOL_SIDE: String = "obstacle_side"

const LANE_COUNT: int = 3
## Stay clear of chunk seams so obstacles don't sit on the edge.
const Z_MARGIN: float = 6.0

@export var chunk_scene: PackedScene
@export var pit_scene: PackedScene
@export var gravestone_scene: PackedScene
@export var side_scene: PackedScene
@export var player_path: NodePath = ^"../Player"
## How many obstacle slots to roll per chunk (after the safe intro chunks).
@export var obstacles_per_chunk_min: int = 1
@export var obstacles_per_chunk_max: int = 3
## First N chunks (by spawn order) stay empty so the player can accelerate.
@export var safe_chunk_count: int = 1

var _player: Node3D
var _chunks: Array[Node3D] = []
var _next_spawn_z: float = 0.0
var _chunks_spawned: int = 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node3D
	_ensure_scenes()
	_register_pools()

	_next_spawn_z = 0.0
	_chunks_spawned = 0
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH


func _process(_delta: float) -> void:
	if _player == null or not GameManager.is_playing():
		return
	_recycle_behind()
	_ensure_ahead()


func _ensure_scenes() -> void:
	if chunk_scene == null:
		chunk_scene = preload("res://scenes/levels/Chunk_Graveyard_01.tscn")
	if pit_scene == null:
		pit_scene = preload("res://scenes/obstacles/ObstaclePit.tscn")
	if gravestone_scene == null:
		gravestone_scene = preload("res://scenes/obstacles/ObstacleGravestone.tscn")
	if side_scene == null:
		side_scene = preload("res://scenes/obstacles/ObstacleSideIncoming.tscn")


func _register_pools() -> void:
	if not ObjectPool.has_pool(POOL_CHUNK):
		ObjectPool.register_pool(POOL_CHUNK, chunk_scene, CHUNKS_AHEAD + 2)
	if not ObjectPool.has_pool(POOL_PIT):
		ObjectPool.register_pool(POOL_PIT, pit_scene, 8)
	if not ObjectPool.has_pool(POOL_GRAVESTONE):
		ObjectPool.register_pool(POOL_GRAVESTONE, gravestone_scene, 8)
	if not ObjectPool.has_pool(POOL_SIDE):
		ObjectPool.register_pool(POOL_SIDE, side_scene, 6)


func _spawn_chunk_at(origin_z: float) -> Node3D:
	var chunk: Node3D = _acquire_chunk()
	if chunk == null:
		return null

	if chunk.get_parent() != self:
		if chunk.get_parent() != null:
			chunk.get_parent().remove_child(chunk)
		add_child(chunk)

	chunk.global_position = Vector3(0.0, 0.0, origin_z)
	if chunk.has_method("on_spawned"):
		chunk.call("on_spawned")

	var index := _chunks_spawned
	_chunks_spawned += 1
	if index >= safe_chunk_count:
		_populate_obstacles(chunk, index)

	_chunks.append(chunk)
	return chunk


func _populate_obstacles(chunk: Node3D, chunk_index: int) -> void:
	if not chunk.has_method("attach_obstacle"):
		return

	var count := _rng.randi_range(obstacles_per_chunk_min, obstacles_per_chunk_max)
	## Slightly denser as distance grows.
	if chunk_index > 4:
		count = mini(count + 1, 4)

	## band → packed lane flags; never fill all 3 lanes in one Z band.
	var band_lanes: Dictionary = {}
	for i in count:
		var kind := _pick_obstacle_kind(chunk_index)
		var lane := _rng.randi_range(0, LANE_COUNT - 1)
		var z_off := _rng.randf_range(
			-CHUNK_LENGTH * 0.5 + Z_MARGIN,
			CHUNK_LENGTH * 0.5 - Z_MARGIN
		)
		var band := int(floor(z_off / 4.0))
		var occupied: int = int(band_lanes.get(band, 0))
		## Try up to 3 lanes until we find a free escape route.
		var placed := false
		for attempt in LANE_COUNT:
			var try_lane := (lane + attempt) % LANE_COUNT
			var bit := 1 << try_lane
			if occupied & bit:
				continue
			## Refusing a placement that would block every lane.
			if (occupied | bit) == (1 << LANE_COUNT) - 1:
				continue
			occupied |= bit
			band_lanes[band] = occupied
			var obs := _acquire_obstacle(kind)
			if obs == null:
				break
			obs.pool_id = kind
			if obs.has_method("configure"):
				obs.call("configure", try_lane, z_off)
			chunk.call("attach_obstacle", obs)
			placed = true
			break
		if not placed:
			continue


func _pick_obstacle_kind(chunk_index: int) -> String:
	## Intro: mostly stones. Later: mix in pits and side-sweepers.
	var roll := _rng.randf()
	if chunk_index < 3:
		return POOL_GRAVESTONE if roll < 0.7 else POOL_PIT
	if roll < 0.35:
		return POOL_PIT
	if roll < 0.7:
		return POOL_GRAVESTONE
	return POOL_SIDE


func _acquire_obstacle(pool_id: String) -> Node3D:
	var node := ObjectPool.acquire(pool_id)
	if node is Node3D:
		return node as Node3D
	return null


func _acquire_chunk() -> Node3D:
	var node := ObjectPool.acquire(POOL_CHUNK)
	if node is Node3D:
		return node as Node3D
	if chunk_scene:
		return chunk_scene.instantiate() as Node3D
	return null


func _release_chunk(chunk: Node3D) -> void:
	if chunk == null:
		return
	if chunk.has_method("on_recycled"):
		chunk.call("on_recycled")
	ObjectPool.release(POOL_CHUNK, chunk)


func _recycle_behind() -> void:
	while not _chunks.is_empty():
		var rear: Node3D = _chunks[0]
		var near_edge_z: float = rear.global_position.z - CHUNK_LENGTH * 0.5
		if near_edge_z > _player.global_position.z + RECYCLE_MARGIN:
			_chunks.pop_front()
			_release_chunk(rear)
		else:
			break


func _ensure_ahead() -> void:
	while _chunks.size() < CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH

	if _chunks.is_empty():
		return
	var front: Node3D = _chunks[_chunks.size() - 1]
	var front_near_edge: float = front.global_position.z - CHUNK_LENGTH * 0.5
	while front_near_edge > _player.global_position.z - CHUNK_LENGTH * 2.0:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
		front = _chunks[_chunks.size() - 1]
		front_near_edge = front.global_position.z - CHUNK_LENGTH * 0.5
		if _chunks.size() > CHUNKS_AHEAD + 2:
			break


func reset_generator() -> void:
	for chunk in _chunks:
		_release_chunk(chunk)
	_chunks.clear()
	_next_spawn_z = 0.0
	_chunks_spawned = 0
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
