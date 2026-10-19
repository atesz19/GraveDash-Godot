extends "res://scripts/collectibles/CollectibleBase.gd"
## Soul orb — common pickup worth 1 point.


func _ready() -> void:
	collectible_id = "soul_orb"
	points = 1
	super._ready()
