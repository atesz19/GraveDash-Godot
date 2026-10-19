extends "res://scripts/collectibles/AbilityPickup.gd"
## Cursed Speed — big speed boost with sluggish lane changes (~6s).

const CURSED_DURATION: float = 6.0


func _ready() -> void:
	ability_id = "cursed_speed"
	ability_duration = CURSED_DURATION
	super._ready()
