extends CharacterBody3D
## PlayerController — Subway Surfers–style 3-lane runner for GraveDash.
## Forward axis: negative Z (player runs toward -Z). Lanes along X.
## Desktop: A/D or arrows = lanes, Space = jump, Ctrl/S = slide.
## Mobile: swipe_* input actions (wire TouchScreenSwipe later).

## Emitted when the player hits a lethal obstacle / hazard.
signal died
## Emitted when a power-up is collected (stub hook).
signal powerup_collected(powerup_id: String)

# --- Lane layout -------------------------------------------------------------
const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]
const LANE_SWITCH_DURATION: float = 0.20  ## seconds for smooth X tween

# --- Speed ramp --------------------------------------------------------------
const START_SPEED: float = 13.0
const MAX_SPEED: float = 30.0
## Units/sec gained per second of run time (caps at MAX_SPEED).
const SPEED_RAMP_PER_SECOND: float = 0.35

# --- Jump / gravity ----------------------------------------------------------
const JUMP_VELOCITY: float = 9.5
const GRAVITY: float = 28.0

# --- Slide / crouch ----------------------------------------------------------
const SLIDE_DURATION: float = 0.75
const STANDING_CAPSULE_HEIGHT: float = 1.8
const STANDING_CAPSULE_RADIUS: float = 0.4
const SLIDE_CAPSULE_HEIGHT: float = 0.9
const SLIDE_CAPSULE_RADIUS: float = 0.4
## Y offset of CollisionShape3D center while standing / sliding.
const STANDING_SHAPE_Y: float = 0.9
const SLIDE_SHAPE_Y: float = 0.45

# --- Collision layers (document for later obstacle setup) --------------------
## Player collision_layer = 2, mask = 1|4 (world + hazards) — configured in .tscn.

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var run_particles: GPUParticles3D = $RunParticles

var current_lane: int = 1  ## center lane
var target_lane: int = 1
var _lane_tween: Tween = null

var run_speed: float = START_SPEED
var is_sliding: bool = false
var _slide_timer: float = 0.0
var is_alive: bool = true

## Power-up stub flags (magnet, shield, etc. — filled in later slices).
var has_shield: bool = false
var has_magnet: bool = false
var _powerup_timers: Dictionary = {}

## Capsule shape resource (shared reference; we mutate height at runtime).
var _capsule_shape: CapsuleShape3D
var _capsule_mesh: CapsuleMesh


func _ready() -> void:
	GameManager.player = self
	_capsule_shape = collision_shape.shape as CapsuleShape3D
	if mesh_instance.mesh is CapsuleMesh:
		_capsule_mesh = mesh_instance.mesh as CapsuleMesh
	_apply_standing_hitbox()
	# Ensure we start centered.
	global_position.x = LANE_POSITIONS[current_lane]
	if not GameManager.is_playing():
		GameManager.start_game()


func _physics_process(delta: float) -> void:
	if not is_alive or not GameManager.is_playing():
		return

	_handle_lane_input()
	_handle_jump_input()
	_handle_slide_input(delta)
	_update_speed(delta)
	_apply_forward_and_gravity(delta)
	move_and_slide()
	_report_distance(delta)
	_check_hazard_collisions()
	_tick_powerups(delta)


# --- Input -------------------------------------------------------------------

func _handle_lane_input() -> void:
	if is_sliding:
		## Allow lane changes while sliding (common endless-runner feel).
		pass
	if Input.is_action_just_pressed("swipe_left"):
		_change_lane(-1)
	elif Input.is_action_just_pressed("swipe_right"):
		_change_lane(1)


func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("swipe_up") and is_on_floor() and not is_sliding:
		velocity.y = JUMP_VELOCITY
		## Cancel slide if somehow overlapping.
		if is_sliding:
			_end_slide()


func _handle_slide_input(delta: float) -> void:
	if Input.is_action_just_pressed("swipe_down") and is_on_floor() and not is_sliding:
		_start_slide()

	if is_sliding:
		_slide_timer -= delta
		if _slide_timer <= 0.0 or not is_on_floor():
			_end_slide()


func _change_lane(direction: int) -> void:
	var next := clampi(target_lane + direction, 0, LANE_POSITIONS.size() - 1)
	if next == target_lane:
		return
	target_lane = next
	current_lane = next
	_tween_to_lane(LANE_POSITIONS[target_lane])


