extends CharacterBody3D
## PlayerController — Subway Surfers–style 3-lane runner for GraveDash.
## Forward axis: negative Z (player runs toward -Z). Lanes along X.
## Desktop: A/D or arrows = lanes, Space = jump, Ctrl/S = slide.
## Mobile: swipe_* input actions (wire TouchScreenSwipe later).

signal died
signal powerup_collected(powerup_id: String)
## Timed / stock power-up HUD: id, active, remaining seconds (0 for stock).
signal powerup_changed(powerup_id: String, active: bool, remaining: float)
## Emitted when Ghost Form starts/stops or ticks (remaining seconds).
signal ghost_form_changed(active: bool, remaining: float)
signal second_chance_changed(has_charge: bool)

# --- Lane layout -------------------------------------------------------------
const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]
const LANE_SWITCH_DURATION: float = 0.20
const CURSED_LANE_DURATION: float = 0.48

# --- Speed ramp --------------------------------------------------------------
const START_SPEED: float = 13.0
const MAX_SPEED: float = 30.0
const SPEED_RAMP_PER_SECOND: float = 0.35
const CURSED_SPEED_MULT: float = 1.48

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

# --- Power-up defaults -------------------------------------------------------
const GHOST_DURATION_DEFAULT: float = 9.0
const MAGNET_DURATION_DEFAULT: float = 11.0
const HOLY_DURATION_DEFAULT: float = 7.0
const CURSED_DURATION_DEFAULT: float = 6.0
const HOLY_RADIUS: float = 6.5
const HOLY_PULSE_INTERVAL: float = 0.12
const SECOND_CHANCE_HOVER_TIME: float = 1.35
const SECOND_CHANCE_HOVER_HEIGHT: float = 2.4

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var run_particles: GPUParticles3D = $RunParticles
@onready var ghost_trail: GPUParticles3D = $GhostTrail
@onready var ghost_light: OmniLight3D = $GhostLight
@onready var magnet_light: OmniLight3D = get_node_or_null("MagnetLight")
@onready var holy_light: OmniLight3D = get_node_or_null("HolyLight")
@onready var holy_aura: MeshInstance3D = get_node_or_null("HolyAura")
@onready var holy_particles: GPUParticles3D = get_node_or_null("HolyParticles")
@onready var cursed_light: OmniLight3D = get_node_or_null("CursedLight")
@onready var cursed_trail: GPUParticles3D = get_node_or_null("CursedTrail")
@onready var chance_light: OmniLight3D = get_node_or_null("ChanceLight")
@onready var chance_particles: GPUParticles3D = get_node_or_null("ChanceParticles")

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
var has_holy_light: bool = false
var has_cursed_speed: bool = false
var has_second_chance: bool = false
var is_ghost: bool = false
var is_escaping: bool = false
var ghost_time_remaining: float = 0.0
var magnet_time_remaining: float = 0.0
var holy_time_remaining: float = 0.0
var cursed_time_remaining: float = 0.0
var _escape_timer: float = 0.0
var _holy_pulse_accum: float = 0.0
var _powerup_timers: Dictionary = {}
var _hud_tick_accum: float = 0.0

var _capsule_shape: CapsuleShape3D
var _capsule_mesh: CapsuleMesh
var _body_material: StandardMaterial3D
var _normal_albedo: Color = Color(0.55, 0.72, 0.45, 1.0)
var _holy_aura_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
	GameManager.player = self
	is_alive = true
	_capsule_shape = collision_shape.shape as CapsuleShape3D
	if mesh_instance.mesh is CapsuleMesh:
		_capsule_mesh = mesh_instance.mesh as CapsuleMesh
	_setup_materials()
	_apply_standing_hitbox()
	_clear_all_powerups(false)
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
	if holy_aura:
		var am := holy_aura.get_surface_override_material(0)
		if am is StandardMaterial3D:
			_holy_aura_mat = (am as StandardMaterial3D).duplicate() as StandardMaterial3D
			holy_aura.set_surface_override_material(0, _holy_aura_mat)


