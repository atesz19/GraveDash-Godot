extends "res://scripts/obstacles/ObstacleBase.gd"
## Minor gravestone — short jump-over hazard using PBR FBX visuals.

const KILL_Y_MAX: float = 1.15
const VISUAL_VARIANTS: Array[String] = [
	"res://scenes/levels/props/DecorGravestone_01.tscn",
	"res://scenes/levels/props/DecorGravestone_02.tscn",
	"res://scenes/levels/props/DecorGravestone_03.tscn",
	"res://scenes/levels/props/DecorGravestone_04.tscn",
]

@onready var visual_slot: Node3D = $Visual


func _ready() -> void:
	super._ready()
	if visual_slot and visual_slot.get_child_count() == 0:
		_spawn_visual()


func can_kill_body(body: Node3D) -> bool:
	return body.global_position.y < KILL_Y_MAX


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation_degrees = Vector3(0.0, randf_range(-20.0, 20.0), 0.0)
	## Refresh visual when recycled from the pool.
	_spawn_visual()


func _spawn_visual() -> void:
	if visual_slot == null:
		visual_slot = get_node_or_null("Visual") as Node3D
	if visual_slot == null:
		return
	for c in visual_slot.get_children():
		c.queue_free()
	var path: String = VISUAL_VARIANTS[randi() % VISUAL_VARIANTS.size()]
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return
	var stone: Node3D = packed.instantiate() as Node3D
	if stone == null:
		return
	visual_slot.add_child(stone)
	## Lane hazard scale — keep footprint inside one lane, clear neighbors.
	stone.scale *= 0.95
