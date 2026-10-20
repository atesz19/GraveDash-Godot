extends "res://scripts/collectibles/CollectibleBase.gd"
## Ghost Form — rare power-up. Grants ~9s of hazard phase-through.

const GHOST_DURATION: float = 9.0


func _ready() -> void:
	collectible_id = "ghost_form"
	points = 0  ## Ability pickup; no score (activation is the reward).
	spin_speed = 2.0
	super._ready()


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	_base_y = 1.2
	position.y = _base_y


func _pickup(body: Node3D) -> void:
	_picked = true
	monitoring = false
	if AudioManager:
		AudioManager.play_powerup_pickup()
	## Activate ghost mode on the player.
	if body.has_method("apply_ghost_form"):
		body.call("apply_ghost_form", GHOST_DURATION)
	elif body.has_method("apply_powerup"):
		body.call("apply_powerup", "ghost_form", GHOST_DURATION)
	collected.emit(0, collectible_id)

	var parent_chunk := _find_chunk()
	if parent_chunk and parent_chunk.has_method("notify_collectible_picked"):
		parent_chunk.call("notify_collectible_picked", self)
	elif pool_id != "" and ObjectPool.has_pool(pool_id):
		on_recycled()
		ObjectPool.release(pool_id, self)
