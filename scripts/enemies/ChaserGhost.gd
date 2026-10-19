extends Node3D
## ChaserGhost — stays behind the player (-Z runner), gradually closes in, catches on contact.
## Ghost Form: cannot catch; gently pushed back to a safe gap.

signal almost_close(gap: float)
signal caught_player

const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]

## Gap = chaser.z - player.z (positive while behind). Catch when gap ≤ this.
const CATCH_DISTANCE: float = 2.2
## Soft floor while Ghost Form is active / after a scare pushback.
const SAFE_GAP: float = 12.0
## Hard minimum — never pass ahead of the player.
const MIN_BEHIND: float = 1.5
## Distance that triggers "Almost Caught" feedback.
const ALMOST_DISTANCE: float = 7.0

var pool_id: String = "chaser_ghost"
var player: Node3D = null

## Horizontal offset relative to the player's lane center (-1 / 0 / +1-ish).
var lane_offset: float = 0.0
## Multiplier vs player speed when closing a large gap.
var speed_jitter: float = 1.04
## Desired gap the chaser is trying to hold (shrinks over time).
var target_gap: float = 20.0

var _lane_stick_timer: float = 0.0
var _last_player_lane: int = 1
var _caught: bool = false


func _ready() -> void:
	add_to_group("chaser")
	add_to_group("enemy")


func setup(p: Node3D, start_gap: float, offset: float, jitter: float) -> void:
	player = p
	lane_offset = offset
	speed_jitter = jitter
	target_gap = start_gap
	_caught = false
	_lane_stick_timer = 0.0
	if player:
		var lane_val: Variant = player.get("current_lane")
		_last_player_lane = int(lane_val) if lane_val != null else 1
		global_position = Vector3(
			_target_x(),
			1.1,
			player.global_position.z + start_gap
		)


func on_spawned() -> void:
	_caught = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if has_node("Trail"):
		($Trail as GPUParticles3D).emitting = true


func on_recycled() -> void:
	_caught = false
	player = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if has_node("Trail"):
		($Trail as GPUParticles3D).emitting = false


func get_gap() -> float:
	if player == null or not is_instance_valid(player):
		return 999.0
	return global_position.z - player.global_position.z


func _physics_process(delta: float) -> void:
	if _caught or player == null or not is_instance_valid(player):
		return
	if not GameManager.is_playing():
		return
	if not bool(player.get("is_alive")):
		return

	_update_lane_stick(delta)
	_chase(delta)


func _update_lane_stick(delta: float) -> void:
	var lane_val: Variant = player.get("current_lane")
	var lane := int(lane_val) if lane_val != null else 1
	if lane == _last_player_lane:
		_lane_stick_timer += delta
	else:
		_lane_stick_timer = 0.0
		_last_player_lane = lane


func _chase(delta: float) -> void:
	var run_speed: float = float(player.get("run_speed"))
	var ghost_protected := player.has_method("is_ghost_form") and player.call("is_ghost_form")

	## Close-in rate: faster if the player camps one lane.
	var shrink := 0.55
	if _lane_stick_timer > 2.0:
		shrink = 1.35
	elif _lane_stick_timer > 1.0:
		shrink = 0.9

	if ghost_protected:
		## Drift back — Ghost Form phases through enemies / no catch.
		target_gap = maxf(target_gap, SAFE_GAP)
		target_gap = move_toward(target_gap, SAFE_GAP + 2.0, delta * 4.0)
	else:
		target_gap = move_toward(target_gap, CATCH_DISTANCE + 0.8, delta * shrink)

	var gap := get_gap()

	## Choose speed relative to the player so we approach target_gap, never overtake.
	var speed := run_speed
	if gap > target_gap + 0.4:
		speed = run_speed * speed_jitter
	elif gap < target_gap - 0.4:
		speed = run_speed * 0.88
	else:
		speed = run_speed * randf_range(0.98, 1.02)

	## Advance toward -Z (same convention as the player).
	global_position.z -= speed * delta

	## Re-clamp: never go ahead of the player.
	gap = get_gap()
	if gap < MIN_BEHIND:
		global_position.z = player.global_position.z + MIN_BEHIND
		gap = MIN_BEHIND

	## Smoothly match player X with a pack offset.
	var tx := _target_x()
	global_position.x = lerpf(global_position.x, tx, clampf(6.0 * delta, 0.0, 1.0))
	global_position.y = 1.1 + sin(Time.get_ticks_msec() * 0.004 + lane_offset) * 0.12

	if gap <= ALMOST_DISTANCE:
		almost_close.emit(gap)

	if not ghost_protected and gap <= CATCH_DISTANCE:
		_catch()


func _target_x() -> float:
	var px := player.global_position.x
	return px + lane_offset


func _catch() -> void:
	if _caught:
		return
	## Final Ghost Form gate (race with expiry).
	if player and player.has_method("is_ghost_form") and player.call("is_ghost_form"):
		target_gap = SAFE_GAP
		global_position.z = player.global_position.z + SAFE_GAP
		return
	_caught = true
	caught_player.emit()
	if player and player.has_method("die"):
		## die() also no-ops while ghost — double safe.
		player.call("die")
	else:
		GameManager.trigger_game_over()
	print("[ChaserGhost] Caught the player (gap closed)")
