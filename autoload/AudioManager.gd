extends Node
## AudioManager — Music/SFX buses, volumes, mutes, pooled one-shots, music switch.
## Prefs: music_muted, sfx_muted, music_volume, sfx_volume via SaveSystem.

signal mute_changed(music_muted: bool, sfx_muted: bool)
signal volume_changed(music_volume: float, sfx_volume: float)

const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

const KEY_MUSIC_MUTE: String = "music_muted"
const KEY_SFX_MUTE: String = "sfx_muted"
const KEY_MUSIC_VOL: String = "music_volume"
const KEY_SFX_VOL: String = "sfx_volume"

const SFX_POOL_SIZE: int = 8
const PATH_MUSIC_MENU: String = "res://assets/audio/music/menu_loop.wav"
const PATH_MUSIC_GAME: String = "res://assets/audio/music/gameplay_loop.wav"

const SFX_PATHS: Dictionary = {
	"footstep": "res://assets/audio/sfx/footstep.wav",
	"jump": "res://assets/audio/sfx/jump.wav",
	"slide": "res://assets/audio/sfx/slide.wav",
	"soul_pickup": "res://assets/audio/sfx/soul_pickup.wav",
	"powerup_pickup": "res://assets/audio/sfx/powerup_pickup.wav",
	"powerup_activate": "res://assets/audio/sfx/powerup_activate.wav",
	"powerup_expire": "res://assets/audio/sfx/powerup_expire.wav",
	"death": "res://assets/audio/sfx/death.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
}

var music_muted: bool = false
var sfx_muted: bool = false
## Linear 0..1 volumes (bus gain).
var music_volume: float = 0.75
var sfx_volume: float = 0.85
## Legacy combined mute.
var _muted: bool = false

var _streams: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_fade_tween: Tween
var _current_music_id: String = ""

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_i: int = 0
var _footstep_player: AudioStreamPlayer
var _footstep_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_build_players()
	_load_streams()
	call_deferred("_boot")


func _boot() -> void:
	_load_prefs()
	_apply_buses()
	if GameManager:
		if not GameManager.state_changed.is_connected(_on_state_changed):
			GameManager.state_changed.connect(_on_state_changed)
		_sync_music_for_state(GameManager.state)


func _ensure_buses() -> void:
	## Layout file creates Music/SFX; fall back to runtime creation if missing.
	if AudioServer.get_bus_index(BUS_MUSIC) < 0:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index(BUS_SFX) < 0:
		AudioServer.add_bus()
		var idx2: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx2, BUS_SFX)
		AudioServer.set_bus_send(idx2, "Master")


func _build_players() -> void:
	_music_a = _make_player("MusicA", BUS_MUSIC)
	_music_b = _make_player("MusicB", BUS_MUSIC)
	_music_active = _music_a
	_footstep_player = _make_player("Footsteps", BUS_SFX)
	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player("Sfx%d" % i, BUS_SFX))


func _make_player(node_name: String, bus: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _load_streams() -> void:
	_streams["menu"] = _load_loop(PATH_MUSIC_MENU)
	_streams["gameplay"] = _load_loop(PATH_MUSIC_GAME)
	for id in SFX_PATHS.keys():
		var path: String = str(SFX_PATHS[id])
		var stream: AudioStream = load(path) as AudioStream
		_streams[id] = stream


func _load_loop(path: String) -> AudioStream:
	var stream: AudioStream = load(path) as AudioStream
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func get_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id] as AudioStream
	return null


# --- Prefs -------------------------------------------------------------------

func _load_prefs() -> void:
	if SaveSystem == null:
		return
	music_muted = bool(SaveSystem.get_value(KEY_MUSIC_MUTE, false))
	sfx_muted = bool(SaveSystem.get_value(KEY_SFX_MUTE, false))
	music_volume = clampf(float(SaveSystem.get_value(KEY_MUSIC_VOL, 0.75)), 0.0, 1.0)
	sfx_volume = clampf(float(SaveSystem.get_value(KEY_SFX_VOL, 0.85)), 0.0, 1.0)
	_muted = music_muted and sfx_muted
	mute_changed.emit(music_muted, sfx_muted)
	volume_changed.emit(music_volume, sfx_volume)


func _persist() -> void:
	if SaveSystem == null:
		return
	SaveSystem.set_value(KEY_MUSIC_MUTE, music_muted)
	SaveSystem.set_value(KEY_SFX_MUTE, sfx_muted)
	SaveSystem.set_value(KEY_MUSIC_VOL, music_volume)
	SaveSystem.set_value(KEY_SFX_VOL, sfx_volume)
	if SaveSystem.has_method("save"):
		SaveSystem.save()


func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_muted = music_muted and sfx_muted
	_persist()
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)
	if music_muted:
		_pause_music_players()
	elif _current_music_id != "":
		_resume_music_players()


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_muted = music_muted and sfx_muted
	_persist()
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)


func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_persist()
	_apply_buses()
	volume_changed.emit(music_volume, sfx_volume)


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)
	_persist()
	_apply_buses()
	volume_changed.emit(music_volume, sfx_volume)


func get_music_volume() -> float:
	return music_volume


func get_sfx_volume() -> float:
	return sfx_volume


func is_music_muted() -> bool:
	return music_muted


func is_sfx_muted() -> bool:
	return sfx_muted


func set_muted(muted: bool) -> void:
	music_muted = muted
	sfx_muted = muted
	_muted = muted
	_persist()
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)


func is_muted() -> bool:
	return _muted


