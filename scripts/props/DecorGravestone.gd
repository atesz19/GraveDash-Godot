extends Node3D
## Random gravestone variant (01–04) for edge decor / chunk props.

const VARIANTS: Array[String] = [
	"res://scenes/levels/props/DecorGravestone_01.tscn",
	"res://scenes/levels/props/DecorGravestone_02.tscn",
	"res://scenes/levels/props/DecorGravestone_03.tscn",
	"res://scenes/levels/props/DecorGravestone_04.tscn",
]

@export_range(0, 4, 1) var force_variant: int = 0 ## 0 = random; 1–4 = fixed.


func _ready() -> void:
	var idx: int
	if force_variant >= 1 and force_variant <= 4:
		idx = force_variant - 1
	else:
		idx = randi() % VARIANTS.size()
	var packed: PackedScene = load(VARIANTS[idx]) as PackedScene
	if packed == null:
		return
	var stone: Node3D = packed.instantiate() as Node3D
	if stone == null:
		return
	add_child(stone)
