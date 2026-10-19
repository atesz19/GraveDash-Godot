extends Node3D
## GraveyardAtmosphere — falling leaves + fog wisps that follow the player along -Z.

@export var player_path: NodePath = ^"../Player"
@export var follow_height: float = 6.0
@export var follow_behind: float = 4.0

@onready var leaves: GPUParticles3D = $FallingLeaves
@onready var wisps: GPUParticles3D = $FogWisps

var _player: Node3D


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	if leaves:
		leaves.emitting = true
	if wisps:
		wisps.emitting = true


func _process(_delta: float) -> void:
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
