extends SceneTree
## Headless: buses, streams, mute/volume prefs, SFX helpers, music switch.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	await process_frame
	await process_frame
	await process_frame
	var am: Node = get_root().get_node_or_null("AudioManager")
	if am == null:
		push_error("FAIL AudioManager missing")
		quit(1)
		return
	## Buses
	for bus_name in ["Music", "SFX"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx < 0:
			push_error("FAIL bus missing: %s" % bus_name)
			failed += 1
		else:
			print("OK bus ", bus_name, " idx=", idx)
	## Streams
	for id in ["menu", "gameplay", "footstep", "jump", "slide", "soul_pickup",
			"powerup_pickup", "powerup_activate", "powerup_expire",
			"death", "ui_click"]:
		var stream: Variant = am.call("get_stream", id)
		if stream == null:
			push_error("FAIL stream %s" % id)
			failed += 1
		else:
			print("OK stream ", id)
	## Chaser / Almost Caught audio must be gone.
	for gone_id in ["almost_caught", "chaser_approach"]:
		if am.call("get_stream", gone_id) != null:
			push_error("FAIL leftover stream %s" % gone_id)
			failed += 1
		else:
			print("OK removed stream ", gone_id)
	if am.has_method("set_almost_caught"):
		push_error("FAIL set_almost_caught still present")
		failed += 1
	else:
		print("OK set_almost_caught removed")
	## Volume / mute
	am.call("set_music_volume", 0.4)
	am.call("set_sfx_volume", 0.6)
	if abs(float(am.call("get_music_volume")) - 0.4) > 0.001:
		push_error("FAIL music volume")
		failed += 1
	else:
		print("OK music volume")
	am.call("set_music_muted", true)
	am.call("set_sfx_muted", true)
	if not bool(am.call("is_music_muted")) or not bool(am.call("is_sfx_muted")):
		push_error("FAIL mute flags")
		failed += 1
	else:
		print("OK mute")
	am.call("set_music_muted", false)
	am.call("set_sfx_muted", false)
	## Playback helpers (headless — no audible output required)
	am.call("play_ui_click")
	am.call("play_jump")
	am.call("play_slide")
	am.call("play_soul_pickup")
	am.call("play_powerup_pickup")
	am.call("play_powerup_activate", "ghost_form")
	am.call("play_powerup_expire", "ghost_form")
	am.call("play_death")
	am.call("play_menu_music", 0.1)
	await process_frame
	am.call("play_gameplay_music", 0.1)
	await process_frame
	print("OK playback helpers")
	## Save keys written
	var ss: Node = get_root().get_node_or_null("SaveSystem")
	if ss:
		for key in ["music_muted", "sfx_muted", "music_volume", "sfx_volume"]:
			var v: Variant = ss.call("get_value", key, null)
			if v == null:
				push_error("FAIL save key missing %s" % key)
				failed += 1
			else:
				print("OK save key ", key, "=", v)
	if failed > 0:
		quit(1)
	print("Audio system OK")
	quit(0)
