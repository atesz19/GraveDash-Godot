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
	## Narrow flicker band — never dunk local fill so the track goes black.
	var flicker: float = (
		0.94
		+ 0.05 * sin(t * 9.7)
		+ 0.03 * sin(t * 17.3 + 1.2)
		+ 0.02 * sin(t * 31.1 + 0.4)
	)
	flicker = clampf(flicker, 0.92, 1.08)
	light.light_energy = _base_energy * flicker
	if flame:
		var s: float = 0.94 + 0.08 * flicker
		flame.scale = Vector3(s * 0.9, s * 1.1, s * 0.9)
		flame.position.y = 1.7 + 0.03 * sin(t * 13.0)
