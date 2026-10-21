extends "res://scripts/obstacles/ObstacleBase.gd"
## Minor gravestone — short jump-over hazard / lane block (not the main obstacle type).

const KILL_Y_MAX: float = 1.05


func can_kill_body(body: Node3D) -> bool:
	return body.global_position.y < KILL_Y_MAX


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation_degrees = Vector3(0.0, randf_range(-20.0, 20.0), 0.0)
