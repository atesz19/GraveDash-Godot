extends "res://scripts/obstacles/ObstacleBase.gd"
## Tall crate / gate — must jump over. Lethal while feet are near ground.


const KILL_Y_MAX: float = 1.25


func can_kill_body(body: Node3D) -> bool:
	return body.global_position.y < KILL_Y_MAX


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation = Vector3.ZERO
