extends "res://scripts/collectibles/CollectibleBase.gd"
## Soul orb — common pickup (value in EconomyConfig).

const Economy = preload("res://scripts/economy/EconomyConfig.gd")


func _ready() -> void:
	collectible_id = "soul_orb"
	points = Economy.SOUL_ORB_VALUE
	spin_speed = 1.8
	super._ready()
