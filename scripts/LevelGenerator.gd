extends Node3D
## LevelGenerator — fair Subway Surfers–style chunk patterns.
## Obstacles & souls only on lanes X = [-2.5, 0, 2.5]. Patterns guarantee ≥1 free lane.

const ChunkPatternsScript = preload("res://scripts/levels/ChunkPatterns.gd")

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
## Clearance: souls must stay this far in Z from same-lane obstacles.
const SOUL_CLEARANCE_Z: float = 5.0
## Obstacle beats in the same pattern must stay this far apart when sharing conflicting lanes.
const MIN_BEAT_GAP: float = 8.0

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

@export var safe_chunk_count: int = 1
## Overall chance to place one ability power-up per chunk (after intro).
@export var ability_powerup_chance: float = 0.18
## Legacy export kept for scene compatibility.
@export var ghost_form_chance: float = 0.12
@export var obstacles_per_chunk_min: int = 1
@export var obstacles_per_chunk_max: int = 3
@export var souls_per_chunk_min: int = 3
@export var souls_per_chunk_max: int = 5

var _player: Node3D
var _chunks: Array[Node3D] = []
var _next_spawn_z: float = 0.0
var _chunks_spawned: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Last free-lane hint so consecutive chunks don't feel identical.
var _last_open_lane: int = 1


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node3D
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
	var biome_chunk: PackedScene = BiomeManager.get_chunk_scene()
	if biome_chunk:
		chunk_scene = biome_chunk


func _on_biome_changed(_biome_id: String) -> void:
	_sync_chunk_from_biome()
	_register_chunk_pools_for_biome()


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
	_register_chunk_pools_for_biome()
	if not ObjectPool.has_pool(POOL_CHUNK):
		var gy: PackedScene = preload("res://scenes/levels/Chunk_Graveyard_01.tscn")
		ObjectPool.register_pool(POOL_CHUNK, gy, CHUNKS_AHEAD + 2)
	if not ObjectPool.has_pool(POOL_PIT):
		ObjectPool.register_pool(POOL_PIT, pit_scene, 8)
	if not ObjectPool.has_pool(POOL_GRAVESTONE):
		ObjectPool.register_pool(POOL_GRAVESTONE, gravestone_scene, 10)
	if not ObjectPool.has_pool(POOL_SIDE):
		ObjectPool.register_pool(POOL_SIDE, side_scene, 6)
	## Pattern lines place more orbs per chunk than scatter density.
	if not ObjectPool.has_pool(POOL_SOUL):
		ObjectPool.register_pool(POOL_SOUL, soul_scene, 48)
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


func _register_chunk_pools_for_biome() -> void:
	var variants: Array = BiomeManager.get_chunk_variants()
	if variants.is_empty():
		var pool_id: String = BiomeManager.get_chunk_pool_id()
		if not ObjectPool.has_pool(pool_id) and chunk_scene:
			ObjectPool.register_pool(pool_id, chunk_scene, CHUNKS_AHEAD + 2)
		return
	for variant in variants:
		if not (variant is Dictionary):
			continue
		var vdict: Dictionary = variant as Dictionary
		var vid: String = str(vdict.get("id", ""))
		var scene: PackedScene = vdict.get("scene") as PackedScene
		if vid == "" or scene == null:
			continue
		if not ObjectPool.has_pool(vid):
			ObjectPool.register_pool(vid, scene, CHUNKS_AHEAD + 2)


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

	var index: int = _chunks_spawned
	_chunks_spawned += 1

	var occupied: Dictionary = {}
	var soul_cells: Dictionary = {}
	if index < safe_chunk_count:
		## Intro: souls only — straight center line, no hazards.
		soul_cells = _populate_from_pattern(
			chunk,
			{
				"id": "intro_safe",
				"obstacles": [],
				"souls": [
					{"kind": POOL_SOUL, "lane": 1, "z": 10.0},
					{"kind": POOL_SOUL, "lane": 1, "z": 7.8},
					{"kind": POOL_SOUL, "lane": 1, "z": 5.6},
					{"kind": POOL_SOUL, "lane": 1, "z": 3.4},
				],
			},
			occupied
		)
	else:
		var difficulty: int = _difficulty_for_chunk(index)
		var biome_id: String = "graveyard"
		if BiomeManager != null:
			biome_id = str(BiomeManager.current_biome)
		var pattern: Dictionary = ChunkPatternsScript.pick_pattern(_rng, difficulty, biome_id)
		if not ChunkPatternsScript.validate_pattern(pattern):
			pattern = ChunkPatternsScript.pick_pattern(_rng, 0, biome_id)
		occupied = _populate_obstacles_from_pattern(chunk, pattern)
		soul_cells = _populate_souls_from_pattern(chunk, pattern, occupied)
		_maybe_spawn_ability_powerup(chunk, index, occupied, soul_cells)
		_last_open_lane = _primary_open_lane(occupied)

	_chunks.append(chunk)
	return chunk


