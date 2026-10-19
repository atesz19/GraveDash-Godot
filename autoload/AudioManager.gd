extends Node
## AudioManager — stub. Wire music / SFX buses and pools in a later MVP step.

enum Bus { MASTER, MUSIC, SFX }

var _muted: bool = false


func play_sfx(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	## TODO: acquire pooled AudioStreamPlayer and play.
	pass


func play_music(_stream: AudioStream, _fade_in: float = 0.5) -> void:
	## TODO: crossfade music tracks per biome.
	pass


func stop_music(_fade_out: float = 0.5) -> void:
	pass


func set_muted(muted: bool) -> void:
	_muted = muted
	## TODO: mute AudioServer buses.


func is_muted() -> bool:
	return _muted
