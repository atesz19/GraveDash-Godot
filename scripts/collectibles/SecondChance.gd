extends "res://scripts/collectibles/AbilityPickup.gd"
## Second Chance — single-use stock. Survives one lethal hit with a hover escape.

func _ready() -> void:
	ability_id = "second_chance"
	ability_duration = 0.0
	super._ready()


func _grant(body: Node3D) -> void:
	if body.has_method("apply_second_chance"):
		body.call("apply_second_chance")
	elif body.has_method("apply_powerup"):
		body.call("apply_powerup", "second_chance", 0.0)