func _physics_process(delta: float) -> void:
	if not is_alive or not GameManager.is_playing():
		return

	if is_escaping:
		_tick_second_chance_escape(delta)
		move_and_slide()
		_report_distance(delta)
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
	_tick_holy_light(delta)
	_refresh_powerup_hud(delta)


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
	var duration := CURSED_LANE_DURATION if has_cursed_speed else LANE_SWITCH_DURATION
	if has_cursed_speed:
		## Sluggish + slight overshoot — harder to land clean lanes.
		_lane_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var overshoot := target_x + signf(target_x - global_position.x) * 0.35
		_lane_tween.tween_property(self, "global_position:x", overshoot, duration * 0.65)
		_lane_tween.tween_property(self, "global_position:x", target_x, duration * 0.35)
	else:
		_lane_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_lane_tween.tween_property(self, "global_position:x", target_x, duration)


# --- Movement ----------------------------------------------------------------

func _update_speed(_delta: float) -> void:
	var t: float = GameManager.run_time
	var base := clampf(START_SPEED + t * SPEED_RAMP_PER_SECOND, START_SPEED, MAX_SPEED)
	if has_cursed_speed:
		run_speed = minf(base * CURSED_SPEED_MULT, MAX_SPEED * 1.35)
	else:
		run_speed = base


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
	if is_ghost or is_escaping:
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
	if is_ghost or is_escaping:
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
	if is_ghost or is_escaping:
		## Ghost Form / mid-escape — cannot die.
		return
	if has_second_chance:
		_trigger_second_chance()
		return
	is_alive = false
	velocity = Vector3.ZERO
	_clear_all_powerups(false)
	died.emit()
	GameManager.trigger_game_over()
	print("[Player] Game Over — score=%d distance=%.1f" % [ScoreManager.score, ScoreManager.distance])


# --- Ghost Form --------------------------------------------------------------

func is_ghost_form() -> bool:
	return is_ghost


func apply_ghost_form(duration: float = GHOST_DURATION_DEFAULT) -> void:
	var was_active := is_ghost
	is_ghost = true
	ghost_time_remaining = maxf(ghost_time_remaining, duration)
	_powerup_timers["ghost_form"] = ghost_time_remaining
	_refresh_collision_mask()
	_apply_ghost_visuals(true)
	powerup_collected.emit("ghost_form")
	ghost_form_changed.emit(true, ghost_time_remaining)
	powerup_changed.emit("ghost_form", true, ghost_time_remaining)
	if not was_active:
		print("[Player] Ghost Form ON (%.1fs)" % ghost_time_remaining)


func _tick_ghost_form(delta: float) -> void:
	if not is_ghost:
		return
	ghost_time_remaining = maxf(0.0, ghost_time_remaining - delta)
	_powerup_timers["ghost_form"] = ghost_time_remaining
	if ghost_time_remaining <= 0.0:
		_end_ghost_form(true)


func _end_ghost_form(emit_signal: bool = true) -> void:
	is_ghost = false
	ghost_time_remaining = 0.0
	_powerup_timers.erase("ghost_form")
	_refresh_collision_mask()
	_apply_ghost_visuals(false)
	_reapply_body_tint()
	if emit_signal:
		ghost_form_changed.emit(false, 0.0)
		powerup_changed.emit("ghost_form", false, 0.0)
		print("[Player] Ghost Form OFF")


func _apply_ghost_visuals(active: bool) -> void:
	if ghost_trail:
		ghost_trail.emitting = active
	if ghost_light:
		ghost_light.visible = active
		ghost_light.light_energy = 2.2 if active else 0.0
	if active and _body_material:
		_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_material.albedo_color = Color(0.55, 0.35, 0.85, 0.42)
		_body_material.emission_enabled = true
		_body_material.emission = Color(0.45, 0.2, 0.75)
		_body_material.emission_energy_multiplier = 1.8


# --- Soul Magnet -------------------------------------------------------------

