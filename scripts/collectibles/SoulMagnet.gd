extends "res://scripts/collectibles/AbilityPickup.gd"
## Soul Magnet — pulls nearby soul collectibles toward the player (~11s).

const MAGNET_DURATION: float = 11.0


func _ready() -> void:
	ability_id = "soul_magnet"
	ability_duration = MAGNET_DURATION
	super._ready()
