extends Node3D
## Elevated “train” platform — walkable StaticBody top + optional ramp.
## Front Area3D kills if you smash into the face without jumping / ramping up.

const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]
const PLATFORM_HEIGHT: float = 1.35
const DEFAULT_LENGTH: float = 16.0
const DEFAULT_WIDTH_ONE: float = 2.4
const DEFAULT_WIDTH_TWO: float = 5.2

var pool_id: String = ""
var lane_index: int = 1
var local_z: float = 0.0
var width_lanes: int = 1
var has_ramp: bool = false
var length_z: float = DEFAULT_LENGTH

var _dodge_counted: bool = false
var _shapes_unique: bool = false

@onready var floor_body: StaticBody3D = $FloorBody
@onready var floor_shape: CollisionShape3D = $FloorBody/CollisionShape3D
@onready var floor_mesh: MeshInstance3D = $FloorBody/Mesh
@onready var ramp_body: StaticBody3D = $RampBody
@onready var ramp_shape: CollisionShape3D = $RampBody/CollisionShape3D
@onready var ramp_mesh: MeshInstance3D = $RampBody/Mesh
@onready var front_hazard: Area3D = $FrontHazard
@onready var front_shape: CollisionShape3D = $FrontHazard/CollisionShape3D


func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("platform")
	if floor_body:
		floor_body.collision_layer = 1
		floor_body.collision_mask = 0
	if ramp_body:
		ramp_body.collision_layer = 1
		ramp_body.collision_mask = 0
	if front_hazard:
		front_hazard.collision_layer = 4
		front_hazard.collision_mask = 2
		front_hazard.monitoring = true
		if not front_hazard.body_entered.is_connected(_on_front_entered):
			front_hazard.body_entered.connect(_on_front_entered)
	set_physics_process(false)


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	lane_index = clampi(lane, 0, LANE_POSITIONS.size() - 1)
	local_z = z_offset
	width_lanes = clampi(int(extras.get("width", 1)), 1, 2)
	## Clamp so width fits on the track.
	if lane_index + width_lanes - 1 > 2:
		lane_index = 3 - width_lanes
	has_ramp = bool(extras.get("ramp", false))
	length_z = clampf(float(extras.get("length", DEFAULT_LENGTH)), 10.0, 22.0)
	var x0: float = LANE_POSITIONS[lane_index]
	var x1: float = LANE_POSITIONS[lane_index + width_lanes - 1]
	position = Vector3((x0 + x1) * 0.5, 0.0, local_z)
	rotation = Vector3.ZERO
	_apply_dimensions()


func _ensure_unique_shapes() -> void:
	if _shapes_unique:
		return
	if floor_shape and floor_shape.shape:
		floor_shape.shape = floor_shape.shape.duplicate()
	if floor_mesh and floor_mesh.mesh:
		floor_mesh.mesh = floor_mesh.mesh.duplicate()
	if ramp_shape and ramp_shape.shape:
		ramp_shape.shape = ramp_shape.shape.duplicate()
	if ramp_mesh and ramp_mesh.mesh:
		ramp_mesh.mesh = ramp_mesh.mesh.duplicate()
	if front_shape and front_shape.shape:
		front_shape.shape = front_shape.shape.duplicate()
	_shapes_unique = true


