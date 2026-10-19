extends CharacterBody3D
## PlayerController — Subway Surfers–style 3-lane runner for GraveDash.
## Forward axis: negative Z (player runs toward -Z). Lanes along X.
## Desktop: A/D or arrows = lanes, Space = jump, Ctrl/S = slide.
## Mobile: swipe_* input actions (wire TouchScreenSwipe later).

signal died
signal powerup_collected(powerup_id: String)
## Emitted when Ghost Form starts/stops or ticks (remaining seconds).
signal ghost_form_changed(active: bool, remaining: float)

# --- Lane layout -------------------------------------------------------------
const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]
const LANE_SWITCH_DURATION: float = 0.20

# --- Speed ramp --------------------------------------------------------------
const START_SPEED: float = 13.0
const MAX_SPEED: float = 30.0
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
const STANDING_SHAPE_Y: float = 0.9
const SLIDE_SHAPE_Y: float = 0.45

# --- Collision masks ---------------------------------------------------------
## Layer bits: 1 = world, 2 = player, 4 = hazards (layer 3).
const MASK_NORMAL: int = 5   ## world + hazards
const MASK_GHOST: int = 1    ## world only — phase through hazard bodies
const LAYER_PLAYER: int = 2

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var run_particles: GPUParticles3D = $RunParticles
@onready var ghost_trail: GPUParticles3D = $GhostTrail
@onready var ghost_light: OmniLight3D = $GhostLight

var current_lane: int = 1
var target_lane: int = 1
var _lane_tween: Tween = null

var run_speed: float = START_SPEED
var is_sliding: bool = false
var _slide_timer: float = 0.0
var is_alive: bool = true

## Power-up state.
var has_shield: bool = false
var has_magnet: bool = false
var is_ghost: bool = false
var ghost_time_remaining: float = 0.0
var _powerup_timers: Dictionary = {}

var _capsule_shape: CapsuleShape3D
var _capsule_mesh: CapsuleMesh
var _body_material: StandardMaterial3D
var _normal_albedo: Color = Color(0.55, 0.72, 0.45, 1.0)
var _hud_tick_accum: float = 0.0


func _ready() -> void:
	add_to_group("player")
	GameManager.player = self
	is_alive = true
	_capsule_shape = collision_shape.shape as CapsuleShape3D
	if mesh_instance.mesh is CapsuleMesh:
		_capsule_mesh = mesh_instance.mesh as CapsuleMesh
	_setup_materials()
	_apply_standing_hitbox()
	_end_ghost_form(false)
	global_position.x = LANE_POSITIONS[current_lane]
	if not GameManager.is_playing():
		GameManager.start_game()


func _setup_materials() -> void:
	## Unique material so ghost transparency doesn't mutate a shared resource.
	var existing := mesh_instance.get_surface_override_material(0)
	if existing is StandardMaterial3D:
		_body_material = (existing as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		_body_material = StandardMaterial3D.new()
		_body_material.albedo_color = _normal_albedo
		_body_material.roughness = 0.7
	_normal_albedo = _body_material.albedo_color
	mesh_instance.set_surface_override_material(0, _body_material)


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
	_tick_ghost_form(delta)


# --- Input -------------------------------------------------------------------

func _handle_lane_input() -> void:
	if Input.is_action_just_pressed("swipe_left"):
		_change_lane(-1)
	elif Input.is_action_just_pressed("swipe_right"):
		_change_lane(1)


func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("swipe_up") and is_on_floor() and not is_sliding:
		velocity.y = JUMP_VELOCITY
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

func _update_speed(_delta: float) -> void:
	var t: float = GameManager.run_time
	run_speed = clampf(START_SPEED + t * SPEED_RAMP_PER_SECOND, START_SPEED, MAX_SPEED)


func _apply_forward_and_gravity(delta: float) -> void:
	velocity.z = -run_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _report_distance(delta: float) -> void:
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
	mesh_instance.rotation_degrees.x = 70.0


# --- Collisions / death ------------------------------------------------------

func _check_hazard_collisions() -> void:
	if is_ghost:
		return
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
	if is_ghost:
		return
	if has_shield:
		has_shield = false
		_powerup_timers.erase("shield")
		print("[Player] Shield absorbed hit")
		return
	die()


func die() -> void:
	if not is_alive:
		return
	if is_ghost:
		## Ghost Form still active — hazards cannot kill.
		return
	is_alive = false
	velocity = Vector3.ZERO
	_end_ghost_form(false)
	died.emit()
	GameManager.trigger_game_over()
	print("[Player] Game Over — score=%d distance=%.1f" % [ScoreManager.score, ScoreManager.distance])


# --- Ghost Form --------------------------------------------------------------

func is_ghost_form() -> bool:
	return is_ghost


func apply_ghost_form(duration: float = 9.0) -> void:
	## Refresh / extend if already active.
	var was_active := is_ghost
	is_ghost = true
	ghost_time_remaining = maxf(ghost_time_remaining, duration)
	_powerup_timers["ghost_form"] = ghost_time_remaining
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_GHOST
	_apply_ghost_visuals(true)
	powerup_collected.emit("ghost_form")
	ghost_form_changed.emit(true, ghost_time_remaining)
	if not was_active:
		print("[Player] Ghost Form ON (%.1fs)" % ghost_time_remaining)


func _tick_ghost_form(delta: float) -> void:
	if not is_ghost:
		return
	ghost_time_remaining = maxf(0.0, ghost_time_remaining - delta)
	_powerup_timers["ghost_form"] = ghost_time_remaining
	_hud_tick_accum += delta
	## HUD update ~10 Hz to avoid spam.
	if _hud_tick_accum >= 0.1:
		_hud_tick_accum = 0.0
		ghost_form_changed.emit(true, ghost_time_remaining)
	if ghost_time_remaining <= 0.0:
		_end_ghost_form(true)


func _end_ghost_form(emit_signal: bool = true) -> void:
	is_ghost = false
	ghost_time_remaining = 0.0
	_powerup_timers.erase("ghost_form")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_NORMAL
	_apply_ghost_visuals(false)
	_hud_tick_accum = 0.0
	if emit_signal:
		ghost_form_changed.emit(false, 0.0)
		print("[Player] Ghost Form OFF")


func _apply_ghost_visuals(active: bool) -> void:
	if _body_material:
		if active:
			_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_body_material.albedo_color = Color(0.55, 0.35, 0.85, 0.42)
			_body_material.emission_enabled = true
			_body_material.emission = Color(0.45, 0.2, 0.75)
			_body_material.emission_energy_multiplier = 1.8
		else:
			_body_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_body_material.albedo_color = _normal_albedo
			_body_material.emission_enabled = false
			_body_material.emission_energy_multiplier = 1.0
	if ghost_trail:
		ghost_trail.emitting = active
	if ghost_light:
		ghost_light.visible = active
		ghost_light.light_energy = 2.2 if active else 0.0


# --- Other power-ups ---------------------------------------------------------

func apply_powerup(powerup_id: String, duration: float = 5.0) -> void:
	match powerup_id:
		"ghost_form":
			apply_ghost_form(duration)
			return
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
		if id == "ghost_form":
			continue  ## Handled by _tick_ghost_form.
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
