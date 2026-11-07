extends Node3D
## Chunk — recyclable segment. Holds pooled obstacles + collectibles.

const CHUNK_LENGTH: float = 45.0
const CHUNK_WIDTH: float = 9.0
const GROUND_THICKNESS: float = 1.0
## Shoulder densify — keep clear of the 3 play lanes (|x| >= EDGE_MIN_X).
const EDGE_MIN_X: float = 5.2
const PROPS := "res://scenes/levels/props/"
## [scene, weight] per edge set. Near slots sit on the shoulder gaps between baked Props;
## field props fill the open ground beyond the shoulders (graveyard only).
const EDGE_SETS: Dictionary = {
	"graveyard_near": [
		["DecorGravestone_01.tscn", 3.0], ["DecorGravestone_02.tscn", 3.0],
		["DecorGravestone_03.tscn", 3.0], ["DecorGravestone_04.tscn", 3.0],
		["DecorFallenCross.tscn", 2.0], ["DecorFence.tscn", 1.5], ["DecorCoffin.tscn", 1.0],
		["DecorRock.tscn", 2.0], ["DecorBush.tscn", 2.0], ["DecorLantern.tscn", 1.5],
	],
	"graveyard_field": [
		["DecorGravestone_01.tscn", 3.0], ["DecorGravestone_02.tscn", 3.0],
		["DecorGravestone_03.tscn", 3.0], ["DecorGravestone_04.tscn", 3.0],
		["DecorFallenCross.tscn", 2.0], ["DecorObelisk.tscn", 1.2], ["DecorDeadTree.tscn", 2.5],
		["DecorRock.tscn", 1.5], ["DecorBush.tscn", 2.0], ["DecorFallenLog.tscn", 1.0],
		["DecorLantern.tscn", 0.8],
	],
	"castle_near": [
		["DecorCandelabra.tscn", 3.0], ["DecorArmor.tscn", 2.5], ["DecorCoffin.tscn", 1.0],
		["DecorRock.tscn", 1.0], ["DecorBrazier.tscn", 1.0],
	],
}
## Near-shoulder slots in Z gaps between baked Props (x is |x|; side ±1).
const NEAR_SLOTS: Array[Vector3] = [
	Vector3(-1.0, 5.45, 21.5), Vector3(1.0, 5.55, 13.5), Vector3(-1.0, 5.7, 5.5),
	Vector3(1.0, 5.4, -3.5), Vector3(-1.0, 6.1, -9.5), Vector3(1.0, 5.65, -15.5),
	Vector3(-1.0, 5.35, -21.0),
]
const FIELD_MIN_X: float = 9.6
const FIELD_MAX_X: float = 19.0
const FIELD_SPACING: float = 2.6

## "graveyard" | "castle" | "" (no scatter). Chooses the EDGE_SETS used for this chunk.
@export var edge_set: String = "graveyard"
## Ground height the scatter stands on (shoulder / field top, castle floor).
@export var edge_ground_y: float = 0.105
## Near-shoulder slots in castle chunks hug the walls: z positions, side alternates.
@export var castle_slot_z: PackedFloat32Array = PackedFloat32Array([18.0, 11.5, 3.5, -3.5, -11.5, -18.0])
@export var castle_slot_x: float = 5.3
@export var field_count: int = 12
## Fog swallows decor long before this; culling frees draw calls on far chunks.
@export var decor_visibility_end: float = 115.0

@onready var ground: MeshInstance3D = $Ground
@onready var ground_body: StaticBody3D = $Ground/StaticBody3D
@onready var obstacles_root: Node3D = $Obstacles
@onready var collectibles_root: Node3D = $Collectibles

## Set by LevelGenerator when acquired (so release uses the correct pool after biome switch).
var pool_id: String = ""

var _obstacles: Array[Node] = []
var _collectibles: Array[Node] = []
var _edge_scatter_done: bool = false
var _near_nodes: Array[Node3D] = []
var _field_nodes: Array[Node3D] = []
var _baked_big: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


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
	_ensure_edge_scatter()
	_reshuffle_edge_scatter()


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
## Called from body_entered: physics state can't change until the callback returns.
func notify_collectible_picked(collectible: Node) -> void:
	_collectibles.erase(collectible)
	if collectible is Node3D:
		(collectible as Node3D).visible = false
	_release_item.call_deferred(collectible)


## Holy Light / external clear — recycle an obstacle back into its pool.
func notify_obstacle_destroyed(obstacle: Node) -> void:
	_obstacles.erase(obstacle)
	if obstacle is Node3D:
		(obstacle as Node3D).visible = false
	_release_item.call_deferred(obstacle)


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


