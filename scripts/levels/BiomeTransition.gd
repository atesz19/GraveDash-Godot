extends CanvasLayer
## BiomeTransition — swaps biomes without darkening the screen.
## Previously used a black ColorRect veil + fog density ramp; that caused a
## progressive blackout once the castle trigger distance was reached.

signal fade_midpoint
signal fade_finished

@onready var veil: ColorRect = $Veil

var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	_hide_veil()
	if not BiomeManager.transition_requested.is_connected(_on_transition_requested):
		BiomeManager.transition_requested.connect(_on_transition_requested)
	if GameManager:
		if not GameManager.game_started.is_connected(_on_game_started):
			GameManager.game_started.connect(_on_game_started)
		if not GameManager.game_over.is_connected(_hide_veil):
			GameManager.game_over.connect(_hide_veil)


func _on_game_started() -> void:
	_busy = false
	_hide_veil()


func _hide_veil() -> void:
	if veil == null:
		return
	veil.visible = false
	veil.modulate.a = 0.0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Keep the ColorRect transparent even if something re-enables it.
	veil.color = Color(0.01, 0.01, 0.02, 0.0)


func _on_transition_requested(to_biome: String) -> void:
	play_transition(to_biome)


func play_transition(to_biome: String) -> void:
	if _busy:
		return
	_busy = true
	_hide_veil()
	## Instant apply — no fog ramp, no black veil, no exposure drift.
	fade_midpoint.emit()
	BiomeManager.apply_transition_biome(to_biome)
	_busy = false
	fade_finished.emit()
	BiomeManager.finish_transition(to_biome)
