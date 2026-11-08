extends Node3D
## LevelGenerator — streams hand-authored ChunkPatterns sections onto recyclable chunks.
##
## Sections are longer than a chunk. They are planned ahead in world space (one continuous
## track, z = TRACK_START_Z - d), each built for the speed the player will have when they
## reach it, then every item is attached to the chunk that holds its forward-most point
## (so a long train is only recycled once the player is fully past it).

const Patterns = preload("res://scripts/levels/ChunkPatterns.gd")
const Geo = preload("res://scripts/levels/TrackGeometry.gd")

const CHUNK_LENGTH: float = 45.0
const CHUNKS_AHEAD: int = 5
const RECYCLE_MARGIN: float = 10.0
## Where section streaming begins (the player spawns at z≈0 on an intro soul line).
const TRACK_START_Z: float = -10.0
## Planned-section history kept for get_track_window() (autopilot / debug).
const KEEP_SECTIONS: int = 8

const POOL_CHUNK: String = "chunk_graveyard"
const POOL_GRAVESTONE: String = "obstacle_gravestone"
const POOL_LOW: String = "obstacle_low"
const POOL_HIGH: String = "obstacle_high"
const POOL_BLOCK: String = "obstacle_block"
const POOL_TRAIN: String = "obstacle_train"
const POOL_CART: String = "obstacle_cart"
const POOL_SOUL: String = "collectible_soul"
const POOL_BIG_SOUL: String = "collectible_big_soul"
const POOL_COFFIN: String = "collectible_golden_coffin"
const POOL_GHOST: String = "collectible_ghost_form"
const POOL_MAGNET: String = "collectible_soul_magnet"
const POOL_HOLY: String = "collectible_holy_light"
const POOL_SECOND: String = "collectible_second_chance"
const POOL_CURSED: String = "collectible_cursed_speed"

const LANE_COUNT: int = 3

@export var chunk_scene: PackedScene
@export var gravestone_scene: PackedScene
@export var low_scene: PackedScene
@export var high_scene: PackedScene
@export var block_scene: PackedScene
@export var train_scene: PackedScene
@export var cart_scene: PackedScene
@export var soul_scene: PackedScene
@export var big_soul_scene: PackedScene
@export var coffin_scene: PackedScene
@export var ghost_form_scene: PackedScene
@export var soul_magnet_scene: PackedScene
@export var holy_light_scene: PackedScene
@export var second_chance_scene: PackedScene
@export var cursed_speed_scene: PackedScene
@export var player_path: NodePath = ^"../Player"
## Deprecated exports kept so older Main.tscn assignments still load (unused).
@export var pit_scene: PackedScene
@export var side_scene: PackedScene
@export var platform_scene: PackedScene

## Chance that a section carries one ability power-up (at a pre-validated clear slot).
@export var ability_powerup_chance: float = 0.4
## Legacy export kept for scene compatibility.
@export var ghost_form_chance: float = 0.12
## Fixed seed for reproducible tracks (0 = random).
@export var track_seed: int = 0

var _player: Node3D
var _chunks: Array[Node3D] = []
var _next_spawn_z: float = 0.0
var _chunks_spawned: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Planned items not yet attached: {pool, lane, z, anchor_z, y, extras}.
var _pending: Array[Dictionary] = []
var _plan_end_z: float = TRACK_START_Z
var _history: Array = []
## Recent planned sections: {id, z_start, layout}.
var _sections: Array[Dictionary] = []


func _ready() -> void:
	if track_seed != 0:
		_rng.seed = track_seed
	else:
		_rng.randomize()
	_player = get_node_or_null(player_path) as Node3D
	_sync_chunk_from_biome()
	_ensure_scenes()
	_register_pools()
	_reset_state()
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
	if not BiomeManager.biome_changed.is_connected(_on_biome_changed):
		BiomeManager.biome_changed.connect(_on_biome_changed)


func _reset_state() -> void:
	_next_spawn_z = 0.0
	_chunks_spawned = 0
	_pending.clear()
	_plan_end_z = TRACK_START_Z
	_history.clear()
	_sections.clear()


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
	if gravestone_scene == null:
		gravestone_scene = preload("res://scenes/obstacles/ObstacleGravestone.tscn")
	if low_scene == null:
		low_scene = preload("res://scenes/obstacles/ObstacleLow.tscn")
	if high_scene == null:
		high_scene = preload("res://scenes/obstacles/ObstacleHigh.tscn")
	if block_scene == null:
		block_scene = preload("res://scenes/obstacles/ObstacleBlock.tscn")
	if train_scene == null:
		train_scene = preload("res://scenes/obstacles/ObstacleTrain.tscn")
	if cart_scene == null:
		cart_scene = preload("res://scenes/obstacles/ObstacleCart.tscn")
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
	for stale in ["obstacle_pit", "obstacle_side", "obstacle_platform"]:
		if ObjectPool.has_pool(stale):
			ObjectPool.clear_pool(stale)
	var specs: Array = [
		[POOL_GRAVESTONE, gravestone_scene, 8],
		[POOL_LOW, low_scene, 12],
		[POOL_HIGH, high_scene, 12],
		[POOL_BLOCK, block_scene, 14],
		[POOL_TRAIN, train_scene, 10],
		[POOL_CART, cart_scene, 4],
		[POOL_SOUL, soul_scene, 110],
		[POOL_BIG_SOUL, big_soul_scene, 6],
		[POOL_COFFIN, coffin_scene, 3],
		[POOL_GHOST, ghost_form_scene, 3],
		[POOL_MAGNET, soul_magnet_scene, 3],
		[POOL_HOLY, holy_light_scene, 3],
		[POOL_SECOND, second_chance_scene, 2],
		[POOL_CURSED, cursed_speed_scene, 3],
	]
	for spec in specs:
		if not ObjectPool.has_pool(str(spec[0])):
			ObjectPool.register_pool(str(spec[0]), spec[1] as PackedScene, int(spec[2]))


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
			ObjectPool.register_pool(vid, scene, ceili(float(CHUNKS_AHEAD + 2) / variants.size()) + 1)


