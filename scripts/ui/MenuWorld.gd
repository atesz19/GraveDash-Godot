extends Node3D
## MenuWorld — premium Subway Surfers–style live graveyard menu backdrop.

const CHUNK_SCENE := "res://scenes/levels/Chunk_Graveyard_01.tscn"
const GRAVEYARD_ENV := "res://resources/biomes/graveyard_environment.tres"
const ATMOSPHERE_SCENE := "res://scenes/levels/GraveyardAtmosphere.tscn"
const CHUNK_LENGTH: float = 45.0
const CHUNK_COUNT: int = 4
## Extra menu-only edge props (all |x| >= EDGE_MIN_X so lanes stay clear).
const EDGE_MIN_X: float = 5.15
const CHARACTER_SCALE: float = 1.35
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
var _cam_base_pos: Vector3 = Vector3(-0.55, 1.55, 4.6)
var _dolly_t: float = 0.0
var _edge_root: Node3D = null


func _ready() -> void:
	_ensure_environment()
	_spawn_track()
	_spawn_edge_decor()
	_spawn_atmosphere()
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
		env.fog_density = minf(env.fog_density, 0.028)
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


func _spawn_edge_decor() -> void:
	## Dense shoulders + mid-distance ring — never inside the 3 lanes.
	_edge_root = get_node_or_null("EdgeDecor") as Node3D
	if _edge_root == null:
		_edge_root = Node3D.new()
		_edge_root.name = "EdgeDecor"
		add_child(_edge_root)
	else:
		for c in _edge_root.get_children():
			c.queue_free()
	var packed_props: Array[PackedScene] = []
	for path in EDGE_PROP_SCENES:
		var ps: PackedScene = load(path) as PackedScene
		if ps:
			packed_props.append(ps)
	if packed_props.is_empty():
		return
	var placements: Array[Dictionary] = _build_edge_placements()
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
		var sc: float = float(p.get("scale", 1.0))
		if sc != 1.0:
			node.scale = Vector3.ONE * sc


func _build_edge_placements() -> Array[Dictionary]:
	## Procedural dense scatter across ~180m of track shoulders + mid band.
	var out: Array[Dictionary] = []
	var z_start: float = 14.0
	var z_end: float = -float(CHUNK_COUNT) * CHUNK_LENGTH + 8.0
	var z: float = z_start
	var step_i: int = 0
	while z > z_end:
		for side_i in 2:
			var side: float = -1.0 if side_i == 0 else 1.0
			## Near shoulder row (stones / fences / torches).
			var near_kind: int = [0, 1, 2, 3, 5, 4, 10, 7, 8][step_i % 9]
			out.append({
				"side": side,
				"x": 5.35 + float((step_i + side_i) % 3) * 0.35,
				"z": z + float(side_i) * 1.4,
				"yaw": side * (90.0 if near_kind == 5 else float((step_i * 17 + side_i * 23) % 50) - 25.0),
				"kind": near_kind,
				"scale": 1.0,
			})
			## Outer shoulder (trees / coffins / bushes).
			if step_i % 2 == side_i:
				var outer_kind: int = [9, 6, 8, 3, 0, 9, 7][step_i % 7]
				out.append({
					"side": side,
					"x": 6.8 + float(step_i % 4) * 0.45,
					"z": z - 2.2 + float(side_i),
					"yaw": float((step_i * 29) % 70) - 35.0,
					"kind": outer_kind,
					"scale": 1.05 if outer_kind == 9 else 1.0,
				})
			## Mid-distance band (extra stones / crosses — fills barren look).
			if step_i % 3 == 0:
				var mid_kind: int = [0, 1, 2, 3, 4][(step_i + side_i) % 5]
				out.append({
					"side": side,
					"x": 9.2 + float((step_i + side_i) % 3) * 0.7,
					"z": z - 1.0,
					"yaw": float((step_i * 13) % 40) - 20.0,
					"kind": mid_kind,
					"scale": 0.95,
				})
		z -= 5.5
		step_i += 1
	## Accent torch pairs near the hero framing.
	for accent in [
		{"side": -1.0, "x": 5.2, "z": 3.0, "yaw": 0.0, "kind": 10, "scale": 1.15},
		{"side": 1.0, "x": 5.2, "z": 1.5, "yaw": 0.0, "kind": 10, "scale": 1.15},
		{"side": -1.0, "x": 5.3, "z": -10.0, "yaw": 0.0, "kind": 10, "scale": 1.1},
		{"side": 1.0, "x": 5.3, "z": -12.0, "yaw": 0.0, "kind": 10, "scale": 1.1},
	]:
		out.append(accent)
	return out


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


func _play_witch(anim_name: String) -> void:
	if _witch != null and _witch.has_method("play"):
		_witch.call("play", anim_name, true)