func apply_soul_magnet(duration: float = MAGNET_DURATION_DEFAULT) -> void:
	has_magnet = true
	magnet_time_remaining = maxf(magnet_time_remaining, duration)
	_powerup_timers["soul_magnet"] = magnet_time_remaining
	_apply_magnet_visuals(true)
	powerup_collected.emit("soul_magnet")
	powerup_changed.emit("soul_magnet", true, magnet_time_remaining)
	print("[Player] Soul Magnet ON (%.1fs)" % magnet_time_remaining)


func _end_soul_magnet() -> void:
	has_magnet = false
	magnet_time_remaining = 0.0
	_powerup_timers.erase("soul_magnet")
	_apply_magnet_visuals(false)
	powerup_changed.emit("soul_magnet", false, 0.0)


func _apply_magnet_visuals(active: bool) -> void:
	if magnet_light:
		magnet_light.visible = active
		magnet_light.light_energy = 2.0 if active else 0.0


# --- Holy Light --------------------------------------------------------------

func apply_holy_light(duration: float = HOLY_DURATION_DEFAULT) -> void:
	has_holy_light = true
	holy_time_remaining = maxf(holy_time_remaining, duration)
	_powerup_timers["holy_light"] = holy_time_remaining
	_holy_pulse_accum = 0.0
	_apply_holy_visuals(true)
	powerup_collected.emit("holy_light")
	powerup_changed.emit("holy_light", true, holy_time_remaining)
	_holy_light_blast()
	print("[Player] Holy Light ON (%.1fs)" % holy_time_remaining)


func _tick_holy_light(delta: float) -> void:
	if not has_holy_light:
		return
	_holy_pulse_accum += delta
	if _holy_pulse_accum >= HOLY_PULSE_INTERVAL:
		_holy_pulse_accum = 0.0
		_holy_light_blast()
	if holy_aura:
		var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.008))
		holy_aura.scale = Vector3.ONE * (HOLY_RADIUS / 3.5) * (0.85 + 0.15 * pulse)
		if _holy_aura_mat:
			_holy_aura_mat.albedo_color.a = 0.12 + 0.1 * pulse


func _end_holy_light() -> void:
	has_holy_light = false
	holy_time_remaining = 0.0
	_powerup_timers.erase("holy_light")
	_apply_holy_visuals(false)
	powerup_changed.emit("holy_light", false, 0.0)


func _apply_holy_visuals(active: bool) -> void:
	if holy_light:
		holy_light.visible = active
		holy_light.light_energy = 4.5 if active else 0.0
		holy_light.omni_range = HOLY_RADIUS + 1.0
	if holy_aura:
		holy_aura.visible = active
	if holy_particles:
		holy_particles.emitting = active


func _holy_light_blast() -> void:
	var origin := global_position
	## Obstacles / hazards in radius → recycle via chunk pool.
	for node in get_tree().get_nodes_in_group("obstacle"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node3D):
			continue
		var obs := node as Node3D
		if origin.distance_to(obs.global_position) > HOLY_RADIUS:
			continue
		_recycle_world_node(obs)
	## Chasers: shove far behind (stay in pack, pressure reset).
	for node in get_tree().get_nodes_in_group("chaser"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node3D):
			continue
		var chaser := node as Node3D
		if origin.distance_to(chaser.global_position) > HOLY_RADIUS + 4.0:
			continue
		if chaser.has_method("banish_by_holy_light"):
			chaser.call("banish_by_holy_light", 28.0)


func _recycle_world_node(node: Node3D) -> void:
	var chunk := _find_chunk_ancestor(node)
	if chunk and chunk.has_method("notify_obstacle_destroyed"):
		chunk.call("notify_obstacle_destroyed", node)
		return
	var pool_id := str(node.get("pool_id")) if node.get("pool_id") != null else ""
	if node.has_method("on_recycled"):
		node.call("on_recycled")
	if pool_id != "" and ObjectPool.has_pool(pool_id):
		ObjectPool.release(pool_id, node)
	else:
		node.queue_free()


