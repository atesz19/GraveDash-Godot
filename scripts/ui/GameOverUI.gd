extends CanvasLayer
## GameOverUI — Subway Surfers–style game over: dim scrim, count-up stats, Retry CTA.

const THEME_PATH := "res://resources/ui/MainMenuTheme.tres"
const COUNT_UP_DURATION := 0.85
const RETRY_PULSE_SCALE := 1.06
const RETRY_PULSE_HALF := 0.55

@onready var panel: Control = %Root
@onready var dim: ColorRect = %Dim
@onready var center: CenterContainer = %Center
@onready var panel_container: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var distance_label: Label = %DistanceLabel
@onready var souls_label: Label = %SoulsLabel
@onready var score_label: Label = %ScoreLabel
@onready var mult_label: Label = %MultLabel
@onready var best_label: Label = %BestLabel
@onready var wallet_label: Label = %WalletLabel
@onready var new_best_badge: Control = %NewBestBadge
@onready var best_chip: PanelContainer = %BestChip
@onready var mission_box: VBoxContainer = %MissionBox
@onready var mission_labels: Array[Label] = [%Mission1, %Mission2, %Mission3]
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var ad_button: Button = %AdButton

var _best_at_run_start: int = 0
var _count_tween: Tween
var _pulse_tween: Tween
var _display_distance: float = 0.0
var _display_souls: float = 0.0
var _display_score: float = 0.0
var _display_best: float = 0.0
var _target_distance: int = 0
var _target_souls: int = 0
var _target_score: int = 0
var _target_best: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_res := load(THEME_PATH) as Theme
	if theme_res and panel:
		panel.theme = theme_res
	panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	## Placeholder — disabled stub for future rewarded continue.
	ad_button.disabled = true
	ad_button.visible = true
	ad_button.tooltip_text = "Coming soon"
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_started.connect(_on_game_started)
	if ScoreManager:
		_best_at_run_start = ScoreManager.highscore
	if GameManager.state == GameManager.State.GAME_OVER:
		_show_overlay()


func _on_game_over() -> void:
	_show_overlay()


func _on_game_started() -> void:
	_stop_tweens()
	if ScoreManager:
		_best_at_run_start = ScoreManager.highscore
	panel.visible = false
	panel.modulate.a = 1.0
	if dim:
		dim.modulate.a = 1.0
	restart_button.scale = Vector2.ONE
	if new_best_badge:
		new_best_badge.visible = false


func _show_overlay() -> void:
	_stop_tweens()
	var run_score: int = ScoreManager.score if ScoreManager else 0
	var banked: int = ScoreManager.run_souls if ScoreManager else 0
	var wallet: int = ScoreManager.total_souls if ScoreManager else 0
	var dist: int = ScoreManager.get_distance_meters() if ScoreManager else 0
	var best: int = ScoreManager.highscore if ScoreManager else 0
	var mult: int = MissionManager.get_multiplier() if MissionManager else 1
	var is_new_best: bool = run_score > 0 and run_score > _best_at_run_start

	_target_distance = dist
	_target_souls = banked
	_target_score = run_score
	_target_best = best
	_display_distance = 0.0
	_display_souls = 0.0
	_display_score = 0.0
	_display_best = 0.0

	mult_label.text = "×%d" % mult
	wallet_label.text = "Soul wallet  %d" % wallet
	if new_best_badge:
		new_best_badge.visible = is_new_best
	if best_chip:
		best_chip.modulate = Color(1.15, 1.05, 0.85, 1.0) if is_new_best else Color.WHITE

	_refresh_missions()
	_apply_display_labels()
	panel.visible = true
	panel.modulate.a = 0.0
	center.scale = Vector2(0.92, 0.92)
	dim.modulate.a = 0.0

	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(panel, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
	intro.tween_property(dim, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	intro.tween_property(center, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_count_tween = create_tween()
	_count_tween.set_parallel(true)
	_count_tween.tween_method(_set_display_distance, 0.0, float(dist), COUNT_UP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_method(_set_display_souls, 0.0, float(banked), COUNT_UP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_method(_set_display_score, 0.0, float(run_score), COUNT_UP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_method(_set_display_best, 0.0, float(best), COUNT_UP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_new_best and new_best_badge:
		new_best_badge.scale = Vector2(0.4, 0.4)
		_count_tween.tween_property(new_best_badge, "scale", Vector2.ONE, 0.4).set_delay(COUNT_UP_DURATION * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_start_retry_pulse()
	restart_button.grab_focus()


func _set_display_distance(value: float) -> void:
	_display_distance = value
	distance_label.text = "%d m" % int(round(value))


func _set_display_souls(value: float) -> void:
	_display_souls = value
	souls_label.text = "+%d" % int(round(value))


func _set_display_score(value: float) -> void:
	_display_score = value
	score_label.text = "%d" % int(round(value))


func _set_display_best(value: float) -> void:
	_display_best = value
	best_label.text = "%d" % int(round(value))


func _apply_display_labels() -> void:
	distance_label.text = "%d m" % int(round(_display_distance))
	souls_label.text = "+%d" % int(round(_display_souls))
	score_label.text = "%d" % int(round(_display_score))
	best_label.text = "%d" % int(round(_display_best))


func _start_retry_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	restart_button.pivot_offset = restart_button.size * 0.5
	if restart_button.size == Vector2.ZERO:
		await get_tree().process_frame
		restart_button.pivot_offset = restart_button.size * 0.5
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(restart_button, "scale", Vector2(RETRY_PULSE_SCALE, RETRY_PULSE_SCALE), RETRY_PULSE_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(restart_button, "scale", Vector2.ONE, RETRY_PULSE_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_tweens() -> void:
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_count_tween = null
	_pulse_tween = null


func _refresh_missions() -> void:
	if MissionManager == null:
		mission_box.visible = false
		return
	var missions: Array[Dictionary] = MissionManager.get_active_missions()
	var any_visible := false
	for i in mission_labels.size():
		var label: Label = mission_labels[i]
		if label == null:
			continue
		if i < missions.size():
			label.visible = true
			label.text = MissionManager.format_mission_line(missions[i])
			any_visible = true
		else:
			label.visible = false
	mission_box.visible = any_visible


func _on_restart_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_click()
	_stop_tweens()
	panel.visible = false
	GameManager.restart_run()


func _on_menu_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_click()
	_stop_tweens()
	panel.visible = false
	GameManager.return_to_menu()
