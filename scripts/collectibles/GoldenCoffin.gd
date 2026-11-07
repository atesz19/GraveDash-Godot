extends "res://scripts/collectibles/CollectibleBase.gd"
## Golden Coffin — rare jackpot pickup (value in EconomyConfig).

const Economy = preload("res://scripts/economy/EconomyConfig.gd")


func _ready() -> void:
	collectible_id = "golden_coffin"
	points = Economy.GOLDEN_COFFIN_VALUE
	spin_speed = 0.9
	super._ready()


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	_base_y = 0.85
	position.y = _base_y
