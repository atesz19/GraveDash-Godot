extends "res://scripts/collectibles/CollectibleBase.gd"
## Big Soul — uncommon pickup; value scales with the "Big Soul" shop upgrade.

const Economy = preload("res://scripts/economy/EconomyConfig.gd")


func _ready() -> void:
	collectible_id = "big_soul"
	points = int(Economy.value_at("big_soul_value", 0))
	spin_speed = 1.4
	super._ready()


func get_soul_value() -> int:
	if UpgradeManager:
		return UpgradeManager.get_big_soul_value()
	return points


func configure(lane: int, z_offset: float) -> void:
	super.configure(lane, z_offset)
	_base_y = 1.15
	position.y = _base_y
