extends CanvasLayer
## HUD — Score, distance, Best, and active power-up icons + timers.

const THEME_PATH := "res://resources/ui/GraveDashTheme.tres"

@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var best_label: Label = $Margin/VBox/BestLabel
@onready var powerup_box: VBoxContainer = $Margin/VBox/PowerupBox
@onready var root_margin: MarginContainer = $Margin

var _rows: Dictionary = {}  ## id → { row, icon, label }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_res := load(THEME_PATH) as Theme
	if theme_res and root_margin:
		root_margin.theme = theme_res
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.distance_changed.connect(_on_distance_changed)
	ScoreManager.highscore_changed.connect(_on_highscore_changed)
	_cache_rows()
	_hide_all_powerups()
	_refresh_all()
	call_deferred("_bind_player")
	## Hide HUD on menu/game-over; show while playing / paused.
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state, GameManager.state)


func _cache_rows() -> void:
	_rows = {
		"ghost_form": _row_nodes("GhostRow", "GhostIcon", "GhostLabel"),
		"soul_magnet": _row_nodes("MagnetRow", "MagnetIcon", "MagnetLabel"),
		"holy_light": _row_nodes("HolyRow", "HolyIcon", "HolyLabel"),
		"cursed_speed": _row_nodes("CursedRow", "CursedIcon", "CursedLabel"),
		"second_chance": _row_nodes("ChanceRow", "ChanceIcon", "ChanceLabel"),
	}


func _row_nodes(row_name: String, icon_name: String, label_name: String) -> Dictionary:
	var row: Control = powerup_box.get_node_or_null(row_name) as Control
	return {
		"row": row,
		"icon": row.get_node_or_null(icon_name) if row else null,
		"label": row.get_node_or_null(label_name) if row else null,
	}


func _bind_player() -> void:
	var player := GameManager.player
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("powerup_changed"):
		if not player.powerup_changed.is_connected(_on_powerup_changed):
			player.powerup_changed.connect(_on_powerup_changed)
	if player.has_signal("ghost_form_changed"):
		if not player.ghost_form_changed.is_connected(_on_ghost_form_changed):
			player.ghost_form_changed.connect(_on_ghost_form_changed)
	if player.has_signal("second_chance_changed"):
		if not player.second_chance_changed.is_connected(_on_second_chance_changed):
			player.second_chance_changed.connect(_on_second_chance_changed)
	## Sync current state.
	if player.has_method("is_ghost_form") and player.is_ghost_form():
		_on_ghost_form_changed(true, player.ghost_time_remaining)
	if bool(player.get("has_second_chance")):
		_on_second_chance_changed(true)


func _refresh_all() -> void:
	_on_score_changed(ScoreManager.score)
	_on_distance_changed(ScoreManager.distance)
	_on_highscore_changed(ScoreManager.highscore)


func _hide_all_powerups() -> void:
	for id in _rows.keys():
		_set_row_visible(id, false)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score  %d" % new_score


func _on_distance_changed(new_distance: float) -> void:
	distance_label.text = "Distance  %d m" % int(floor(new_distance))


func _on_highscore_changed(new_highscore: int) -> void:
	best_label.text = "Best  %d" % new_highscore


func _on_ghost_form_changed(active: bool, remaining: float) -> void:
	_on_powerup_changed("ghost_form", active, remaining)


func _on_second_chance_changed(has_charge: bool) -> void:
	_on_powerup_changed("second_chance", has_charge, 0.0)


func _on_powerup_changed(powerup_id: String, active: bool, remaining: float) -> void:
	if not _rows.has(powerup_id):
		return
	_set_row_visible(powerup_id, active)
	if not active:
		return
	var entry: Dictionary = _rows[powerup_id]
	var label: Label = entry.get("label") as Label
	var icon: ColorRect = entry.get("icon") as ColorRect
	if label == null:
		return
	match powerup_id:
		"ghost_form":
			label.text = "GHOST  %.1fs" % remaining
			_pulse_icon(icon, Color(0.55, 0.2, 0.85, 0.9), remaining)
		"soul_magnet":
			label.text = "MAGNET  %.1fs" % remaining
			_pulse_icon(icon, Color(0.2, 0.65, 1.0, 0.9), remaining)
		"holy_light":
			label.text = "HOLY  %.1fs" % remaining
			_pulse_icon(icon, Color(1.0, 0.9, 0.4, 0.95), remaining)
		"cursed_speed":
			label.text = "CURSED  %.1fs" % remaining
			_pulse_icon(icon, Color(0.95, 0.25, 0.1, 0.9), remaining)
		"second_chance":
			label.text = "2nd CHANCE"
			if icon:
				icon.color = Color(0.25, 0.9, 0.55, 0.95)


func _set_row_visible(powerup_id: String, visible: bool) -> void:
	var entry: Dictionary = _rows.get(powerup_id, {})
	var row: Control = entry.get("row") as Control
	if row:
		row.visible = visible


func _pulse_icon(icon: ColorRect, base: Color, remaining: float) -> void:
	if icon == null:
		return
	var pulse := 0.65 + 0.35 * absf(sin(remaining * 4.0))
	icon.color = Color(base.r, base.g, base.b, pulse)


func _on_state_changed(_previous: Variant, current: Variant) -> void:
	var playing_or_paused := (
		current == GameManager.State.PLAYING or current == GameManager.State.PAUSED
	)
	visible = playing_or_paused