func _difficulty_for_chunk(chunk_index: int) -> int:
	## Maps chunk index → pattern difficulty band (0 = easiest).
	return clampi(chunk_index - safe_chunk_count, 0, 20)


func _populate_from_pattern(chunk: Node3D, pattern: Dictionary, occupied: Dictionary) -> Dictionary:
	occupied.clear()
	var obs: Dictionary = _populate_obstacles_from_pattern(chunk, pattern)
	for k in obs.keys():
		occupied[k] = obs[k]
	return _populate_souls_from_pattern(chunk, pattern, occupied)


func _populate_obstacles_from_pattern(chunk: Node3D, pattern: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	if not chunk.has_method("attach_obstacle"):
		return occupied
	var specs: Array = pattern.get("obstacles", []) as Array
	## Place in Z order (descending = approaching player first).
	var sorted: Array = specs.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		var za: float = float((a as Dictionary).get("z", 0.0)) if a is Dictionary else 0.0
		var zb: float = float((b as Dictionary).get("z", 0.0)) if b is Dictionary else 0.0
		return za > zb
	)

	var placed: Array[Dictionary] = []
	for item in sorted:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item as Dictionary
		var lane: int = clampi(int(spec.get("lane", 1)), 0, LANE_COUNT - 1)
		var z_off: float = float(spec.get("z", 0.0))
		var kind: String = str(spec.get("kind", POOL_GRAVESTONE))
		if not _can_place_obstacle(lane, z_off, occupied, placed):
			## Try shifting to a free lane at this Z rather than blocking everything.
			var alt: int = _find_free_lane_at(z_off, occupied, placed, lane)
			if alt < 0:
				continue
			lane = alt
		var obs: Node3D = _acquire_pooled(kind)
		if obs == null:
			continue
		obs.pool_id = kind
		if obs.has_method("configure"):
			obs.call("configure", lane, z_off)
		chunk.call("attach_obstacle", obs)
		_mark_occupied(occupied, lane, z_off)
		placed.append({"lane": lane, "z": z_off})
	## Exact placements for soul clearance (lane + Z distance).
	occupied["_placements"] = placed
	return occupied


func _populate_souls_from_pattern(
	chunk: Node3D,
	pattern: Dictionary,
	occupied: Dictionary
) -> Dictionary:
	var soul_cells: Dictionary = {}
	if not chunk.has_method("attach_collectible"):
		return soul_cells
	var placements: Array = occupied.get("_placements", []) as Array
	var specs: Array = pattern.get("souls", []) as Array
	for item in specs:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item as Dictionary
		var lane: int = clampi(int(spec.get("lane", 1)), 0, LANE_COUNT - 1)
		var z_off: float = float(spec.get("z", 0.0))
		var kind: String = str(spec.get("kind", POOL_SOUL))
		if not _soul_clear_of_obstacles(lane, z_off, placements):
			## Nudge to a free neighboring lane if the choreography clipped an obstacle.
			var alt: int = _nearest_clear_lane(lane, z_off, placements, soul_cells)
			if alt < 0:
				continue
			lane = alt
		var cell: String = _cell_key(lane, z_off)
		if soul_cells.has(cell):
			continue
		var col: Node3D = _acquire_pooled(kind)
		if col == null:
			continue
		col.pool_id = kind
		if col.has_method("configure"):
			col.call("configure", lane, z_off)
		chunk.call("attach_collectible", col)
		soul_cells[cell] = true
	return soul_cells


func _can_place_obstacle(
	lane: int,
	z_off: float,
	occupied: Dictionary,
	placed: Array[Dictionary]
) -> bool:
	## Reject if this Z-band would become fully blocked (all 3 lanes).
	var band: int = _band(z_off)
	var mask: int = int(occupied.get(band, 0))
	var bit: int = 1 << lane
	if mask & bit:
		return false
	if (mask | bit) == 7:
		return false
	## Keep readable gaps between nearby beats on the same lane.
	for prev in placed:
		var pz: float = float(prev.get("z", 0.0))
		var pl: int = int(prev.get("lane", 0))
		if absf(pz - z_off) < MIN_BEAT_GAP and pl == lane:
			return false
	return true


func _find_free_lane_at(
	z_off: float,
	occupied: Dictionary,
	placed: Array[Dictionary],
	prefer: int
) -> int:
	for attempt in LANE_COUNT:
		var lane: int = (prefer + attempt) % LANE_COUNT
		if _can_place_obstacle(lane, z_off, occupied, placed):
			return lane
	return -1