func _find_chunk_ancestor(node: Node) -> Node:
	var n: Node = node.get_parent() if node else null
	while n:
		if n.is_in_group("chunk"):
			return n
		n = n.get_parent()
	return null


# --- Second Chance -----------------------------------------------------------

func apply_second_chance() -> void:
	## One charge max — picking up again while charged is a no-op refresh.
	if has_second_chance:
		powerup_collected.emit("second_chance")
		second_chance_changed.emit(true)
		powerup_changed.emit("second_chance", true, 0.0)
		return
	has_second_chance = true
	_apply_chance_visuals(true)
	powerup_collected.emit("second_chance")
	second_chance_changed.emit(true)
	powerup_changed.emit("second_chance", true, 0.0)
	print("[Player] Second Chance charged")


func _trigger_second_chance() -> void:
	has_second_chance = false
	second_chance_changed.emit(false)
	powerup_changed.emit("second_chance", false, 0.0)
	is_escaping = true
	_escape_timer = SECOND_CHANCE_HOVER_TIME
	_refresh_collision_mask()
	velocity.y = 7.5
	if is_sliding:
		_end_slide()
	## Nudge toward lane center for a clean land.
	target_lane = current_lane
	_tween_to_lane(LANE_POSITIONS[current_lane])
	_apply_chance_visuals(true)
	if chance_particles:
		chance_particles.emitting = true
	print("[Player] Second Chance — hover escape!")


func _tick_second_chance_escape(delta: float) -> void:
	_escape_timer -= delta
	_update_speed(delta)
	velocity.z = -run_speed * 0.92
	## Hold near hover height, then settle.
	var target_y := SECOND_CHANCE_HOVER_HEIGHT if _escape_timer > 0.35 else 0.05
	global_position.y = move_toward(global_position.y, target_y, delta * 6.0)
	velocity.y = 0.0
	if _escape_timer <= 0.0:
		_end_second_chance_escape()


func _end_second_chance_escape() -> void:
	is_escaping = false
	_escape_timer = 0.0
	global_position.y = 0.05
	velocity.y = 0.0
	_refresh_collision_mask()
	_apply_chance_visuals(has_second_chance)
	if chance_particles:
		chance_particles.emitting = false
	print("[Player] Second Chance land — back on track")


func _apply_chance_visuals(active: bool) -> void:
	if chance_light:
		chance_light.visible = active or is_escaping
		chance_light.light_energy = 2.4 if (active or is_escaping) else 0.0


# --- Cursed Speed ------------------------------------------------------------

func apply_cursed_speed(duration: float = CURSED_DURATION_DEFAULT) -> void:
	has_cursed_speed = true
	cursed_time_remaining = maxf(cursed_time_remaining, duration)
	_powerup_timers["cursed_speed"] = cursed_time_remaining
	_apply_cursed_visuals(true)
	powerup_collected.emit("cursed_speed")
	powerup_changed.emit("cursed_speed", true, cursed_time_remaining)
	print("[Player] Cursed Speed ON (%.1fs)" % cursed_time_remaining)


func _end_cursed_speed() -> void:
	has_cursed_speed = false
	cursed_time_remaining = 0.0
	_powerup_timers.erase("cursed_speed")
	_apply_cursed_visuals(false)
	_reapply_body_tint()
	powerup_changed.emit("cursed_speed", false, 0.0)


func _apply_cursed_visuals(active: bool) -> void:
	if cursed_light:
		cursed_light.visible = active
		cursed_light.light_energy = 2.6 if active else 0.0
	if cursed_trail:
		cursed_trail.emitting = active
	if active and _body_material and not is_ghost:
		_body_material.emission_enabled = true
		_body_material.emission = Color(0.95, 0.25, 0.08)
		_body_material.emission_energy_multiplier = 2.2
		_body_material.albedo_color = Color(0.85, 0.4, 0.28, 1.0)


# --- Shared power-up API -----------------------------------------------------

