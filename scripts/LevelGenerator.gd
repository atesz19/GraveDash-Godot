extends Node3D
## LevelGenerator — chunk spawner + lane-aware obstacles & soul collectibles.

const CHUNK_LENGTH: float = 45.0
const CHUNKS_AHEAD: int = 5
const RECYCLE_MARGIN: float = 10.0

const POOL_CHUNK: String = "chunk_graveyard"
const POOL_PIT: String = "obstacle_pit"
const POOL_GRAVESTONE: String = "obstacle_gravestone"
const POOL_SIDE: String = "obstacle_side"
const POOL_SOUL: String = "collectible_soul"
const POOL_BIG_SOUL: String = "collectible_big_soul"
const POOL_COFFIN: String = "collectible_golden_coffin"
const POOL_GHOST: String = "collectible_ghost_form"
const POOL_MAGNET: String = "collectible_soul_magnet"
const POOL_HOLY: String = "collectible_holy_light"
const POOL_SECOND: String = "collectible_second_chance"
const POOL_CURSED: String = "collectible_cursed_speed"

const LANE_COUNT: int = 3
const Z_MARGIN: float = 6.0
## Z-band width used to keep obstacles/souls from stacking.
const BAND_SIZE: float = 4.0

@export var chunk_scene: PackedScene
@export var pit_scene: PackedScene
@export var gravestone_scene: PackedScene
@export var side_scene: PackedScene
@export var soul_scene: PackedScene
@export var big_soul_scene: PackedScene
@export var coffin_scene: PackedScene
@export var ghost_form_scene: PackedScene
@export var soul_magnet_scene: PackedScene
@export var holy_light_scene: PackedScene
@export var second_chance_scene: PackedScene
@export var cursed_speed_scene: PackedScene
@export var player_path: NodePath = ^"../Player"

@export var obstacles_per_chunk_min: int = 1
@export var obstacles_per_chunk_max: int = 3
@export var souls_per_chunk_min: int = 3
@export var souls_per_chunk_max: int = 5
@export var safe_chunk_count: int = 1
## Overall chance to place one ability power-up per chunk (after intro).
@export var ability_powerup_chance: float = 0.22
## Legacy: kept for compatibility; abilities use weighted pick below.
@export var ghost_form_chance: float = 0.12

var _player: Node3D
var _chunks: Array[Node3D] = []
var _next_spawn_z: float = 0.0
var _chunks_spawned: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node3D
	## Pull chunk scene from the active biome (Graveyard at run start).
	_sync_chunk_from_biome()
	_ensure_scenes()
	_register_pools()

	_next_spawn_z = 0.0
	_chunks_spawned = 0
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH

	if not BiomeManager.biome_changed.is_connected(_on_biome_changed):
		BiomeManager.biome_changed.connect(_on_biome_changed)


func _sync_chunk_from_biome() -> void:
	var biome_chunk := BiomeManager.get_chunk_scene()
	if biome_chunk:
		chunk_scene = biome_chunk


func _on_biome_changed(_biome_id: String) -> void:
	## Future biomes can swap chunk scenes; keep current runway intact for now.
	_sync_chunk_from_biome()


func _process(_delta: float) -> void:
	if _player == null or not GameManager.is_playing():
		return
	_recycle_behind()
	_ensure_ahead()


func _ensure_scenes() -> void:
	if chunk_scene == null:
		chunk_scene = BiomeManager.get_chunk_scene()
	if chunk_scene == null:
		chunk_scene = preload("res://scenes/levels/Chunk_Graveyard_01.tscn")
	if pit_scene == null:
		pit_scene = preload("res://scenes/obstacles/ObstaclePit.tscn")
	if gravestone_scene == null:
		gravestone_scene = preload("res://scenes/obstacles/ObstacleGravestone.tscn")
	if side_scene == null:
		side_scene = preload("res://scenes/obstacles/ObstacleSideIncoming.tscn")
	if soul_scene == null:
		soul_scene = preload("res://scenes/powerups/SoulOrb.tscn")
	if big_soul_scene == null:
		big_soul_scene = preload("res://scenes/powerups/BigSoul.tscn")
	if coffin_scene == null:
		coffin_scene = preload("res://scenes/powerups/GoldenCoffin.tscn")
	if ghost_form_scene == null:
		ghost_form_scene = preload("res://scenes/powerups/GhostForm.tscn")
	if soul_magnet_scene == null:
		soul_magnet_scene = preload("res://scenes/powerups/SoulMagnet.tscn")
	if holy_light_scene == null:
		holy_light_scene = preload("res://scenes/powerups/HolyLight.tscn")
	if second_chance_scene == null:
		second_chance_scene = preload("res://scenes/powerups/SecondChance.tscn")
	if cursed_speed_scene == null:
		cursed_speed_scene = preload("res://scenes/powerups/CursedSpeed.tscn")


