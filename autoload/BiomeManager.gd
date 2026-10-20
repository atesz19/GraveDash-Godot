extends Node
## BiomeManager — biome definitions, distance-triggered Castle switch, atmosphere apply.
## Opening biome: Graveyard. After ~1200–1500 m → Haunted Castle (with fade).

signal biome_changed(biome_id: String)
signal biome_applied(biome_id: String)
## Overlay listens; performs black fog fade then calls apply_transition_biome.
signal transition_requested(to_biome: String)
signal transition_finished(to_biome: String)

const CASTLE_DISTANCE_MIN: float = 1200.0
const CASTLE_DISTANCE_MAX: float = 1500.0

## Active biome id. Matches chunk pool naming.
var current_biome: String = "graveyard"

const BIOME_ORDER: PackedStringArray = [
	"graveyard",
	"haunted_castle",
	"crypt",
	"fog_woods",
]

var world_environment: WorldEnvironment = null
var moon_light: DirectionalLight3D = null

var _biomes: Dictionary = {}
var _castle_trigger_m: float = 1350.0
var _castle_reached: bool = false
var _transitioning: bool = false


func _ready() -> void:
	_register_builtin_biomes()
	current_biome = "graveyard"


func _process(_delta: float) -> void:
	if _castle_reached or _transitioning:
		return
	if GameManager == null or not GameManager.is_playing():
		return
	if ScoreManager == null:
		return
	if ScoreManager.distance >= _castle_trigger_m:
		request_biome_transition("haunted_castle")


func _register_builtin_biomes() -> void:
	_biomes["graveyard"] = {
		"display_name": "Graveyard",
		"environment": preload("res://resources/biomes/graveyard_environment.tres"),
		"chunk_scene": preload("res://scenes/levels/Chunk_Graveyard_01.tscn"),
		"chunk_pool_id": "chunk_graveyard",
		"chunk_variants": [
			{
				"id": "chunk_graveyard",
				"scene": preload("res://scenes/levels/Chunk_Graveyard_01.tscn"),
			},
		],
		"moon_color": Color(0.58, 0.64, 1.0, 1),
		"moon_energy": 0.78,
		"moon_specular": 0.55,
		"moon_rotation_degrees": Vector3(-42.0, -35.0, 12.0),
	}
	_biomes["haunted_castle"] = {
		"display_name": "Haunted Castle",
		"environment": preload("res://resources/biomes/haunted_castle_environment.tres"),
		"chunk_scene": preload("res://scenes/levels/Chunk_Castle_01.tscn"),
		"chunk_pool_id": "chunk_haunted_castle",
		"chunk_variants": [
			{
				"id": "chunk_haunted_castle",
				"scene": preload("res://scenes/levels/Chunk_Castle_01.tscn"),
			},
			{
				"id": "chunk_haunted_castle_02",
				"scene": preload("res://scenes/levels/Chunk_Castle_02.tscn"),
			},
		],
		"moon_color": Color(0.45, 0.22, 0.35, 1),
		"moon_energy": 0.22,
		"moon_specular": 0.15,
		"moon_rotation_degrees": Vector3(-55.0, 15.0, -10.0),
	}
	## Placeholders for later biomes.
	_biomes["crypt"] = {
		"display_name": "Crypt",
		"environment": preload("res://resources/biomes/haunted_castle_environment.tres"),
		"chunk_scene": preload("res://scenes/levels/Chunk_Castle_01.tscn"),
		"chunk_pool_id": "chunk_haunted_castle",
		"chunk_variants": [
			{"id": "chunk_haunted_castle", "scene": preload("res://scenes/levels/Chunk_Castle_01.tscn")},
		],
		"moon_color": Color(0.4, 0.45, 0.55, 1),
		"moon_energy": 0.35,
		"moon_specular": 0.2,
		"moon_rotation_degrees": Vector3(-50.0, 20.0, 0.0),
	}
	_biomes["fog_woods"] = {
		"display_name": "Fog Woods",
		"environment": preload("res://resources/biomes/graveyard_environment.tres"),
		"chunk_scene": preload("res://scenes/levels/Chunk_Graveyard_01.tscn"),
		"chunk_pool_id": "chunk_graveyard",
		"chunk_variants": [
			{"id": "chunk_graveyard", "scene": preload("res://scenes/levels/Chunk_Graveyard_01.tscn")},
		],
		"moon_color": Color(0.45, 0.55, 0.5, 1),
		"moon_energy": 0.4,
		"moon_specular": 0.25,
		"moon_rotation_degrees": Vector3(-38.0, 10.0, -8.0),
	}


func get_biome_data(biome_id: String = "") -> Dictionary:
	var id := biome_id if biome_id != "" else current_biome
	if _biomes.has(id):
		return _biomes[id]
	return _biomes.get("graveyard", {})


