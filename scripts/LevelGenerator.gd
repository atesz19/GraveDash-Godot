extends Node3D
## LevelGenerator — endless chunk spawner for GraveDash.
## Keeps CHUNKS_AHEAD segments in front of the player and recycles those behind.
## Uses ObjectPool when a pool is registered; falls back to instantiate().

const CHUNK_LENGTH: float = 45.0
const CHUNKS_AHEAD: int = 5
## Recycle when the chunk's far end is this far behind the player (+Z side).
const RECYCLE_MARGIN: float = 10.0
const POOL_ID: String = "chunk_graveyard"

@export var chunk_scene: PackedScene
@export var player_path: NodePath = ^"../Player"

var _player: Node3D
## Active chunks ordered from rear → front (increasing -Z depth).
var _chunks: Array[Node3D] = []
## World Z of the next chunk origin (chunk local origin at its +Z / start edge).
var _next_spawn_z: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	if chunk_scene == null:
		chunk_scene = preload("res://scenes/levels/Chunk_Graveyard_01.tscn")

	## Warm the pool once so recycling is cheap.
	if not ObjectPool.has_pool(POOL_ID):
		ObjectPool.register_pool(POOL_ID, chunk_scene, CHUNKS_AHEAD + 2)

	## Seed runway with the first chunk centered on the player spawn (z=0).
	_next_spawn_z = 0.0
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH


func _process(_delta: float) -> void:
	if _player == null or not GameManager.is_playing():
		return
	_recycle_behind()
	_ensure_ahead()


func _spawn_chunk_at(origin_z: float) -> Node3D:
	var chunk: Node3D = _acquire_chunk()
	if chunk == null:
		return null

	## Parent under the generator so the scene tree stays tidy.
	if chunk.get_parent() != self:
		if chunk.get_parent() != null:
			chunk.get_parent().remove_child(chunk)
		add_child(chunk)

	## Chunk origin sits at the center of the segment along Z.
	chunk.global_position = Vector3(0.0, 0.0, origin_z)
	if chunk.has_method("on_spawned"):
		chunk.call("on_spawned")
	_chunks.append(chunk)
	return chunk


func _acquire_chunk() -> Node3D:
	var node := ObjectPool.acquire(POOL_ID)
	if node is Node3D:
		return node as Node3D
	## Fallback if pool failed.
	if chunk_scene:
		return chunk_scene.instantiate() as Node3D
	return null


func _release_chunk(chunk: Node3D) -> void:
	if chunk == null:
		return
	if chunk.has_method("on_recycled"):
		chunk.call("on_recycled")
	ObjectPool.release(POOL_ID, chunk)


func _recycle_behind() -> void:
	## Player runs toward -Z; rear chunks have larger (more positive) Z.
	## Recycle once the chunk's forward (-Z) edge is fully behind the player.
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

	## Also spawn if the frontmost chunk is getting close to the player.
	if _chunks.is_empty():
		return
	var front: Node3D = _chunks[_chunks.size() - 1]
	var front_near_edge: float = front.global_position.z - CHUNK_LENGTH * 0.5
	## Keep runway extending at least ~2 chunk lengths ahead of player.
	while front_near_edge > _player.global_position.z - CHUNK_LENGTH * 2.0:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
		front = _chunks[_chunks.size() - 1]
		front_near_edge = front.global_position.z - CHUNK_LENGTH * 0.5
		if _chunks.size() > CHUNKS_AHEAD + 2:
			break


## Call from GameManager restart / biome swap later.
func reset_generator() -> void:
	for chunk in _chunks:
		_release_chunk(chunk)
	_chunks.clear()
	_next_spawn_z = 0.0
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
