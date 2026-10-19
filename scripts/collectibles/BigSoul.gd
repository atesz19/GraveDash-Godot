extends "res://scripts/collectibles/CollectibleBase.gd"
## Big Soul — uncommon pickup worth 5 points.


func _ready() -> void:
	collectible_id = "big_soul"
	points = 5
	spin_speed = 1.4
	super._ready()


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	_base_y = 1.15
	position.y = _base_y
