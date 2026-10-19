extends Node3D
## Main — play scene bootstrap. Graveyard start; BiomeManager may fade into Haunted Castle.

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var moon_light: DirectionalLight3D = $MoonLight


func _ready() -> void:
	BiomeManager.bind_world(world_environment, moon_light)
	## Opening section is always Graveyard (fog, cold moonlight, muddy track).
	BiomeManager.start_run_biome()