func _apply_buses() -> void:
	_set_bus_mute(BUS_MUSIC, music_muted)
	_set_bus_mute(BUS_SFX, sfx_muted)
	_set_bus_volume(BUS_MUSIC, music_volume)
	_set_bus_volume(BUS_SFX, sfx_volume)


func _set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	## Avoid -inf at 0; use a deep mute.
	var db: float = -80.0 if linear <= 0.001 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, db)


# --- Music -------------------------------------------------------------------

func _on_state_changed(_previous: Variant, current: Variant) -> void:
	_sync_music_for_state(current)


func _sync_music_for_state(state: Variant) -> void:
	if state == GameManager.State.MENU:
		play_menu_music()
	elif state == GameManager.State.PLAYING or state == GameManager.State.PAUSED:
		play_gameplay_music()
	elif state == GameManager.State.GAME_OVER:
		## Keep gameplay bed quieter under game-over UI.
		play_gameplay_music()
		if _music_active:
			_music_active.volume_db = -8.0


func play_menu_music(fade: float = 0.6) -> void:
	_crossfade_music("menu", fade)


func play_gameplay_music(fade: float = 0.6) -> void:
	_crossfade_music("gameplay", fade)


func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	if stream == null:
		return
	## Ad-hoc stream (not from catalog).
	if music_muted:
		return
	_swap_to_stream(stream, "custom", fade_in)


func stop_music(fade_out: float = 0.5) -> void:
	_current_music_id = ""
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.set_parallel(true)
	for p in [_music_a, _music_b]:
		if p and p.playing:
			_music_fade_tween.tween_property(p, "volume_db", -40.0, fade_out)
	_music_fade_tween.set_parallel(false)
	_music_fade_tween.tween_callback(_stop_all_music)


func _crossfade_music(music_id: String, fade: float) -> void:
	if _current_music_id == music_id and _music_active and _music_active.playing:
		if _music_active.volume_db < -1.0:
			_music_active.volume_db = 0.0
		return
	var stream: AudioStream = get_stream(music_id)
	if stream == null:
		return
	_swap_to_stream(stream, music_id, fade)


func _swap_to_stream(stream: AudioStream, music_id: String, fade: float) -> void:
	_current_music_id = music_id
	if music_muted:
		_stop_all_music()
		return
	var incoming: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var outgoing: AudioStreamPlayer = _music_active
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.set_parallel(true)
	_music_fade_tween.tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing and outgoing.playing:
		_music_fade_tween.tween_property(outgoing, "volume_db", -40.0, fade)
	_music_fade_tween.set_parallel(false)
	_music_fade_tween.tween_callback(_finish_music_crossfade.bind(incoming, outgoing))


func _finish_music_crossfade(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer) -> void:
	if outgoing and outgoing != incoming and is_instance_valid(outgoing):
		outgoing.stop()
	if is_instance_valid(incoming):
		_music_active = incoming


func _stop_all_music() -> void:
	if _music_a:
		_music_a.stop()
	if _music_b:
		_music_b.stop()


func _pause_music_players() -> void:
	_stop_all_music()


func _resume_music_players() -> void:
	if _current_music_id == "":
		return
	var stream: AudioStream = get_stream(_current_music_id)
	if stream == null:
		return
	_music_active.stream = stream
	_music_active.volume_db = 0.0
	_music_active.play()


# --- SFX API -----------------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if sfx_muted or stream == null:
		return
	var p: AudioStreamPlayer = _next_sfx_player()
	p.stream = stream
	p.pitch_scale = 1.0
	p.volume_db = volume_db
	p.play()


func play_sfx_id(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if sfx_muted:
		return
	var stream: AudioStream = get_stream(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _next_sfx_player()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 1.5)
	p.volume_db = volume_db
	p.play()


func _next_sfx_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _sfx_pool[_sfx_pool_i]
	_sfx_pool_i = (_sfx_pool_i + 1) % _sfx_pool.size()
	return p


func play_ui_click() -> void:
	play_sfx_id("ui_click", -4.0)


func play_jump() -> void:
	play_sfx_id("jump", -2.0, randf_range(0.95, 1.05))


func play_slide() -> void:
	play_sfx_id("slide", -3.0)


func play_soul_pickup() -> void:
	play_sfx_id("soul_pickup", -2.0, randf_range(0.96, 1.06))


func play_powerup_pickup() -> void:
	play_sfx_id("powerup_pickup", -1.0)


func play_powerup_activate(_id: String = "") -> void:
	play_sfx_id("powerup_activate", -1.0)


func play_powerup_expire(_id: String = "") -> void:
	play_sfx_id("powerup_expire", -4.0)


func play_death() -> void:
	play_sfx_id("death", 0.0)


func play_footstep_tick(run_speed: float = 13.0, delta: float = 0.016) -> void:
	## Cadence scales lightly with speed; dedicated player avoids stacking.
	if sfx_muted or not GameManager or not GameManager.is_playing():
		return
	var interval: float = clampf(0.38 - (run_speed - 13.0) * 0.008, 0.22, 0.42)
	_footstep_accum += maxf(0.0, delta)
	if _footstep_accum < interval:
		return
	_footstep_accum = 0.0
	var stream: AudioStream = get_stream("footstep")
	if stream == null:
		return
	_footstep_player.stream = stream
	_footstep_player.pitch_scale = randf_range(0.92, 1.08)
	_footstep_player.volume_db = -8.0
	_footstep_player.play()


func reset_footsteps() -> void:
	_footstep_accum = 0.0
	if _footstep_player:
		_footstep_player.stop()
