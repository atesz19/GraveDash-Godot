extends "res://scripts/obstacles/ObstacleBase.gd"
## Open grave / pit — kill if the player runs into the hole without jumping clear.
## Jump-over: only lethal while the player's feet are near ground level.

## Feet below this Y count as "in the pit" (CharacterBody origin ≈ feet).
const KILL_Y_MAX: float = 1.05


func can_kill_body(body: Node3D) -> bool:
	## Mid-air jump clears the pit volume.
	return body.global_position.y < KILL_Y_MAX


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	## Pit sits flush with the ground plane.
	position.y = 0.0
