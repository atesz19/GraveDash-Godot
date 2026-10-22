extends Node3D
## MenuWorld — live graveyard backdrop for the main menu (orbit camera + idle Witch).

const CHUNK_SCENE := "res://scenes/levels/Chunk_Graveyard_01.tscn"
const GRAVEYARD_ENV := "res://resources/biomes/graveyard_environment.tres"
const CHUNK_LENGTH: float = 45.0
## Extra menu-only edge props (all |x| >= EDGE_MIN_X so lanes stay clear).
const EDGE_MIN_X: float = 5.2
const EDGE_PROP_SCENES: Array[String] = [
	"res://scenes/levels/props/DecorGravestone_01.tscn",
	"res://scenes/levels/props/DecorGravestone_02.tscn",
	"res://scenes/levels/props/DecorGravestone_03.tscn",
	"res://scenes/levels/props/DecorGravestone_04.tscn",
	"res://scenes/levels/props/DecorFallenCross.tscn",
	"res://scenes/levels/props/DecorFence.tscn",
	"res://scenes/levels/props/DecorCoffin.tscn",
	"res://scenes/levels/props/DecorRock.tscn",
	"res://scenes/levels/props/DecorBush.tscn",
	"res://scenes/levels/props/DecorDeadTree.tscn",
	"res://scenes/levels/props/Torch.tscn",
]

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var track_root: Node3D = $Track
@onready var witch_slot: Node3D = $WitchSlot
@onready var moon: DirectionalLight3D = $MoonLight

var _witch: Node3D = null
var _orbit_t: float = 0.0
var _transitioning: bool = false
var _cam_base_pos: Vector3 = Vector3(-0.6, 1.45, 5.0)
var _dolly_t: float = 0.0
var _edge_root: Node3D = null


func _ready() -> void:
	_ensure_environment()
	_spawn_track()
	_spawn_edge_decor()
	_spawn_witch()
	_force_backdrop_visible()
	if camera:
		camera.current = true
		_cam_base_pos = camera.position
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
		camera_pivot.rotation.y = lerpf(sin(_orbit_t * 0.22) * 0.28, 0.0, ease_t)
		camera_pivot.rotation.x = lerpf(-0.12 + sin(_orbit_t * 0.35) * 0.04, -0.08, ease_t)
		if camera:
			camera.position = _cam_base_pos.lerp(Vector3(0.0, 1.8, 4.2), ease_t)
		return
	## Gentle idle orbit / sway — keep Witch framed as the hero.
	camera_pivot.rotation.y = sin(_orbit_t * 0.22) * 0.18
	camera_pivot.rotation.x = -0.1 + sin(_orbit_t * 0.35) * 0.03
	if camera:
		camera.position = _cam_base_pos + Vector3(
			sin(_orbit_t * 0.18) * 0.1,
			sin(_orbit_t * 0.27) * 0.06,
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


func _spawn_edge_decor() -> void:
	## Menu-only densification between chunk props — never inside the 3 lanes.
	_edge_root = get_node_or_null("EdgeDecor") as Node3D
	if _edge_root == null:
		_edge_root = Node3D.new()
		_edge_root.name = "EdgeDecor"
		add_child(_edge_root)
	var packed_props: Array[PackedScene] = []
	for path in EDGE_PROP_SCENES:
		var ps: PackedScene = load(path) as PackedScene
		if ps:
			packed_props.append(ps)
	if packed_props.is_empty():
		return
	## Scatter along both shoulders across the 3-chunk stretch (~135m).
	## kind indices match EDGE_PROP_SCENES (0–3 = gravestone FBX variants).
	var placements: Array[Dictionary] = [
		{"side": -1.0, "x": 5.6, "z": 8.0, "yaw": 20.0, "kind": 0},
		{"side": -1.0, "x": 6.4, "z": -6.0, "yaw": -12.0, "kind": 1},
		{"side": -1.0, "x": 5.4, "z": -22.0, "yaw": 90.0, "kind": 5},
		{"side": -1.0, "x": 6.8, "z": -38.0, "yaw": 35.0, "kind": 2},
		{"side": -1.0, "x": 5.8, "z": -52.0, "yaw": -8.0, "kind": 4},
		{"side": -1.0, "x": 7.2, "z": -68.0, "yaw": 15.0, "kind": 8},
		{"side": -1.0, "x": 7.6, "z": -84.0, "yaw": -20.0, "kind": 9},
		{"side": -1.0, "x": 5.5, "z": -100.0, "yaw": 0.0, "kind": 10},
		{"side": -1.0, "x": 6.2, "z": -116.0, "yaw": 25.0, "kind": 3},
		{"side": 1.0, "x": 5.7, "z": 4.0, "yaw": -18.0, "kind": 3},
		{"side": 1.0, "x": 6.5, "z": -12.0, "yaw": 10.0, "kind": 8},
		{"side": 1.0, "x": 5.4, "z": -28.0, "yaw": -90.0, "kind": 5},
		{"side": 1.0, "x": 6.9, "z": -44.0, "yaw": 40.0, "kind": 6},
		{"side": 1.0, "x": 5.9, "z": -60.0, "yaw": 5.0, "kind": 7},
		{"side": 1.0, "x": 7.4, "z": -76.0, "yaw": -15.0, "kind": 9},
		{"side": 1.0, "x": 5.6, "z": -92.0, "yaw": 0.0, "kind": 10},
		{"side": 1.0, "x": 6.3, "z": -108.0, "yaw": 22.0, "kind": 1},
		{"side": 1.0, "x": 7.8, "z": -124.0, "yaw": -30.0, "kind": 2},
	]
	for p in placements:
		var kind: int = clampi(int(p["kind"]), 0, packed_props.size() - 1)
		var node: Node3D = packed_props[kind].instantiate() as Node3D
		if node == null:
			continue
		_edge_root.add_child(node)
		var side: float = float(p["side"])
		var x: float = maxf(EDGE_MIN_X, float(p["x"]))
		node.position = Vector3(side * x, 0.0, float(p["z"]))
		node.rotation_degrees.y = float(p["yaw"])


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


func _play_witch(anim_name: String) -> void:
	if _witch != null and _witch.has_method("play"):
		_witch.call("play", anim_name, true)
