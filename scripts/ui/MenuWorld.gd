extends Node3D
## MenuWorld — premium Subway Surfers–style live graveyard menu backdrop.
## Edge densify lives on Chunk.on_spawned so menu + gameplay share the same shoulders.

const CHUNK_SCENE := "res://scenes/levels/Chunk_Graveyard_01.tscn"
const GRAVEYARD_ENV := "res://resources/biomes/graveyard_environment.tres"
const ATMOSPHERE_SCENE := "res://scenes/levels/GraveyardAtmosphere.tscn"
const CHUNK_LENGTH: float = 45.0
const CHUNK_COUNT: int = 4
const CHARACTER_SCALE: float = 1.35
## Body height the camera framing was composed for (Witch incl. hat). Shorter skins
## drop the camera instead of being scaled up, so chibi skeletons don't fill the frame.
const FRAME_BODY_HEIGHT: float = 1.7
const FRAME_CAM_DROP_MAX: float = 0.6

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var track_root: Node3D = $Track
@onready var witch_slot: Node3D = $WitchSlot
@onready var moon: DirectionalLight3D = $MoonLight

var _witch: Node3D = null
var _orbit_t: float = 0.0
var _transitioning: bool = false
var _cam_base_pos: Vector3 = Vector3(-0.55, 1.55, 4.6)
var _cam_scene_pos: Vector3 = Vector3(-0.55, 1.55, 4.6)
var _dolly_t: float = 0.0


func _ready() -> void:
	_ensure_environment()
	_spawn_track()
	_spawn_atmosphere()
	if camera:
		_cam_scene_pos = camera.position
		_cam_base_pos = _cam_scene_pos
	_spawn_witch()
	_force_backdrop_visible()
	if camera:
		camera.current = true
	_play_witch("idle")
	if SkinManager and not SkinManager.equipped_changed.is_connected(_on_skin_equipped):
		SkinManager.equipped_changed.connect(_on_skin_equipped)


func _on_skin_equipped(_skin_id: String) -> void:
	_spawn_witch()
	_play_witch("idle")


func _force_backdrop_visible() -> void:
	## Menu is always Graveyard; ensure backdrop shows even if BiomeManager is mid-castle.
	var backdrop: Node = get_node_or_null("Backdrop")
	if backdrop:
		backdrop.visible = true
		if backdrop.has_method("_set_active"):
			backdrop.call("_set_active", true)


func _process(delta: float) -> void:
	_orbit_t += delta
	if camera_pivot == null:
		return
	if _transitioning:
		_dolly_t = minf(1.0, _dolly_t + delta * 0.85)
		var ease_t: float = _dolly_t * _dolly_t * (3.0 - 2.0 * _dolly_t)
		camera_pivot.rotation.y = lerpf(sin(_orbit_t * 0.22) * 0.22, 0.0, ease_t)
		camera_pivot.rotation.x = lerpf(-0.1 + sin(_orbit_t * 0.35) * 0.03, -0.08, ease_t)
		if camera:
			camera.position = _cam_base_pos.lerp(Vector3(0.0, 1.85, 4.0), ease_t)
		return
	## Gentle idle orbit — keep character hero-framed and readable.
	camera_pivot.rotation.y = sin(_orbit_t * 0.2) * 0.14
	camera_pivot.rotation.x = -0.08 + sin(_orbit_t * 0.32) * 0.025
	if camera:
		camera.position = _cam_base_pos + Vector3(
			sin(_orbit_t * 0.16) * 0.08,
			sin(_orbit_t * 0.24) * 0.05,
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
		## Duplicate so menu can nudge fog/depth without mutating gameplay .tres.
		var env: Environment = env_res.duplicate() as Environment
		env.fog_density = minf(env.fog_density, 0.036)
		env.fog_aerial_perspective = 0.62
		env.adjustment_brightness = maxf(env.adjustment_brightness, 0.96)
		env.tonemap_exposure = maxf(env.tonemap_exposure, 1.05)
		env.glow_intensity = maxf(env.glow_intensity, 0.78)
		env_node.environment = env


func _spawn_track() -> void:
	if track_root == null:
		return
	var packed: PackedScene = load(CHUNK_SCENE) as PackedScene
	if packed == null:
		return
	for i in CHUNK_COUNT:
		var chunk: Node3D = packed.instantiate() as Node3D
		if chunk == null:
			continue
		track_root.add_child(chunk)
		chunk.position = Vector3(0.0, 0.0, -float(i) * CHUNK_LENGTH)
		if chunk.has_method("on_spawned"):
			chunk.call("on_spawned")


func _spawn_atmosphere() -> void:
	if get_node_or_null("MenuAtmosphere") != null:
		return
	var packed: PackedScene = load(ATMOSPHERE_SCENE) as PackedScene
	if packed == null:
		return
	var atmo: Node3D = packed.instantiate() as Node3D
	if atmo == null:
		return
	atmo.name = "MenuAtmosphere"
	## Set follow target before enter_tree so _ready resolves WitchSlot.
	atmo.set("player_path", NodePath("../WitchSlot"))
	add_child(atmo)
	if atmo.has_method("_set_active"):
		atmo.call("_set_active", true)
	## Keep particles around the menu framing volume.
	atmo.position = Vector3(0.0, 5.5, -8.0)
	atmo.set("follow_height", 5.5)
	atmo.set("follow_behind", 2.0)


func _spawn_witch() -> void:
	if witch_slot == null:
		return
	for c in witch_slot.get_children():
		c.queue_free()
	_witch = null
	if SkinManager:
		_witch = SkinManager.create_runner()
	if _witch == null:
		var packed: PackedScene = load("res://scenes/player/WitchRunner.tscn") as PackedScene
		if packed:
			_witch = packed.instantiate() as Node3D
	if _witch == null:
		return
	witch_slot.add_child(_witch)
	_witch.position = Vector3.ZERO
	_witch.scale = Vector3.ONE * CHARACTER_SCALE
	_frame_character()


func _frame_character() -> void:
	var body_h: float = FRAME_BODY_HEIGHT
	if _witch != null and _witch.has_method("get_body_height"):
		body_h = float(_witch.call("get_body_height"))
	var drop: float = clampf((FRAME_BODY_HEIGHT - body_h) * CHARACTER_SCALE, 0.0, FRAME_CAM_DROP_MAX)
	_cam_base_pos = _cam_scene_pos - Vector3(0.0, drop, 0.0)


func _play_witch(anim_name: String) -> void:
	if _witch != null and _witch.has_method("play"):
		_witch.call("play", anim_name, true)
