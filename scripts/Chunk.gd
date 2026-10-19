extends Node3D
## Chunk — one recyclable level segment. Length must match LevelGenerator.CHUNK_LENGTH.

const CHUNK_LENGTH: float = 45.0
const CHUNK_WIDTH: float = 9.0
const GROUND_THICKNESS: float = 1.0

@onready var ground: MeshInstance3D = $Ground
@onready var ground_body: StaticBody3D = $Ground/StaticBody3D


func _ready() -> void:
	add_to_group("chunk")


## Called by LevelGenerator after positioning a pooled instance.
func on_spawned() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


## Called before returning to ObjectPool.
func on_recycled() -> void:
	## Clear dynamic children (obstacles/enemies) in later slices.
	pass
