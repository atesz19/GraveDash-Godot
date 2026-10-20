extends Node3D
## ChaserSpawner — keeps 1–3 pooled chaser ghosts behind the player.

signal almost_caught_changed(active: bool, intensity: float)

const POOL_ID := "chaser_ghost"
const LANE_POSITIONS: Array[float] = [-2.5, 0.0, 2.5]

@export var chaser_scene: PackedScene
@export var player_path: NodePath = ^"../Player"
@export_range(1, 3) var chaser_count: int = 2
@export var spawn_delay: float = 1.5
@export var start_gap_min: float = 18.0
@export var start_gap_max: float = 26.0

@onready var almost_ui: CanvasLayer = $AlmostCaughtUI
@onready var vignette: ColorRect = $AlmostCaughtUI/Vignette
@onready var edge_top: ColorRect = $AlmostCaughtUI/EdgeTop
@onready var edge_bottom: ColorRect = $AlmostCaughtUI/EdgeBottom
@onready var warning_label: Label = $AlmostCaughtUI/WarningLabel

var _player: Node3D
var _chasers: Array[Node] = []
var _spawned: bool = false
var _almost_active: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node3D
	if chaser_scene == null:
		chaser_scene = preload("res://scenes/enemies/ChaserGhost.tscn")
	if not ObjectPool.has_pool(POOL_ID):
		ObjectPool.register_pool(POOL_ID, chaser_scene, chaser_count + 1)
	if almost_ui:
		almost_ui.visible = true
	if vignette:
		vignette.modulate.a = 0.0
	if warning_label:
		warning_label.modulate.a = 0.0
	## Delay so the player gets a clean start.
	get_tree().create_timer(spawn_delay).timeout.connect(_spawn_pack)


func _process(delta: float) -> void:
	if not _spawned or not GameManager.is_playing():
		_set_almost(false, 0.0)
		return
	_update_almost_caught(delta)


func _spawn_pack() -> void:
	if _spawned:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		return
	_spawned = true
	var count := clampi(chaser_count, 1, 3)
	## Pack offsets so they fan behind the player.
	var offsets: Array[float] = [0.0, -1.6, 1.6]
	for i in count:
		var ghost := ObjectPool.acquire(POOL_ID) as Node3D
		if ghost == null:
			continue
		if ghost.get_parent() != self:
			if ghost.get_parent() != null:
				ghost.get_parent().remove_child(ghost)
			add_child(ghost)
		ghost.pool_id = POOL_ID
		var gap := _rng.randf_range(start_gap_min, start_gap_max) + float(i) * 2.5
		var jitter := _rng.randf_range(1.02, 1.08)
		if ghost.has_method("setup"):
			ghost.call("setup", _player, gap, offsets[i], jitter)
		if ghost.has_method("on_spawned"):
			ghost.call("on_spawned")
		if ghost.has_signal("caught_player"):
			if not ghost.caught_player.is_connected(_on_chaser_caught):
				ghost.caught_player.connect(_on_chaser_caught)
		_chasers.append(ghost)
	print("[ChaserSpawner] Spawned %d chasers" % _chasers.size())


func _on_chaser_caught() -> void:
	_set_almost(false, 0.0)


func _update_almost_caught(_delta: float) -> void:
	var min_gap := 999.0
	for c in _chasers:
		if c == null or not is_instance_valid(c):
			continue
		if c.has_method("get_gap"):
			min_gap = minf(min_gap, float(c.call("get_gap")))
	## Ghost Form: suppress the scare UX (phasethrough).
	if _player and _player.has_method("is_ghost_form") and _player.call("is_ghost_form"):
		_set_almost(false, 0.0)
		return
	var almost_dist := 7.0
	if min_gap >= almost_dist:
		_set_almost(false, 0.0)
		return
	## 0 at almost_dist, 1 at catch distance (~2.2).
	var intensity := 1.0 - clampf((min_gap - 2.2) / (almost_dist - 2.2), 0.0, 1.0)
	_set_almost(true, intensity)


func _set_almost(active: bool, intensity: float) -> void:
	var target_a := intensity * 0.55 if active else 0.0
	var edge_a := intensity * 0.9 if active else 0.0
	if vignette:
		vignette.modulate.a = lerpf(vignette.modulate.a, target_a, 0.2)
	if edge_top:
		edge_top.modulate.a = lerpf(edge_top.modulate.a, edge_a, 0.2)
	if edge_bottom:
		edge_bottom.modulate.a = lerpf(edge_bottom.modulate.a, edge_a, 0.2)
	if warning_label:
		warning_label.modulate.a = lerpf(
			warning_label.modulate.a,
			(0.55 + intensity * 0.45) if active else 0.0,
			0.25
		)
		if active:
			warning_label.text = "ALMOST CAUGHT"
	if AudioManager and AudioManager.has_method("set_almost_caught"):
		AudioManager.set_almost_caught(active, intensity)
	if active != _almost_active:
		_almost_active = active
		almost_caught_changed.emit(active, intensity)


func release_all() -> void:
	var copy := _chasers.duplicate()
	_chasers.clear()
	_spawned = false
	for c in copy:
		if c == null or not is_instance_valid(c):
			continue
		if c.has_method("on_recycled"):
			c.call("on_recycled")
		ObjectPool.release(POOL_ID, c)
	_set_almost(false, 0.0)
