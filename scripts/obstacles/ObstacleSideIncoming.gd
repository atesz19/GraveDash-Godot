extends "res://scripts/obstacles/ObstacleBase.gd"
## Side-incoming hazard — slides from off-screen into the target lane, then holds.
## Tall enough that lane-change (not jump) is the intended dodge.

const SIDE_SPAWN_X: float = 7.0
const SLIDE_DURATION: float = 0.55

var _target_x: float = 0.0
var _tween: Tween = null
## +1 enters from the right, -1 from the left.
var _side_sign: int = 1


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	_target_x = LANE_POSITIONS[lane_index]
	## Prefer entering from the nearer outer side.
	_side_sign = 1 if lane_index <= 1 else -1
	if lane_index == 1:
		_side_sign = 1 if randf() < 0.5 else -1
	position = Vector3(_target_x + _side_sign * SIDE_SPAWN_X, 0.0, local_z)
	rotation = Vector3.ZERO


func on_spawned() -> void:
	super.on_spawned()
	_start_slide_in()


func _reset_motion() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _start_slide_in() -> void:
	_reset_motion()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:x", _target_x, SLIDE_DURATION)
