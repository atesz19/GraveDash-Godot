extends "res://scripts/obstacles/ObstacleBase.gd"
## Low barrier — must slide under. Standing into it kills.


func can_kill_body(body: Node3D) -> bool:
	if body.get("is_sliding") == true:
		return false
	return true


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation = Vector3.ZERO
