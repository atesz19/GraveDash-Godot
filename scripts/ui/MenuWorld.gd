extends Node3D
## MenuWorld — live graveyard backdrop for the main menu (orbit camera + idle Witch).

const CHUNK_SCENE := "res://scenes/levels/Chunk_Graveyard_01.tscn"
const WITCH_SCENE := "res://scenes/player/WitchRunner.tscn"
const GRAVEYARD_ENV := "res://resources/biomes/graveyard_environment.tres"
const CHUNK_LENGTH: float = 45.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var track_root: Node3D = $Track
@onready var witch_slot: Node3D = $WitchSlot
@onready var moon: DirectionalLight3D = $MoonLight

var _witch: Node3D = null
var _orbit_t: float = 0.0
var _transitioning: bool = false
var _cam_base_pos: Vector3 = Vector3(0.0, 2.4, 7.5)
var _dolly_t: float = 0.0


func _ready() -> void:
	_ensure_environment()
	_spawn_track()
	_spawn_witch()
	if camera:
		camera.current = true
		_cam_base_pos = camera.position
	_play_witch("idle")


func _process(delta: float) -> void:
	_orbit_t += delta
	if camera_pivot == null:
		return
	if _transitioning:
		_dolly_t = minf(1.0, _dolly_t + delta * 0.85)
		var ease_t: float = _dolly_t * _dolly_t * (3.0 - 2.0 * _dolly_t)
		camera_pivot.rotation.y = lerpf(sin(_orbit_t * 0.22) * 0.28, 0.0, ease_t)
		camera_pivot.rotation.x = lerpf(-0.12 + sin(_orbit_t * 0.35) * 0.04, -0.08, ease_t)
		if camera:
			camera.position = _cam_base_pos.lerp(Vector3(0.0, 1.8, 4.2), ease_t)
		return
	## Gentle idle orbit / sway.
	camera_pivot.rotation.y = sin(_orbit_t * 0.22) * 0.28
	camera_pivot.rotation.x = -0.12 + sin(_orbit_t * 0.35) * 0.04
	if camera:
		camera.position = _cam_base_pos + Vector3(
			sin(_orbit_t * 0.18) * 0.15,
			sin(_orbit_t * 0.27) * 0.08,
			0.0
		)


func begin_start_transition() -> void:
	_transitioning = true
	_dolly_t = 0.0
	_play_witch("run")


func _ensure_environment() -> void:
	var env_node: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)
	var env_res: Environment = load(GRAVEYARD_ENV) as Environment
	if env_res:
		env_node.environment = env_res


func _spawn_track() -> void:
	if track_root == null:
		return
	var packed: PackedScene = load(CHUNK_SCENE) as PackedScene
	if packed == null:
		return
	## Three chunks along -Z so the stretch reads as a runner track.
	for i in 3:
		var chunk: Node3D = packed.instantiate() as Node3D
		if chunk == null:
			continue
		track_root.add_child(chunk)
		chunk.position = Vector3(0.0, 0.0, -float(i) * CHUNK_LENGTH)
		if chunk.has_method("on_spawned"):
			chunk.call("on_spawned")


func _spawn_witch() -> void:
	if witch_slot == null:
		return
	var packed: PackedScene = load(WITCH_SCENE) as PackedScene
	if packed == null:
		return
	_witch = packed.instantiate() as Node3D
	if _witch == null:
		return
	witch_slot.add_child(_witch)
	_witch.position = Vector3.ZERO


func _play_witch(anim_name: String) -> void:
	if _witch != null and _witch.has_method("play"):
		_witch.call("play", anim_name, true)