func apply_powerup(powerup_id: String, duration: float = 5.0) -> void:
	match powerup_id:
		"ghost_form":
			apply_ghost_form(duration if duration > 0.0 else GHOST_DURATION_DEFAULT)
		"soul_magnet", "magnet":
			apply_soul_magnet(duration if duration > 0.0 else MAGNET_DURATION_DEFAULT)
		"holy_light":
			apply_holy_light(duration if duration > 0.0 else HOLY_DURATION_DEFAULT)
		"cursed_speed":
			apply_cursed_speed(duration if duration > 0.0 else CURSED_DURATION_DEFAULT)
		"second_chance":
			apply_second_chance()
		"shield":
			has_shield = true
			_powerup_timers["shield"] = duration
			powerup_collected.emit("shield")
		_:
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
	if has_magnet:
		magnet_time_remaining = maxf(0.0, magnet_time_remaining - delta)
		_powerup_timers["soul_magnet"] = magnet_time_remaining
		if magnet_time_remaining <= 0.0:
			_end_soul_magnet()
	if has_holy_light:
		holy_time_remaining = maxf(0.0, holy_time_remaining - delta)
		_powerup_timers["holy_light"] = holy_time_remaining
		if holy_time_remaining <= 0.0:
			_end_holy_light()
	if has_cursed_speed:
		cursed_time_remaining = maxf(0.0, cursed_time_remaining - delta)
		_powerup_timers["cursed_speed"] = cursed_time_remaining
		if cursed_time_remaining <= 0.0:
			_end_cursed_speed()
	## Legacy shield timer (no pickup yet).
	if has_shield and _powerup_timers.has("shield"):
		_powerup_timers["shield"] = float(_powerup_timers["shield"]) - delta
		if float(_powerup_timers["shield"]) <= 0.0:
			has_shield = false
			_powerup_timers.erase("shield")


func _refresh_powerup_hud(delta: float) -> void:
	_hud_tick_accum += delta
	if _hud_tick_accum < 0.1:
		return
	_hud_tick_accum = 0.0
	if is_ghost:
		ghost_form_changed.emit(true, ghost_time_remaining)
		powerup_changed.emit("ghost_form", true, ghost_time_remaining)
	if has_magnet:
		powerup_changed.emit("soul_magnet", true, magnet_time_remaining)
	if has_holy_light:
		powerup_changed.emit("holy_light", true, holy_time_remaining)
	if has_cursed_speed:
		powerup_changed.emit("cursed_speed", true, cursed_time_remaining)


func _refresh_collision_mask() -> void:
	collision_layer = LAYER_PLAYER
	if is_ghost or is_escaping:
		collision_mask = MASK_GHOST
	else:
		collision_mask = MASK_NORMAL


func _reapply_body_tint() -> void:
	if _body_material == null:
		return
	if is_ghost:
		_apply_ghost_visuals(true)
		return
	if has_cursed_speed:
		_apply_cursed_visuals(true)
		return
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_body_material.albedo_color = _normal_albedo
	_body_material.emission_enabled = false
	_body_material.emission_energy_multiplier = 1.0


func _clear_all_powerups(emit_signals: bool) -> void:
	is_ghost = false
	ghost_time_remaining = 0.0
	has_magnet = false
	magnet_time_remaining = 0.0
	has_holy_light = false
	holy_time_remaining = 0.0
	has_cursed_speed = false
	cursed_time_remaining = 0.0
	has_second_chance = false
	is_escaping = false
	_escape_timer = 0.0
	has_shield = false
	_powerup_timers.clear()
	_refresh_collision_mask()
	_apply_ghost_visuals(false)
	_apply_magnet_visuals(false)
	_apply_holy_visuals(false)
	_apply_cursed_visuals(false)
	_apply_chance_visuals(false)
	_reapply_body_tint()
	if emit_signals:
		ghost_form_changed.emit(false, 0.0)
		second_chance_changed.emit(false)
		for id in ["ghost_form", "soul_magnet", "holy_light", "cursed_speed", "second_chance"]:
			powerup_changed.emit(id, false, 0.0)
