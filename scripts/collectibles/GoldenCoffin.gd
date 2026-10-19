extends "res://scripts/collectibles/CollectibleBase.gd"
## Golden Coffin — rare pickup worth 25 points.


func _ready() -> void:
	collectible_id = "golden_coffin"
	points = 25
	super._ready()


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	_base_y = 0.85
	position.y = _base_y
