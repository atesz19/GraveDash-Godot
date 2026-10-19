extends Node
## BiomeManager — owns biome definitions and applies atmosphere to the play world.
## Starting biome is Graveyard (fog, cold moonlight, muddy track).

signal biome_changed(biome_id: String)
signal biome_applied(biome_id: String)

## Active biome id. Matches chunk pool naming (e.g. "graveyard").
var current_biome: String = "graveyard"

## Ordered progression used by future distance / score thresholds.
const BIOME_ORDER: PackedStringArray = [
	"graveyard",
	"crypt",
	"fog_woods",
]

## Soft refs set by Main / LevelGenerator when the play scene boots.
var world_environment: WorldEnvironment = null
var moon_light: DirectionalLight3D = null

## biome_id → definition dictionary.
var _biomes: Dictionary = {}


func _ready() -> void:
	_register_builtin_biomes()
	## Ensure starting biome is graveyard before any scene asks for chunks.
	current_biome = "graveyard"


func _register_builtin_biomes() -> void:
	_biomes["graveyard"] = {
		"display_name": "Graveyard",
		"environment": preload("res://resources/biomes/graveyard_environment.tres"),
		"chunk_scene": preload("res://scenes/levels/Chunk_Graveyard_01.tscn"),
		"chunk_pool_id": "chunk_graveyard",
		"moon_color": Color(0.52, 0.58, 0.95, 1),
		"moon_energy": 0.48,
		"moon_specular": 0.35,
		## Slight downward / side angle for threatening moonlight.
		"moon_rotation_degrees": Vector3(-42.0, -35.0, 12.0),
	}
	## Placeholders for later biomes (same chunk until dedicated scenes exist).
	_biomes["crypt"] = {
		"display_name": "Crypt",
		"environment": preload("res://resources/biomes/graveyard_environment.tres"),
		"chunk_scene": preload("res://scenes/levels/Chunk_Graveyard_01.tscn"),
		"chunk_pool_id": "chunk_graveyard",
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


func bind_world(env: WorldEnvironment, light: DirectionalLight3D) -> void:
	world_environment = env
	moon_light = light


## Apply current (or given) biome materials / fog / moonlight to the bound world.
func apply_biome(biome_id: String = "") -> void:
	if biome_id != "" and biome_id != current_biome:
		set_biome(biome_id)
	var data := get_biome_data()
	if world_environment and data.has("environment"):
		world_environment.environment = data["environment"]
	if moon_light:
		moon_light.light_color = data.get("moon_color", Color.WHITE)
		moon_light.light_energy = float(data.get("moon_energy", 0.5))
		moon_light.light_specular = float(data.get("moon_specular", 0.3))
		moon_light.shadow_enabled = true
		var rot: Vector3 = data.get("moon_rotation_degrees", Vector3(-45, -30, 0))
		moon_light.rotation_degrees = rot
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


func advance_biome() -> void:
	var idx := BIOME_ORDER.find(current_biome)
	if idx < 0 or idx >= BIOME_ORDER.size() - 1:
		return
	set_biome(BIOME_ORDER[idx + 1])
	apply_biome()


## Called from Main at boot — forces Graveyard as the opening section.
func start_run_biome() -> void:
	current_biome = "graveyard"
	apply_biome("graveyard")