func get_chunk_pool_id(biome_id: String = "") -> String:
	var data := get_biome_data(biome_id)
	return str(data.get("chunk_pool_id", "chunk_graveyard"))


func get_chunk_scene(biome_id: String = "") -> PackedScene:
	var data := get_biome_data(biome_id)
	return data.get("chunk_scene") as PackedScene


func get_chunk_variants(biome_id: String = "") -> Array:
	var data := get_biome_data(biome_id)
	var variants: Variant = data.get("chunk_variants", [])
	if variants is Array:
		return variants as Array
	return []


## Random pool id among the active biome's chunk variants.
func pick_chunk_pool_id(biome_id: String = "") -> String:
	var variants := get_chunk_variants(biome_id)
	if variants.is_empty():
		return get_chunk_pool_id(biome_id)
	var pick: Dictionary = variants[randi() % variants.size()]
	return str(pick.get("id", get_chunk_pool_id(biome_id)))


func bind_world(env: WorldEnvironment, light: DirectionalLight3D) -> void:
	world_environment = env
	moon_light = light


func apply_biome(biome_id: String = "") -> void:
	if biome_id != "" and biome_id != current_biome:
		set_biome(biome_id)
	_apply_environment_and_light()
	biome_applied.emit(current_biome)
	print("[BiomeManager] applied '%s'" % current_biome)


func set_biome(biome_id: String) -> void:
	if not _biomes.has(biome_id):
		push_warning("BiomeManager: unknown biome '%s'" % biome_id)
		return
	if biome_id == current_biome:
		return
	current_biome = biome_id
	biome_changed.emit(current_biome)
	print("[BiomeManager] biome → %s" % current_biome)


## Called by BiomeTransition at fade midpoint — swap env + emit biome_changed for LevelGenerator.
func apply_transition_biome(biome_id: String) -> void:
	if not _biomes.has(biome_id):
		return
	## Duplicate Environment so mid-fade fog ramps don't mutate the shared .tres.
	var data := get_biome_data(biome_id)
	if world_environment and data.has("environment"):
		var src := data["environment"] as Environment
		if src:
			world_environment.environment = src.duplicate() as Environment
	current_biome = biome_id
	biome_changed.emit(current_biome)
	_apply_light_only()
	biome_applied.emit(current_biome)
	print("[BiomeManager] transition applied '%s'" % current_biome)


func finish_transition(biome_id: String) -> void:
	_transitioning = false
	if biome_id == "haunted_castle":
		_castle_reached = true
	transition_finished.emit(biome_id)


func request_biome_transition(to_biome: String) -> void:
	if _transitioning or to_biome == current_biome:
		return
	if not _biomes.has(to_biome):
		return
	_transitioning = true
	if to_biome == "haunted_castle":
		_castle_reached = true  ## Don't re-fire while fading.
	print("[BiomeManager] transition requested → %s @ %.0fm" % [to_biome, ScoreManager.distance])
	transition_requested.emit(to_biome)


func advance_biome() -> void:
	var idx := BIOME_ORDER.find(current_biome)
	if idx < 0 or idx >= BIOME_ORDER.size() - 1:
		return
	request_biome_transition(BIOME_ORDER[idx + 1])


## Called from Main at boot — forces Graveyard as the opening section.
func start_run_biome() -> void:
	current_biome = "graveyard"
	_castle_reached = false
	_transitioning = false
	_castle_trigger_m = randf_range(CASTLE_DISTANCE_MIN, CASTLE_DISTANCE_MAX)
	## Fresh env instance so runtime fog edits stay local to the run.
	var data := get_biome_data("graveyard")
	if world_environment and data.has("environment"):
		var src := data["environment"] as Environment
		if src:
			world_environment.environment = src.duplicate() as Environment
	_apply_light_only()
	biome_changed.emit(current_biome)
	biome_applied.emit(current_biome)
	print("[BiomeManager] start run biome=graveyard, castle @ %.0fm" % _castle_trigger_m)


func _apply_environment_and_light() -> void:
	var data := get_biome_data()
	if world_environment and data.has("environment"):
		var src := data["environment"] as Environment
		if src:
			world_environment.environment = src.duplicate() as Environment
	_apply_light_only()


func _apply_light_only() -> void:
	var data := get_biome_data()
	if moon_light == null:
		return
	moon_light.light_color = data.get("moon_color", Color.WHITE)
	moon_light.light_energy = float(data.get("moon_energy", 0.5))
	moon_light.light_specular = float(data.get("moon_specular", 0.3))
	moon_light.shadow_enabled = true
	moon_light.shadow_blur = 1.4
	moon_light.light_angular_distance = 1.2
	var rot: Vector3 = data.get("moon_rotation_degrees", Vector3(-45, -30, 0))
	moon_light.rotation_degrees = rot