func _mark_occupied(occupied: Dictionary, lane: int, z_off: float) -> void:
	var band: int = _band(z_off)
	var mask: int = int(occupied.get(band, 0))
	mask |= (1 << clampi(lane, 0, LANE_COUNT - 1))
	occupied[band] = mask


func _soul_clear_of_obstacles(lane: int, z_off: float, placements: Array) -> bool:
	for item in placements:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		if int(d.get("lane", -1)) != lane:
			continue
		if absf(float(d.get("z", 0.0)) - z_off) < SOUL_CLEARANCE_Z:
			return false
	return true


func _nearest_clear_lane(
	prefer: int,
	z_off: float,
	placements: Array,
	soul_cells: Dictionary
) -> int:
	for attempt in LANE_COUNT:
		var lane: int = (prefer + attempt) % LANE_COUNT
		var cell: String = _cell_key(lane, z_off)
		if soul_cells.has(cell):
			continue
		if _soul_clear_of_obstacles(lane, z_off, placements):
			return lane
	return -1


func _primary_open_lane(occupied: Dictionary) -> int:
	## Prefer a lane that was open on the densest band; fallback center.
	var best_lane: int = 1
	var best_free: int = -1
	for lane in LANE_COUNT:
		var free_count: int = 0
		for band_key in occupied.keys():
			if typeof(band_key) != TYPE_INT:
				continue
			var mask: int = int(occupied[band_key])
			if (mask & (1 << lane)) == 0:
				free_count += 1
		if free_count > best_free:
			best_free = free_count
			best_lane = lane
	return best_lane


func _cell_key(lane: int, z_off: float) -> String:
	return "%d|%d" % [lane, _band(z_off)]


func _band(z_off: float) -> int:
	return int(floor(z_off / 4.0))


## At most one ability power-up per chunk after intro.
## Always lane-snapped to a clear free lane.
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

	var pool_id: String = _pick_ability_pool()
	var placements: Array = occupied.get("_placements", []) as Array
	## Prefer rhythmic Z slots away from chunk edges.
	var z_candidates: Array[float] = [12.0, 4.0, -4.0, -12.0]
	var lane_order: Array[int] = [_last_open_lane, 1, 0, 2]
	for z_off in z_candidates:
		for lane in lane_order:
			var lane_i: int = clampi(int(lane), 0, LANE_COUNT - 1)
			if not _soul_clear_of_obstacles(lane_i, z_off, placements):
				continue
			var cell: String = _cell_key(lane_i, z_off)
			if soul_cells.has(cell):
				continue
			var col: Node3D = _acquire_pooled(pool_id)
			if col == null:
				return
			col.pool_id = pool_id
			if col.has_method("configure"):
				col.call("configure", lane_i, z_off)
			chunk.call("attach_collectible", col)
			soul_cells[cell] = true
			return


func _pick_ability_pool() -> String:
	var roll: float = _rng.randf()
	if roll < 0.28:
		return POOL_GHOST
	if roll < 0.52:
		return POOL_MAGNET
	if roll < 0.72:
		return POOL_HOLY
	if roll < 0.88:
		return POOL_CURSED
	return POOL_SECOND


func _acquire_pooled(pool_id: String) -> Node3D:
	var node: Node = ObjectPool.acquire(pool_id)
	if node is Node3D:
		return node as Node3D
	return null


func _chunk_pool_id() -> String:
	return BiomeManager.pick_chunk_pool_id()


func _acquire_chunk() -> Node3D:
	var pool_id: String = _chunk_pool_id()
	var node: Node = ObjectPool.acquire(pool_id)
	if node == null and pool_id != POOL_CHUNK:
		node = ObjectPool.acquire(POOL_CHUNK)
		pool_id = POOL_CHUNK
	if node is Node3D:
		var chunk: Node3D = node as Node3D
		if "pool_id" in chunk:
			chunk.pool_id = pool_id
		return chunk
	if chunk_scene:
		var fallback: Node3D = chunk_scene.instantiate() as Node3D
		if fallback and "pool_id" in fallback:
			fallback.pool_id = pool_id
		return fallback
	return null


func _release_chunk(chunk: Node3D) -> void:
	if chunk == null:
		return
	if chunk.has_method("on_recycled"):
		chunk.call("on_recycled")
	var pool_id: String = ""
	if "pool_id" in chunk:
		pool_id = str(chunk.pool_id)
	if pool_id == "" or not ObjectPool.has_pool(pool_id):
		pool_id = BiomeManager.get_chunk_pool_id()
	if ObjectPool.has_pool(pool_id):
		ObjectPool.release(pool_id, chunk)
	elif ObjectPool.has_pool(POOL_CHUNK):
		ObjectPool.release(POOL_CHUNK, chunk)
	else:
		chunk.queue_free()


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
	_last_open_lane = 1
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
