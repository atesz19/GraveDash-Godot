extends RefCounted
## EconomyConfig — single tuning table for the soul economy.
## Pickup values, mission rewards, multiplier bonus, upgrade ladders and skin prices.
## Balance model + targets: tools/validate_economy.gd (prints souls/run vs. costs).

# --- Pickups -----------------------------------------------------------------
const SOUL_ORB_VALUE: int = 1
const GOLDEN_COFFIN_VALUE: int = 25
## BigSoul value is upgrade-driven (see UPGRADES "big_soul_value", level 0 = base).

# --- Run payout --------------------------------------------------------------
## Bonus on collected souls per mission-multiplier step above x1 (x5 → +20%).
const MULT_SOUL_BONUS_PER_STEP: float = 0.05
const MULT_SOUL_BONUS_MAX: float = 1.0

## Souls granted when a mission completes (banked with the run payout).
const MISSION_REWARDS: Dictionary = {
	"run_100": 20,
	"run_250": 35,
	"run_500": 60,
	"run_1000": 110,
	"souls_5": 15,
	"souls_15": 30,
	"souls_30": 55,
	"souls_50": 90,
	"dodge_5": 20,
	"dodge_15": 40,
	"dodge_30": 75,
	"power_1": 20,
	"power_3": 45,
	"power_5": 80,
}
const MISSION_REWARD_DEFAULT: int = 25

# --- Upgrades ----------------------------------------------------------------
## Cost to buy level N (index N-1). Each upgrade multiplies by its cost_scale,
## rounded to COST_ROUND.
const UPGRADE_COST_CURVE: Array[int] = [150, 400, 900, 1800, 3500]
const COST_ROUND: int = 25

## values[0] = un-upgraded; values[N] = effect at level N. Max level = values.size() - 1.
## format: label for one value in the shop row ("%s" receives the formatted value).
const UPGRADES: Array[Dictionary] = [
	{
		"id": "ghost_duration",
		"name": "Ghost Form",
		"description": "Phase through hazards for longer",
		"values": [9.0, 10.5, 12.0, 13.5, 15.0, 17.0],
		"format": "%ss",
		"cost_scale": 1.0,
		"color": Color(0.62, 0.42, 0.95, 1),
	},
	{
		"id": "magnet_duration",
		"name": "Soul Magnet",
		"description": "Magnet pulls souls for longer",
		"values": [11.0, 12.5, 14.0, 16.0, 18.0, 20.0],
		"format": "%ss",
		"cost_scale": 1.0,
		"color": Color(0.35, 0.85, 1.0, 1),
	},
	{
		"id": "magnet_radius",
		"name": "Magnet Reach",
		"description": "Soul Magnet pulls from farther away",
		"values": [14.0, 16.0, 18.0, 20.0, 23.0, 26.0],
		"format": "%sm",
		"cost_scale": 0.9,
		"color": Color(0.3, 0.7, 0.95, 1),
	},
	{
		"id": "holy_duration",
		"name": "Holy Light",
		"description": "Obstacle-clearing light lasts longer",
		"values": [7.0, 8.0, 9.0, 10.0, 11.5, 13.0],
		"format": "%ss",
		"cost_scale": 1.0,
		"color": Color(1.0, 0.92, 0.55, 1),
	},
	{
		"id": "cursed_duration",
		"name": "Cursed Speed",
		"description": "Speed burst lasts longer (more distance)",
		"values": [6.0, 7.0, 8.0, 9.0, 10.0, 11.0],
		"format": "%ss",
		"cost_scale": 0.8,
		"color": Color(0.95, 0.42, 0.25, 1),
	},
	{
		"id": "big_soul_value",
		"name": "Big Soul",
		"description": "Big Souls are worth more",
		"values": [5, 6, 7, 8, 10, 12],
		"format": "%s souls",
		"cost_scale": 1.25,
		"color": Color(0.55, 1.0, 0.85, 1),
	},
	{
		"id": "head_start",
		"name": "Head Start",
		"description": "Begin each run with a ghostly sprint",
		"values": [0.0, 3.0, 4.5, 6.0, 7.5, 9.0],
		"format": "%ss",
		"cost_scale": 1.25,
		"color": Color(0.75, 0.6, 1.0, 1),
	},
	{
		"id": "starting_chance",
		"name": "Guardian Spirit",
		"description": "Chance to start a run with Second Chance",
		"values": [0, 20, 40, 60, 80, 100],
		"format": "%s%%",
		"cost_scale": 1.5,
		"color": Color(1.0, 0.75, 0.4, 1),
	},
]

## Head Start sprint speed multiplier (stacks with Ghost Form phasing).
const HEAD_START_SPEED_MULT: float = 1.55

# --- Skins -------------------------------------------------------------------
const SKIN_PRICES: Dictionary = {
	"witch": 0,
	"skeleton_minion": 2500,
	"skeleton_rogue": 5000,
	"skeleton_warrior": 8000,
	"skeleton_mage": 12000,
}


static func get_upgrade_def(upgrade_id: String) -> Dictionary:
	for def in UPGRADES:
		if str(def.get("id", "")) == upgrade_id:
			return def
	return {}


static func max_level(upgrade_id: String) -> int:
	var def: Dictionary = get_upgrade_def(upgrade_id)
	if def.is_empty():
		return 0
	return (def.get("values", []) as Array).size() - 1


static func value_at(upgrade_id: String, level: int) -> float:
	var def: Dictionary = get_upgrade_def(upgrade_id)
	if def.is_empty():
		return 0.0
	var values: Array = def.get("values", []) as Array
	if values.is_empty():
		return 0.0
	return float(values[clampi(level, 0, values.size() - 1)])


## Cost to go from `current_level` to `current_level + 1`; -1 when maxed.
static func cost_for_next(upgrade_id: String, current_level: int) -> int:
	if current_level < 0 or current_level >= max_level(upgrade_id):
		return -1
	var def: Dictionary = get_upgrade_def(upgrade_id)
	var idx: int = clampi(current_level, 0, UPGRADE_COST_CURVE.size() - 1)
	var raw: float = float(UPGRADE_COST_CURVE[idx]) * float(def.get("cost_scale", 1.0))
	return maxi(COST_ROUND, int(round(raw / float(COST_ROUND))) * COST_ROUND)


static func total_cost_to_max(upgrade_id: String) -> int:
	var total: int = 0
	for lvl in max_level(upgrade_id):
		total += cost_for_next(upgrade_id, lvl)
	return total


static func format_value(upgrade_id: String, value: float) -> String:
	var def: Dictionary = get_upgrade_def(upgrade_id)
	var fmt: String = str(def.get("format", "%s"))
	var shown: String = str(int(value)) if is_equal_approx(value, round(value)) else "%.1f" % value
	return fmt % shown


static func mission_reward(mission_id: String) -> int:
	return int(MISSION_REWARDS.get(mission_id, MISSION_REWARD_DEFAULT))


static func multiplier_bonus_ratio(multiplier: int) -> float:
	return clampf(float(maxi(multiplier, 1) - 1) * MULT_SOUL_BONUS_PER_STEP, 0.0, MULT_SOUL_BONUS_MAX)


static func skin_price(skin_id: String, fallback: int = 0) -> int:
	return int(SKIN_PRICES.get(skin_id, fallback))
