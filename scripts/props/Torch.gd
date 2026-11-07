extends Node3D
## Torch — warm omni fill + flame flicker (per-instance phase so rows don't sync).
## Mobile forward renderer shades at most 8 omni lights per mesh, so chunks mix lit torches
## with `cast_light = false` ones that only show the additive halo / ground pool.

@export var cast_light: bool = true
@export var light_energy: float = 1.75
@export var light_range: float = 7.5

@onready var light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D
@onready var flame: MeshInstance3D = get_node_or_null("Flame") as MeshInstance3D
@onready var halo: MeshInstance3D = get_node_or_null("Halo") as MeshInstance3D

var _base_energy: float = 1.75
var _phase: float = 0.0
var _flame_y: float = 0.0
var _halo_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_phase = float(get_instance_id() % 997) * 0.137
	if flame:
		_flame_y = flame.position.y
	if halo:
		_halo_scale = halo.scale
	if light:
		light.visible = cast_light
		_base_energy = light_energy
		light.light_energy = light_energy
		light.shadow_enabled = false
		light.omni_range = light_range
		light.omni_attenuation = 1.25
		## Far torches are hidden by fog anyway; fading them frees per-mesh light slots.
		light.distance_fade_enabled = true
		light.distance_fade_begin = 48.0
		light.distance_fade_length = 14.0


func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001 + _phase
	## Narrow flicker band — never dunk local fill so the track goes black.
	var flicker: float = 0.94 + 0.05 * sin(t * 9.7) + 0.03 * sin(t * 17.3 + 1.2) + 0.02 * sin(t * 31.1 + 0.4)
	flicker = clampf(flicker, 0.92, 1.08)
	if light and cast_light:
		light.light_energy = _base_energy * flicker
	if flame:
		var s: float = 0.94 + 0.08 * flicker
		flame.scale = Vector3(s * 0.9, s * 1.1, s * 0.9)
		flame.position.y = _flame_y + 0.03 * sin(t * 13.0)
	if halo:
		halo.scale = _halo_scale * (0.92 + 0.12 * flicker)
