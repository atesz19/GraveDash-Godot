extends "res://scripts/collectibles/CollectibleBase.gd"
## AbilityPickup — base for timed / stock power-up orbs (no score).

@export var ability_id: String = ""
@export var ability_duration: float = 5.0


func _ready() -> void:
	collectible_id = ability_id if ability_id != "" else collectible_id
	points = 0
	super._ready()


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	_base_y = 1.2
	position.y = _base_y


func _pickup(body: Node3D) -> void:
	_picked = true
	monitoring = false
	_grant(body)
	collected.emit(0, collectible_id)

	var parent_chunk := _find_chunk()
	if parent_chunk and parent_chunk.has_method("notify_collectible_picked"):
		parent_chunk.call("notify_collectible_picked", self)
	elif pool_id != "" and ObjectPool.has_pool(pool_id):
		on_recycled()
		ObjectPool.release(pool_id, self)


func _grant(body: Node3D) -> void:
	if body.has_method("apply_powerup"):
		body.call("apply_powerup", ability_id, ability_duration)