func _register_pools() -> void:
	var chunk_pool := BiomeManager.get_chunk_pool_id()
	## Keep legacy constant in sync with the active biome pool id.
	if not ObjectPool.has_pool(chunk_pool):
		ObjectPool.register_pool(chunk_pool, chunk_scene, CHUNKS_AHEAD + 2)
	if chunk_pool != POOL_CHUNK and not ObjectPool.has_pool(POOL_CHUNK):
		ObjectPool.register_pool(POOL_CHUNK, chunk_scene, CHUNKS_AHEAD + 2)
	if not ObjectPool.has_pool(POOL_PIT):
		ObjectPool.register_pool(POOL_PIT, pit_scene, 8)
	if not ObjectPool.has_pool(POOL_GRAVESTONE):
		ObjectPool.register_pool(POOL_GRAVESTONE, gravestone_scene, 8)
	if not ObjectPool.has_pool(POOL_SIDE):
		ObjectPool.register_pool(POOL_SIDE, side_scene, 6)
	if not ObjectPool.has_pool(POOL_SOUL):
		ObjectPool.register_pool(POOL_SOUL, soul_scene, 24)
	if not ObjectPool.has_pool(POOL_BIG_SOUL):
		ObjectPool.register_pool(POOL_BIG_SOUL, big_soul_scene, 10)
	if not ObjectPool.has_pool(POOL_COFFIN):
		ObjectPool.register_pool(POOL_COFFIN, coffin_scene, 4)
	if not ObjectPool.has_pool(POOL_GHOST):
		ObjectPool.register_pool(POOL_GHOST, ghost_form_scene, 4)
	if not ObjectPool.has_pool(POOL_MAGNET):
		ObjectPool.register_pool(POOL_MAGNET, soul_magnet_scene, 4)
	if not ObjectPool.has_pool(POOL_HOLY):
		ObjectPool.register_pool(POOL_HOLY, holy_light_scene, 4)
	if not ObjectPool.has_pool(POOL_SECOND):
		ObjectPool.register_pool(POOL_SECOND, second_chance_scene, 3)
	if not ObjectPool.has_pool(POOL_CURSED):
		ObjectPool.register_pool(POOL_CURSED, cursed_speed_scene, 4)


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

	## band → bitmask of occupied lanes (obstacles). Souls avoid these cells.
	var occupied: Dictionary = {}
	if index >= safe_chunk_count:
		occupied = _populate_obstacles(chunk, index)
	var soul_cells := _populate_collectibles(chunk, index, occupied)
	_maybe_spawn_ability_powerup(chunk, index, occupied, soul_cells)

	_chunks.append(chunk)
	return chunk


func _populate_obstacles(chunk: Node3D, chunk_index: int) -> Dictionary:
	var occupied: Dictionary = {}
	if not chunk.has_method("attach_obstacle"):
		return occupied

	var count := _rng.randi_range(obstacles_per_chunk_min, obstacles_per_chunk_max)
	if chunk_index > 4:
		count = mini(count + 1, 4)

	for i in count:
		var kind := _pick_obstacle_kind(chunk_index)
		var lane := _rng.randi_range(0, LANE_COUNT - 1)
		var z_off := _random_z()
		var band := _band(z_off)
		var mask: int = int(occupied.get(band, 0))
		for attempt in LANE_COUNT:
			var try_lane := (lane + attempt) % LANE_COUNT
			var bit := 1 << try_lane
			if mask & bit:
				continue
			if (mask | bit) == (1 << LANE_COUNT) - 1:
				continue
			mask |= bit
			occupied[band] = mask
			var obs := _acquire_pooled(kind)
			if obs == null:
				break
			obs.pool_id = kind
			if obs.has_method("configure"):
				obs.call("configure", try_lane, z_off)
			chunk.call("attach_obstacle", obs)
			break
	return occupied


