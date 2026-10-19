extends "res://scripts/collectibles/AbilityPickup.gd"
## Holy Light — radiant sphere that clears obstacles / blasts chasers (~7s).

const HOLY_DURATION: float = 7.0


func _ready() -> void:
	ability_id = "holy_light"
	ability_duration = HOLY_DURATION
	super._ready()
