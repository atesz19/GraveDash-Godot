extends Node
## UpgradeManager — persistent leveled Soul Shop upgrades (power-ups, magnet, Big Soul, run start).
## Costs/effects live in scripts/economy/EconomyConfig.gd. Save key: upgrade_levels (Dictionary).

signal upgrades_changed

const Economy = preload("res://scripts/economy/EconomyConfig.gd")
const SAVE_KEY_LEVELS: String = "upgrade_levels"

const POWERUP_UPGRADE: Dictionary = {
	"ghost_form": "ghost_duration",
	"soul_magnet": "magnet_duration",
	"magnet": "magnet_duration",
	"holy_light": "holy_duration",
	"cursed_speed": "cursed_duration",
}

## upgrade_id -> purchased level (0 = not upgraded).
var levels: Dictionary = {}


func _ready() -> void:
	_load()


func get_catalog() -> Array[Dictionary]:
	return Economy.UPGRADES


func get_level(upgrade_id: String) -> int:
	return clampi(int(levels.get(upgrade_id, 0)), 0, Economy.max_level(upgrade_id))


func get_max_level(upgrade_id: String) -> int:
	return Economy.max_level(upgrade_id)


func is_maxed(upgrade_id: String) -> bool:
	return get_level(upgrade_id) >= get_max_level(upgrade_id)


func get_value(upgrade_id: String) -> float:
	return Economy.value_at(upgrade_id, get_level(upgrade_id))


func get_next_cost(upgrade_id: String) -> int:
	return Economy.cost_for_next(upgrade_id, get_level(upgrade_id))


func can_afford(upgrade_id: String) -> bool:
	var cost: int = get_next_cost(upgrade_id)
	return cost > 0 and ScoreManager != null and ScoreManager.total_souls >= cost


func buy_upgrade(upgrade_id: String) -> String:
	## Returns empty on success, otherwise an error message.
	if Economy.get_upgrade_def(upgrade_id).is_empty():
		return "Unknown upgrade."
	var cost: int = get_next_cost(upgrade_id)
	if cost < 0:
		return "Already maxed."
	if ScoreManager == null or not ScoreManager.spend_souls(cost):
		return "Not enough souls."
	levels[upgrade_id] = get_level(upgrade_id) + 1
	_save()
	upgrades_changed.emit()
	return ""


# --- Gameplay hooks ----------------------------------------------------------

func get_powerup_duration(powerup_id: String, fallback: float = 0.0) -> float:
	var upgrade_id: String = str(POWERUP_UPGRADE.get(powerup_id, ""))
	if upgrade_id == "":
		return fallback
	return get_value(upgrade_id)


func get_magnet_range() -> float:
	return get_value("magnet_radius")


func get_big_soul_value() -> int:
	return int(get_value("big_soul_value"))


func get_head_start_seconds() -> float:
	return get_value("head_start")


func get_head_start_speed_mult() -> float:
	return Economy.HEAD_START_SPEED_MULT


func roll_starting_second_chance() -> bool:
	var pct: float = get_value("starting_chance")
	if pct <= 0.0:
		return false
	return randf() * 100.0 < pct


func _load() -> void:
	levels = {}
	if SaveSystem == null:
		return
	var raw: Variant = SaveSystem.get_value(SAVE_KEY_LEVELS, {})
	if raw is Dictionary:
		for k in (raw as Dictionary).keys():
			levels[str(k)] = maxi(0, int((raw as Dictionary)[k]))


func _save() -> void:
	if SaveSystem == null:
		return
	SaveSystem.set_value(SAVE_KEY_LEVELS, levels.duplicate())
	SaveSystem.save()
