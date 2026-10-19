extends Node3D
## CastleAtmosphere — dust motes, torch flicker follow-light, lightning flashes.
## Active only while BiomeManager.current_biome == haunted_castle.

@export var player_path: NodePath = ^"../Player"
@export var follow_height: float = 3.5

@onready var dust: GPUParticles3D = $DustMotes
@onready var follow_light: OmniLight3D = $FollowFlicker
@onready var lightning_layer: CanvasLayer = $LightningFlash
@onready var lightning_rect: ColorRect = $LightningFlash/Flash

var _player: Node3D
var _active: bool = false
var _flicker_t: float = 0.0
var _lightning_cd: float = 4.0
var _flash_tween: Tween


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_set_active(BiomeManager.current_biome == "haunted_castle")
	if not BiomeManager.biome_changed.is_connected(_on_biome_changed):
		BiomeManager.biome_changed.connect(_on_biome_changed)
	if not BiomeManager.biome_applied.is_connected(_on_biome_applied):
		BiomeManager.biome_applied.connect(_on_biome_applied)
	if lightning_rect:
		lightning_rect.modulate.a = 0.0


func _on_biome_changed(biome_id: String) -> void:
	_set_active(biome_id == "haunted_castle")


func _on_biome_applied(biome_id: String) -> void:
	_set_active(biome_id == "haunted_castle")


func _set_active(active: bool) -> void:
	_active = active
	visible = active
	if dust:
		dust.emitting = active
	if follow_light:
		follow_light.visible = active
		follow_light.light_energy = 1.2 if active else 0.0
	if lightning_layer:
		lightning_layer.visible = active


func _process(delta: float) -> void:
	if not _active or not GameManager.is_playing():
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return
	global_position = Vector3(0.0, follow_height, _player.global_position.z - 6.0)
	_flicker_t += delta
	if follow_light:
		var wobble := 0.85 + 0.35 * sin(_flicker_t * 11.0) + 0.15 * sin(_flicker_t * 23.0)
		follow_light.light_energy = 1.1 * wobble
		follow_light.omni_range = 10.0 + 1.5 * wobble
	_tick_lightning(delta)


func _tick_lightning(delta: float) -> void:
	_lightning_cd -= delta
	if _lightning_cd > 0.0:
		return
	_lightning_cd = randf_range(3.5, 9.0)
	_do_lightning_flash()


func _do_lightning_flash() -> void:
	if lightning_rect == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	lightning_rect.modulate.a = 0.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(lightning_rect, "modulate:a", 0.55, 0.04)
	_flash_tween.tween_property(lightning_rect, "modulate:a", 0.08, 0.06)
	_flash_tween.tween_property(lightning_rect, "modulate:a", 0.4, 0.05)
	_flash_tween.tween_property(lightning_rect, "modulate:a", 0.0, 0.35)
	## Punch moon energy briefly if bound.
	if BiomeManager.moon_light and _active:
		var light := BiomeManager.moon_light
		var base := light.light_energy
		var tw := create_tween()
		tw.tween_property(light, "light_energy", base + 1.4, 0.05)
		tw.tween_property(light, "light_energy", base, 0.4)
