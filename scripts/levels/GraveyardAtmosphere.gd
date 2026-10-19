extends Node3D
## GraveyardAtmosphere — falling leaves + fog wisps that follow the player along -Z.

@export var player_path: NodePath = ^"../Player"
@export var follow_height: float = 6.0
@export var follow_behind: float = 4.0

@onready var leaves: GPUParticles3D = $FallingLeaves
@onready var wisps: GPUParticles3D = $FogWisps

var _player: Node3D


var _active: bool = true


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_set_active(BiomeManager.current_biome == "graveyard")
	if not BiomeManager.biome_changed.is_connected(_on_biome_changed):
		BiomeManager.biome_changed.connect(_on_biome_changed)
	if not BiomeManager.biome_applied.is_connected(_on_biome_applied):
		BiomeManager.biome_applied.connect(_on_biome_applied)


func _on_biome_changed(biome_id: String) -> void:
	_set_active(biome_id == "graveyard")


func _on_biome_applied(biome_id: String) -> void:
	_set_active(biome_id == "graveyard")


func _set_active(active: bool) -> void:
	_active = active
	visible = active
	if leaves:
		leaves.emitting = active
	if wisps:
		wisps.emitting = active


func _process(_delta: float) -> void:
	if not _active:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return
	## Keep the particle volume centered just ahead of / around the runner.
	global_position = Vector3(
		0.0,
		follow_height,
		_player.global_position.z - 12.0
	)
