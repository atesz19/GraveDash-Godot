extends Node3D
## Torch — warm omni fill + flame flicker (per-instance phase so rows don't sync).

@onready var light: OmniLight3D = $OmniLight3D
@onready var flame: MeshInstance3D = $Flame

var _base_energy: float = 1.75
var _phase: float = 0.0


func _ready() -> void:
	_phase = float(get_instance_id() % 997) * 0.137
	if light:
		_base_energy = light.light_energy
		## Soft contact shadows from moon remain primary; torch omni shadows stay off for mobile cost.
		light.shadow_enabled = false
		light.light_color = Color(1.0, 0.52, 0.18, 1)
		light.omni_range = 7.5
		light.omni_attenuation = 1.25


func _process(_delta: float) -> void:
	if light == null:
		return
	var t: float = Time.get_ticks_msec() * 0.001 + _phase
	var flicker: float = (
		0.82
		+ 0.14 * sin(t * 9.7)
		+ 0.1 * sin(t * 17.3 + 1.2)
		+ 0.07 * sin(t * 31.1 + 0.4)
	)
	light.light_energy = _base_energy * flicker
	if flame:
		var s: float = 0.88 + 0.18 * flicker
		flame.scale = Vector3(s * 0.9, s * 1.15, s * 0.9)
		flame.position.y = 1.7 + 0.04 * sin(t * 13.0)
