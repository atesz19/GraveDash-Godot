extends CanvasLayer
## BiomeTransition — black fog fade between biomes (Graveyard → Haunted Castle).

signal fade_midpoint
signal fade_finished

@onready var veil: ColorRect = $Veil

var _busy: bool = false
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	if veil:
		veil.modulate.a = 0.0
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not BiomeManager.transition_requested.is_connected(_on_transition_requested):
		BiomeManager.transition_requested.connect(_on_transition_requested)


func _on_transition_requested(to_biome: String) -> void:
	play_transition(to_biome)


func play_transition(to_biome: String) -> void:
	if _busy:
		return
	_busy = true
	if _tween and _tween.is_valid():
		_tween.kill()
	## Ramp fog denser while the veil comes in.
	_ramp_fog(0.09, 0.6)
	_tween = create_tween()
	_tween.tween_property(veil, "modulate:a", 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		fade_midpoint.emit()
		BiomeManager.apply_transition_biome(to_biome)
	)
	_tween.tween_interval(0.2)
	_tween.tween_callback(func() -> void:
		_ramp_fog(-1.0, 0.0)  ## restore biome defaults via applied env
	)
	_tween.tween_property(veil, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_busy = false
		fade_finished.emit()
		BiomeManager.finish_transition(to_biome)
	)


func _ramp_fog(density: float, _duration: float) -> void:
	if BiomeManager.world_environment == null:
		return
	var env := BiomeManager.world_environment.environment
	if env == null:
		return
	if density < 0.0:
		return
	env.fog_density = density
	env.fog_light_color = Color(0.02, 0.01, 0.03, 1)