func _ensure_edge_scatter() -> void:
	## Built once per pooled instance; on_spawned only re-rolls placement (no allocations).
	if _edge_scatter_done:
		return
	_edge_scatter_done = true
	_rng.randomize()
	var props := get_node_or_null("Props") as Node3D
	if props:
		_apply_decor_flags(props)
		for child in props.get_children():
			var n3 := child as Node3D
			if n3 and absf(n3.position.x) > FIELD_MIN_X - 1.5:
				_baked_big.append(Vector2(n3.position.x, n3.position.z))
	if edge_set == "" or get_node_or_null("EdgeScatter") != null:
		return
	var root := Node3D.new()
	root.name = "EdgeScatter"
	add_child(root)
	if edge_set == "castle":
		for i in castle_slot_z.size():
			_near_nodes.append(_make_slot(root, "castle_near"))
	else:
		for i in NEAR_SLOTS.size():
			_near_nodes.append(_make_slot(root, "graveyard_near"))
		for i in field_count:
			_field_nodes.append(_make_slot(root, "graveyard_field"))
	_apply_decor_flags(root)


func _make_slot(root: Node3D, set_id: String) -> Node3D:
	## Wrapper keeps scale/yaw off the prop so GravestoneVisual seats in wrapper space.
	var slot := Node3D.new()
	root.add_child(slot)
	slot.position.y = edge_ground_y
	var path: String = _pick_weighted(EDGE_SETS.get(set_id, []) as Array)
	var packed := load(PROPS + path) as PackedScene
	if packed:
		var prop := packed.instantiate() as Node3D
		if prop:
			slot.add_child(prop)
			slot.set_meta("kind", path)
	return slot


func _pick_weighted(entries: Array) -> String:
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var roll := _rng.randf() * total
	for e in entries:
		roll -= float(e[1])
		if roll <= 0.0:
			return str(e[0])
	return str(entries[0][0]) if not entries.is_empty() else ""


func _reshuffle_edge_scatter() -> void:
	if _near_nodes.is_empty() and _field_nodes.is_empty():
		return
	_rng.randomize()
	if edge_set == "castle":
		var flip: float = -1.0 if _rng.randf() < 0.5 else 1.0
		for i in _near_nodes.size():
			var slot := _near_nodes[i]
			var side: float = flip * (1.0 if i % 2 == 0 else -1.0)
			slot.visible = _rng.randf() < 0.8
			slot.position = Vector3(side * castle_slot_x, edge_ground_y, castle_slot_z[i] + _rng.randf_range(-0.8, 0.8))
			## Props face +X; turn them toward the track on the right wall.
			slot.rotation_degrees.y = 180.0 if side > 0.0 else 0.0
		return
	for i in _near_nodes.size():
		var slot := _near_nodes[i]
		var spec: Vector3 = NEAR_SLOTS[i]
		var kind: String = str(slot.get_meta("kind", ""))
		slot.visible = _rng.randf() < 0.85
		var x: float = maxf(EDGE_MIN_X + 0.15, spec.y + _rng.randf_range(-0.12, 0.25))
		slot.position = Vector3(spec.x * x, edge_ground_y, spec.z + _rng.randf_range(-0.5, 0.5))
		if kind == "DecorFence.tscn":
			slot.rotation_degrees.y = spec.x * 90.0
		elif kind == "DecorLantern.tscn":
			## Lantern arm (+X) leans over the track.
			slot.rotation_degrees.y = 180.0 if spec.x > 0.0 else 0.0
		else:
			slot.rotation_degrees.y = spec.x * _rng.randf_range(-28.0, 28.0)
		slot.scale = Vector3.ONE * _rng.randf_range(0.92, 1.12)
	var placed: Array[Vector2] = []
	for slot in _field_nodes:
		var pos := Vector2.ZERO
		for attempt in 8:
			var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
			pos = Vector2(side * _rng.randf_range(FIELD_MIN_X, FIELD_MAX_X), _rng.randf_range(-21.5, 21.5))
			if _field_spot_free(pos, placed):
				break
		placed.append(pos)
		slot.position = Vector3(pos.x, edge_ground_y, pos.y)
		slot.rotation_degrees.y = _rng.randf_range(-180.0, 180.0)
		slot.scale = Vector3.ONE * _rng.randf_range(0.85, 1.3)


func _field_spot_free(pos: Vector2, placed: Array[Vector2]) -> bool:
	for p in placed:
		if p.distance_to(pos) < FIELD_SPACING:
			return false
	for p in _baked_big:
		if p.distance_to(pos) < 4.0:
			return false
	return true


func _apply_decor_flags(n: Node) -> void:
	## Decor never casts moon shadows (mobile shadow pass cost) and culls past the fog.
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var reach: float = decor_visibility_end
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			## Small clutter disappears into fog much sooner than walls / trees.
			var extent: float = (gi as MeshInstance3D).get_aabb().get_longest_axis_size()
			if extent < 1.2:
				reach = minf(reach, 70.0)
			elif extent < 3.0:
				reach = minf(reach, 95.0)
		gi.visibility_range_end = reach
	for c in n.get_children():
		_apply_decor_flags(c)