# --- Section planning --------------------------------------------------------------

func _ensure_plan(to_z: float) -> void:
	while _plan_end_z > to_z:
		_plan_next_section()


func _plan_next_section() -> void:
	var dist: float = -_plan_end_z
	var band: int = Patterns.band_for_distance(dist)
	var biome_id: String = str(BiomeManager.current_biome) if BiomeManager != null else "graveyard"
	var section: Dictionary = Patterns.pick_section(_rng, band, biome_id, _history)
	_history.append(section["id"])
	if _history.size() > 12:
		_history.pop_front()
	var v: float = Geo.speed_at_distance(dist)
	var layout: Dictionary = Patterns.build_layout(section, v)
	var z0: float = _plan_end_z
	for o in layout["obstacles"]:
		var kind: String = str(o["kind"])
		var extras: Dictionary = {}
		var z: float = z0 - float(o["d"])
		var anchor: float = z
		if kind == Patterns.KIND_TRAIN:
			extras = {"cars": int(o["cars"]), "ramp": bool(o["ramp"])}
			anchor = z0 - float(o["d1"])
		_pending.append({"pool": kind, "lane": int(o["lane"]), "z": z, "anchor": anchor, "y": 0.0, "extras": extras})
	for s in layout["souls"]:
		var sz: float = z0 - float(s["d"])
		_pending.append({"pool": str(s["kind"]), "lane": int(s["lane"]), "z": sz, "anchor": sz, "y": float(s["y"]), "extras": {}})
	var slots: Array = layout["powerup_slots"]
	if not slots.is_empty() and dist > 60.0 and _rng.randf() < ability_powerup_chance:
		var slot: Dictionary = slots[_rng.randi_range(0, slots.size() - 1)]
		var pz: float = z0 - float(slot["d"])
		_pending.append({"pool": _pick_ability_pool(), "lane": int(slot["lane"]), "z": pz, "anchor": pz, "y": 0.0, "extras": {}})
	_sections.append({"id": section["id"], "z_start": z0, "layout": layout})
	if _sections.size() > KEEP_SECTIONS:
		_sections.pop_front()
	_plan_end_z = z0 - float(layout["length"])


## Planned sections as one layout in track distance (d = TRACK_START_Z - z), for tools.
func get_track_sections() -> Array[Dictionary]:
	return _sections


func track_d_for_z(z: float) -> float:
	return TRACK_START_Z - z


# --- Chunks ------------------------------------------------------------------------

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
	var near_z: float = origin_z + CHUNK_LENGTH * 0.5
	var far_z: float = origin_z - CHUNK_LENGTH * 0.5
	if index == 0:
		for i in 7:
			_attach_item(chunk, origin_z, {"pool": POOL_SOUL, "lane": 1, "z": 8.0 - float(i) * 2.4, "y": 0.0, "extras": {}})
	_ensure_plan(far_z - 1.0)
	var keep: Array[Dictionary] = []
	for item in _pending:
		var a: float = float(item["anchor"])
		if a <= near_z and a > far_z:
			_attach_item(chunk, origin_z, item)
		else:
			keep.append(item)
	_pending = keep
	_chunks.append(chunk)
	return chunk


func _attach_item(chunk: Node3D, origin_z: float, item: Dictionary) -> void:
	var pool_id: String = str(item["pool"])
	var node: Node3D = _acquire_pooled(pool_id)
	if node == null:
		return
	node.set("pool_id", pool_id)
	var lane: int = clampi(int(item["lane"]), 0, LANE_COUNT - 1)
	var local_z: float = float(item["z"]) - origin_z
	if node.has_method("set_height_offset"):
		node.call("configure", lane, local_z)
		var dy: float = float(item.get("y", 0.0))
		if absf(dy) > 0.001:
			node.call("set_height_offset", dy)
		chunk.call("attach_collectible", node)
	else:
		node.call("configure", lane, local_z, item.get("extras", {}))
		chunk.call("attach_obstacle", node)


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
		var far_edge_z: float = rear.global_position.z - CHUNK_LENGTH * 0.5
		if far_edge_z > _player.global_position.z + RECYCLE_MARGIN:
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
	_reset_state()
	for i in CHUNKS_AHEAD:
		_spawn_chunk_at(_next_spawn_z)
		_next_spawn_z -= CHUNK_LENGTH
