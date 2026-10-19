extends Node
## AudioManager — music / SFX mute flags + stub playback.
## Prefs persisted via SaveSystem (`music_muted`, `sfx_muted`).

signal mute_changed(music_muted: bool, sfx_muted: bool)

const KEY_MUSIC := "music_muted"
const KEY_SFX := "sfx_muted"

var music_muted: bool = false
var sfx_muted: bool = false
## Legacy combined mute (both buses) — kept for older callers.
var _muted: bool = false


func _ready() -> void:
	call_deferred("_load_prefs")


func _load_prefs() -> void:
	if SaveSystem:
		music_muted = bool(SaveSystem.get_value(KEY_MUSIC, false))
		sfx_muted = bool(SaveSystem.get_value(KEY_SFX, false))
	_muted = music_muted and sfx_muted
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)


func play_sfx(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	if sfx_muted or _stream == null:
		return
	## TODO: acquire pooled AudioStreamPlayer and play.


func play_music(_stream: AudioStream, _fade_in: float = 0.5) -> void:
	if music_muted or _stream == null:
		return
	## TODO: crossfade music tracks per biome.


func stop_music(_fade_out: float = 0.5) -> void:
	pass


func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_muted = music_muted and sfx_muted
	_persist()
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_muted = music_muted and sfx_muted
	_persist()
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)


func is_music_muted() -> bool:
	return music_muted


func is_sfx_muted() -> bool:
	return sfx_muted


## Combined mute (both). Prefer set_music_muted / set_sfx_muted.
func set_muted(muted: bool) -> void:
	music_muted = muted
	sfx_muted = muted
	_muted = muted
	_persist()
	_apply_buses()
	mute_changed.emit(music_muted, sfx_muted)


func is_muted() -> bool:
	return _muted


func _persist() -> void:
	if SaveSystem == null:
		return
	SaveSystem.set_value(KEY_MUSIC, music_muted)
	SaveSystem.set_value(KEY_SFX, sfx_muted)
	if SaveSystem.has_method("save"):
		SaveSystem.save()


func _apply_buses() -> void:
	## Soft-mute via Master children if present; otherwise logical flags only.
	_set_bus_mute("Music", music_muted)
	_set_bus_mute("SFX", sfx_muted)


func _set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
