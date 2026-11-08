extends RefCounted
class_name TrackGeometry
## Shared obstacle / player dimensions. Obstacle scenes, ChunkPatterns and RouteSolver all
## read these so hitboxes, visuals and the fairness model stay in lockstep.

const LANE_X: Array[float] = [-2.5, 0.0, 2.5]
const LANE_COUNT: int = 3

## Physics layer 5 — rideable train bodies. Kept off layer 1 so the camera SpringArm
## (mask 1) never snaps forward when a carriage passes behind the player.
const LAYER_RIDEABLE: int = 16

# --- Player (mirrors PlayerController) -----------------------------------------
const START_SPEED: float = 10.5
const MAX_SPEED: float = 25.0
const SPEED_RAMP: float = 0.17
const JUMP_VELOCITY: float = 10.5
const GRAVITY: float = 28.0
const SLIDE_TIME: float = 0.75
const LANE_TIME: float = 0.20
const STAND_H: float = 1.8
const SLIDE_H: float = 0.9
const RADIUS: float = 0.4
const SOUL_FLOAT_Y: float = 1.05

# --- Low barrier: jump over OR roll under -------------------------------------
const LOW_BOTTOM: float = 1.0
const LOW_TOP: float = 1.35
const LOW_DEPTH: float = 0.22
const LOW_WIDTH: float = 2.0

# --- High barrier: roll under only --------------------------------------------
const HIGH_BOTTOM: float = 1.05
const HIGH_TOP: float = 3.25
const HIGH_DEPTH: float = 0.36
const HIGH_WIDTH: float = 2.0

# --- Gravestone: jump only (FBX visual, existing scene) ------------------------
const GRAVE_TOP: float = 1.2
const GRAVE_DEPTH: float = 0.6

# --- Full-height block: change lane --------------------------------------------
const BLOCK_TOP: float = 3.0
const BLOCK_DEPTH: float = 1.1
const BLOCK_WIDTH: float = 2.2

# --- Hearse train: ride on top, ramp up, change lane -----------------------------
const TRAIN_ROOF: float = 2.3
## Side/front hazard stops short of the roof so ramp runners and roof landings never clip it.
const TRAIN_HAZARD_TOP: float = 2.1
const TRAIN_WIDTH: float = 2.15
const CAR_LEN: float = 9.0
const CAR_GAP: float = 0.8
const RAMP_LEN: float = 6.0
const MAX_CARS: int = 4

# --- Runaway coffin cart: rolls toward the player ------------------------------
const CART_TOP: float = 2.6
const CART_LEN: float = 2.8
const CART_WIDTH: float = 1.9
const CART_SPEED: float = 7.0
## Starts rolling when the player is this close (world meters).
const CART_TRIGGER: float = 55.0
const CART_MAX_TRAVEL: float = 60.0


static func train_length(cars: int) -> float:
	var n: int = clampi(cars, 1, MAX_CARS)
	return float(n) * CAR_LEN + float(n - 1) * CAR_GAP


## Player feet height t seconds after a ground jump (continuous approximation).
static func jump_height(t: float) -> float:
	return maxf(0.0, JUMP_VELOCITY * t - 0.5 * GRAVITY * t * t)


static func jump_air_time() -> float:
	return 2.0 * JUMP_VELOCITY / GRAVITY


static func speed_at_time(t: float) -> float:
	return clampf(START_SPEED + t * SPEED_RAMP, START_SPEED, MAX_SPEED)


## Base speed reached after running `dist` meters from a standing start of the ramp.
static func speed_at_distance(dist: float) -> float:
	var a: float = 0.5 * SPEED_RAMP
	var t_max: float = (MAX_SPEED - START_SPEED) / SPEED_RAMP
	var d_max: float = START_SPEED * t_max + a * t_max * t_max
	if dist >= d_max:
		return MAX_SPEED
	var t: float = (-START_SPEED + sqrt(START_SPEED * START_SPEED + 4.0 * a * maxf(dist, 0.0))) / (2.0 * a)
	return speed_at_time(t)
