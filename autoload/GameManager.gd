extends Node
## GameManager — global game state machine for GraveDash.
## States: Menu → Playing ↔ Paused → GameOver → (restart) Menu / Playing.
## Scene flow: MainMenu.tscn ↔ levels/Main.tscn

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const GAME_SCENE := "res://scenes/levels/Main.tscn"

signal state_changed(previous: State, current: State)
signal game_started
signal game_paused
signal game_resumed
signal game_over

## Current high-level game state.
var state: State = State.MENU

## Soft reference to the active player (set by Main / Player on ready).
var player: Node3D = null

## Elapsed run time while in PLAYING (seconds). Used by speed ramp / scoring.
var run_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if state == State.PLAYING:
		run_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	match state:
		State.PLAYING:
			pause_game()
		State.PAUSED:
			resume_game()
		_:
			pass


## Transition helpers -------------------------------------------------------

func start_game() -> void:
	## Soft start when already inside the gameplay scene.
	run_time = 0.0
	if ScoreManager:
		ScoreManager.reset_run()
	_set_state(State.PLAYING)
	game_started.emit()


func go_to_gameplay() -> void:
	## Menu → Main play scene.
	get_tree().paused = false
	run_time = 0.0
	player = null
	if ScoreManager:
		ScoreManager.reset_run()
	_clear_pools()
	_set_state(State.PLAYING)
	get_tree().change_scene_to_file(GAME_SCENE)
	game_started.emit()


func pause_game() -> void:
	if state != State.PLAYING:
		return
	get_tree().paused = true
	_set_state(State.PAUSED)
	game_paused.emit()


func resume_game() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	_set_state(State.PLAYING)
	game_resumed.emit()


func trigger_game_over() -> void:
	if state == State.GAME_OVER:
		return
	get_tree().paused = false
	if ScoreManager:
		ScoreManager.commit_highscore()
		ScoreManager.commit_run_souls()
	_set_state(State.GAME_OVER)
	game_over.emit()


func return_to_menu() -> void:
	get_tree().paused = false
	player = null
	run_time = 0.0
	_clear_pools()
	_set_state(State.MENU)
	get_tree().change_scene_to_file(MENU_SCENE)


func restart_run() -> void:
	## Reload gameplay and start a fresh run.
	get_tree().paused = false
	run_time = 0.0
	player = null
	if ScoreManager:
		ScoreManager.reset_run()
	_clear_pools()
	_set_state(State.PLAYING)
	var tree := get_tree()
	var current_path := ""
	if tree.current_scene:
		current_path = str(tree.current_scene.scene_file_path)
	if current_path == GAME_SCENE:
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(GAME_SCENE)
	game_started.emit()


func is_playing() -> bool:
	return state == State.PLAYING


func is_menu() -> bool:
	return state == State.MENU


func _clear_pools() -> void:
	if ObjectPool and ObjectPool.has_method("clear_all_pools"):
		ObjectPool.clear_all_pools()


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	state_changed.emit(previous, state)
	print("[GameManager] %s → %s" % [State.keys()[previous], State.keys()[next]])