func _tween_to_lane(target_x: float) -> void:
	if _lane_tween and _lane_tween.is_valid():
		_lane_tween.kill()
	_lane_tween = create_tween()
	_lane_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lane_tween.tween_property(self, "global_position:x", target_x, LANE_SWITCH_DURATION)


# --- Movement ----------------------------------------------------------------

func _update_speed(delta: float) -> void:
	## Ramp by run time (GameManager) so pause doesn't advance speed.
	var t: float = GameManager.run_time
	run_speed = clampf(START_SPEED + t * SPEED_RAMP_PER_SECOND, START_SPEED, MAX_SPEED)


func _apply_forward_and_gravity(delta: float) -> void:
	## Auto-run toward -Z.
	velocity.z = -run_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _report_distance(delta: float) -> void:
	## Distance ≈ speed * time along forward axis.
	ScoreManager.add_distance(run_speed * delta)


# --- Slide hitbox ------------------------------------------------------------

func _start_slide() -> void:
	is_sliding = true
	_slide_timer = SLIDE_DURATION
	_apply_slide_hitbox()
	if run_particles:
		run_particles.emitting = true


func _end_slide() -> void:
	is_sliding = false
	_slide_timer = 0.0
	_apply_standing_hitbox()


func _apply_standing_hitbox() -> void:
	if _capsule_shape:
		_capsule_shape.height = STANDING_CAPSULE_HEIGHT
		_capsule_shape.radius = STANDING_CAPSULE_RADIUS
	if _capsule_mesh:
		_capsule_mesh.height = STANDING_CAPSULE_HEIGHT
		_capsule_mesh.radius = STANDING_CAPSULE_RADIUS
	collision_shape.position.y = STANDING_SHAPE_Y
	mesh_instance.position.y = STANDING_SHAPE_Y
	mesh_instance.rotation_degrees.x = 0.0


func _apply_slide_hitbox() -> void:
	if _capsule_shape:
		_capsule_shape.height = SLIDE_CAPSULE_HEIGHT
		_capsule_shape.radius = SLIDE_CAPSULE_RADIUS
	if _capsule_mesh:
		_capsule_mesh.height = SLIDE_CAPSULE_HEIGHT
		_capsule_mesh.radius = SLIDE_CAPSULE_RADIUS
	collision_shape.position.y = SLIDE_SHAPE_Y
	mesh_instance.position.y = SLIDE_SHAPE_Y
	## Tilt capsule visually to read as a slide.
	mesh_instance.rotation_degrees.x = 70.0


# --- Collisions / death ------------------------------------------------------

func _check_hazard_collisions() -> void:
	## Hook for Game Over: any slide collision with a body in the hazards group.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		if collider.is_in_group("hazard") or collider.is_in_group("obstacle"):
			_on_hit_hazard(collider)
			return
		if collider.is_in_group("powerup"):
			_on_collect_powerup(collider)


func _on_hit_hazard(_hazard: Object) -> void:
	if has_shield:
		## Stub: consume shield instead of dying.
		has_shield = false
		_powerup_timers.erase("shield")
		print("[Player] Shield absorbed hit")
		return
	die()


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector3.ZERO
	died.emit()
	GameManager.trigger_game_over()
	print("[Player] Game Over — score=%d distance=%.1f" % [ScoreManager.score, ScoreManager.distance])


# --- Power-up stubs ----------------------------------------------------------

func apply_powerup(powerup_id: String, duration: float = 5.0) -> void:
	match powerup_id:
		"shield":
			has_shield = true
		"magnet":
			has_magnet = true
		_:
			pass
	_powerup_timers[powerup_id] = duration
	powerup_collected.emit(powerup_id)


func _on_collect_powerup(node: Object) -> void:
	var id := "unknown"
	if node is Node and (node as Node).has_meta("powerup_id"):
		id = str((node as Node).get_meta("powerup_id"))
	apply_powerup(id)
	if node is Node:
		(node as Node).queue_free()


func _tick_powerups(delta: float) -> void:
	var expired: Array[String] = []
	for id in _powerup_timers.keys():
		_powerup_timers[id] = float(_powerup_timers[id]) - delta
		if _powerup_timers[id] <= 0.0:
			expired.append(id)
	for id in expired:
		_powerup_timers.erase(id)
		match id:
			"shield":
				has_shield = false
			"magnet":
				has_magnet = false
