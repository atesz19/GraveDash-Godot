extends Node3D
## Wrought-iron fence run — all spikes in one MultiMesh draw call (shared across instances).

const LENGTH: float = 6.0
const SPACING: float = 0.3
const IRON: Material = preload("res://resources/materials/props/iron.tres")

static var _shared: MultiMesh = null

@onready var spikes: MultiMeshInstance3D = $Spikes


func _ready() -> void:
	if _shared == null:
		_shared = _build()
	spikes.multimesh = _shared
	spikes.material_override = IRON


static func _build() -> MultiMesh:
	var bar := BoxMesh.new()
	bar.size = Vector3(0.035, 1.5, 0.035)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bar
	var count := int(LENGTH / SPACING) - 1
	mm.instance_count = count
	for i in count:
		var z := -LENGTH * 0.5 + SPACING * float(i + 1)
		var h := 1.0 + 0.1 * float(i % 2)
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(0.0, 0.75 * h, z))
		mm.set_instance_transform(i, xf)
	return mm
