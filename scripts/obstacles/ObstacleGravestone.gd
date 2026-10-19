extends "res://scripts/obstacles/ObstacleBase.gd"
## Fallen gravestone — low solid hazard. Jump over it or change lanes.
## Same Y gate as pits so a clean jump clears the Area3D.

const KILL_Y_MAX: float = 1.15


func can_kill_body(body: Node3D) -> bool:
	return body.global_position.y < KILL_Y_MAX


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	position.y = 0.0
	## Tilt reads as a fallen stone.
	rotation_degrees = Vector3(0.0, randf_range(-25.0, 25.0), 55.0)