func _populate_collectibles(chunk: Node3D, chunk_index: int, occupied: Dictionary) -> Dictionary:
	var soul_cells: Dictionary = {}
	if not chunk.has_method("attach_collectible"):
		return soul_cells

	## Density: 3–5 souls/chunk (2–3 on the safe intro chunk).
	var count := _rng.randi_range(souls_per_chunk_min, souls_per_chunk_max)
	if chunk_index < safe_chunk_count:
		count = _rng.randi_range(2, 3)

	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 6:
		attempts += 1
		var lane := _rng.randi_range(0, LANE_COUNT - 1)
		var z_off := _random_z()
		var band := _band(z_off)
		var cell := "%d|%d" % [lane, band]
		if soul_cells.has(cell):
			continue
		if not _cell_is_clear(lane, band, occupied, soul_cells):
			continue

		var kind := _pick_collectible_kind(chunk_index)
		var col := _acquire_pooled(kind)
		if col == null:
			break
		col.pool_id = kind
		if col.has_method("configure"):
			col.call("configure", lane, z_off)
		chunk.call("attach_collectible", col)
		soul_cells[cell] = true
		placed += 1
	return soul_cells


## At most one ability power-up per chunk after intro (~22% chance).
## Weights: Ghost 28%, Magnet 24%, Holy 20%, Cursed 16%, Second Chance 12%.
func _maybe_spawn_ability_powerup(
	chunk: Node3D,
	chunk_index: int,
	occupied: Dictionary,
	soul_cells: Dictionary
) -> void:
	if chunk_index < safe_chunk_count + 1:
		return
	if not chunk.has_method("attach_collectible"):
		return
	if _rng.randf() > ability_powerup_chance:
		return

	var pool_id := _pick_ability_pool()
	for attempt in 8:
		var lane := _rng.randi_range(0, LANE_COUNT - 1)
		var z_off := _random_z()
		var band := _band(z_off)
		var cell := "%d|%d" % [lane, band]
		if not _cell_is_clear(lane, band, occupied, soul_cells):
			continue
		var col := _acquire_pooled(pool_id)
		if col == null:
			return
		col.pool_id = pool_id
		if col.has_method("configure"):
			col.call("configure", lane, z_off)
		chunk.call("attach_collectible", col)
		soul_cells[cell] = true
		return


func _pick_ability_pool() -> String:
	var roll := _rng.randf()
	if roll < 0.28:
		return POOL_GHOST
	if roll < 0.52:
		return POOL_MAGNET
	if roll < 0.72:
		return POOL_HOLY
	if roll < 0.88:
		return POOL_CURSED
	return POOL_SECOND


func _cell_is_clear(lane: int, band: int, occupied: Dictionary, soul_cells: Dictionary) -> bool:
	var cell := "%d|%d" % [lane, band]
	if soul_cells.has(cell):
		return false
	for db in [-1, 0, 1]:
		var m: int = int(occupied.get(band + db, 0))
		if m & (1 << lane):
			return false
	return true


func _pick_obstacle_kind(chunk_index: int) -> String:
	var roll := _rng.randf()
	if chunk_index < 3:
		return POOL_GRAVESTONE if roll < 0.7 else POOL_PIT
	if roll < 0.35:
		return POOL_PIT
	if roll < 0.7:
		return POOL_GRAVESTONE
	return POOL_SIDE


func _pick_collectible_kind(chunk_index: int) -> String:
	## ~82% orb, ~15% big soul, ~3% golden coffin (rarer early).
	var roll := _rng.randf()
	var coffin_chance := 0.015 if chunk_index < 4 else 0.035
	var big_chance := 0.12 if chunk_index < 3 else 0.15
	if roll < coffin_chance:
		return POOL_COFFIN
	if roll < coffin_chance + big_chance:
		return POOL_BIG_SOUL
	return POOL_SOUL


func _random_z() -> float:
	return _rng.randf_range(-CHUNK_LENGTH * 0.5 + Z_MARGIN, CHUNK_LENGTH * 0.5 - Z_MARGIN)


func _band(z_off: float) -> int:
	return int(floor(z_off / BAND_SIZE))


func _acquire_pooled(pool_id: String) -> Node3D:
	var node := ObjectPool.acquire(pool_id)
	if node is Node3D:
		return node as Node3D
	return null


func _chunk_pool_id() -> String:
	return BiomeManager.get_chunk_pool_id()


func _acquire_chunk() -> Node3D:
	var pool_id := _chunk_pool_id()
	var node := ObjectPool.acquire(pool_id)
	if node == null and pool_id != POOL_CHUNK:
		node = ObjectPool.acquire(POOL_CHUNK)
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
	var pool_id := _chunk_pool_id()
	if ObjectPool.has_pool(pool_id):
		ObjectPool.release(pool_id, chunk)
	else:
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
