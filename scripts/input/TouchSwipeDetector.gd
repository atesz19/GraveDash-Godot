extends Node
## TouchSwipeDetector — maps screen swipes to swipe_* input actions.
## Desktop keys still work via Project Settings; this enables Android touch.

const MIN_DISTANCE: float = 56.0
const MAX_TAP_DURATION: float = 0.45

var _tracking: bool = false
var _start_pos: Vector2 = Vector2.ZERO
var _start_time_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_tracking = true
			_start_pos = touch.position
			_start_time_ms = Time.get_ticks_msec()
		elif _tracking and touch.index == 0:
			_finish_swipe(touch.position)
	elif event is InputEventScreenDrag and _tracking:
		## Allow completing early once the gesture clearly exceeds threshold.
		var drag := event as InputEventScreenDrag
		var delta := drag.position - _start_pos
		if delta.length() >= MIN_DISTANCE * 1.5:
			_finish_swipe(drag.position)


func _finish_swipe(end_pos: Vector2) -> void:
	_tracking = false
	var delta := end_pos - _start_pos
	var elapsed := float(Time.get_ticks_msec() - _start_time_ms) / 1000.0
	if elapsed > MAX_TAP_DURATION * 3.0:
		return
	if delta.length() < MIN_DISTANCE:
		return
	var action := ""
	if absf(delta.x) > absf(delta.y):
		action = "swipe_right" if delta.x > 0.0 else "swipe_left"
	else:
		## Screen Y grows downward — swipe up = jump, swipe down = slide.
		action = "swipe_up" if delta.y < 0.0 else "swipe_down"
	_pulse_action(action)


func _pulse_action(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	## Release on next idle frame so is_action_just_pressed works once.
	call_deferred("_release_action", action)


func _release_action(action: String) -> void:
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