func _apply_dimensions() -> void:
	_ensure_unique_shapes()
	var width_x: float = DEFAULT_WIDTH_ONE if width_lanes == 1 else DEFAULT_WIDTH_TWO
	var thick: float = 0.35
	## Floor top at PLATFORM_HEIGHT.
	if floor_shape and floor_shape.shape is BoxShape3D:
		var box: BoxShape3D = floor_shape.shape as BoxShape3D
		box.size = Vector3(width_x, thick, length_z)
	if floor_shape:
		floor_shape.position = Vector3(0.0, PLATFORM_HEIGHT - thick * 0.5, 0.0)
	if floor_mesh and floor_mesh.mesh is BoxMesh:
		var bm: BoxMesh = floor_mesh.mesh as BoxMesh
		bm.size = Vector3(width_x, thick, length_z)
	if floor_mesh:
		floor_mesh.position = Vector3(0.0, PLATFORM_HEIGHT - thick * 0.5, 0.0)

	## Front face at +Z (player approaches from +Z toward -Z).
	var front_z: float = length_z * 0.5
	if front_shape and front_shape.shape is BoxShape3D:
		var fbox: BoxShape3D = front_shape.shape as BoxShape3D
		fbox.size = Vector3(width_x * 0.95, PLATFORM_HEIGHT * 0.9, 0.45)
	if front_shape:
		front_shape.position = Vector3(0.0, PLATFORM_HEIGHT * 0.45, front_z + 0.15)

	## Ramp from ground up to platform on the approach side (+Z).
	if ramp_body:
		ramp_body.visible = has_ramp
		ramp_body.process_mode = Node.PROCESS_MODE_INHERIT if has_ramp else Node.PROCESS_MODE_DISABLED
		for c in ramp_body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = not has_ramp
	if has_ramp and ramp_shape:
		var ramp_len: float = 5.5
		var ramp_angle: float = atan2(PLATFORM_HEIGHT, ramp_len)
		if ramp_shape.shape is BoxShape3D:
			var rbox: BoxShape3D = ramp_shape.shape as BoxShape3D
			rbox.size = Vector3(width_x * 0.92, 0.28, ramp_len)
		## Center of ramp sits ahead of platform front, pitched.
		ramp_body.position = Vector3(0.0, PLATFORM_HEIGHT * 0.5, front_z + ramp_len * 0.5)
		ramp_body.rotation = Vector3(-ramp_angle, 0.0, 0.0)
		if ramp_mesh and ramp_mesh.mesh is BoxMesh:
			(ramp_mesh.mesh as BoxMesh).size = Vector3(width_x * 0.92, 0.28, ramp_len)


func on_spawned() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_dodge_counted = false
	_apply_dimensions()
	if front_hazard:
		front_hazard.set_deferred("monitoring", true)
	set_physics_process(true)


func on_recycled() -> void:
	_try_count_dodge()
	set_physics_process(false)
	if front_hazard:
		front_hazard.monitoring = false
	visible = false
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	has_ramp = false
	width_lanes = 1
	_dodge_counted = false


func _physics_process(_delta: float) -> void:
	_try_count_dodge()


func _on_front_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	if not body.is_in_group("player") and not body.has_method("die"):
		return
	if not GameManager.is_playing():
		return
	if body.has_method("is_ghost_form") and body.call("is_ghost_form"):
		return
	if bool(body.get("is_escaping")):
		return
	## Already on / above platform — ignore.
	if body.global_position.y >= PLATFORM_HEIGHT - 0.15:
		return
	## Mid-jump clearing the face.
	if body.global_position.y > PLATFORM_HEIGHT * 0.55 and body is CharacterBody3D:
		var cb: CharacterBody3D = body as CharacterBody3D
		if not cb.is_on_floor() and cb.velocity.y > -1.0:
			return
	if body.has_method("die"):
		body.call("die")


func _try_count_dodge() -> void:
	if _dodge_counted:
		return
	if not GameManager or not GameManager.is_playing():
		return
	var player: Node = GameManager.player
	if player == null or not is_instance_valid(player) or not (player is Node3D):
		return
	if player.get("is_alive") != null and not bool(player.get("is_alive")):
		return
	## Count dodge once player clears the rear of the platform.
	var rear_z: float = global_position.z - length_z * 0.5
	if (player as Node3D).global_position.z >= rear_z - 1.0:
		return
	_dodge_counted = true
	if MissionManager:
		MissionManager.report_dodge()


## Lanes this platform occupies (for LevelGenerator fairness).
func occupied_lanes() -> Array[int]:
	var out: Array[int] = []
	for i in width_lanes:
		out.append(lane_index + i)
	return out
