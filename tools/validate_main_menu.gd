extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var packed: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	if packed == null:
		push_error("FAIL load MainMenu")
		quit(1)
		return
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	if root.get_node_or_null("MenuWorld") == null:
		push_error("FAIL MenuWorld missing")
		failed += 1
	else:
		var track: Node = root.get_node_or_null("MenuWorld/Track")
		var kids: int = track.get_child_count() if track else 0
		print("OK MenuWorld track_chunks=", kids)
	var cam: Camera3D = root.find_child("Camera3D", true, false) as Camera3D
	if cam == null or not cam.current:
		push_error("FAIL menu camera")
		failed += 1
	else:
		print("OK menu camera")
	if root.find_child("ShopPanel", true, false) == null:
		push_error("FAIL ShopPanel")
		failed += 1
	else:
		print("OK ShopPanel")
	if root.find_child("SoulWalletLabel", true, false) == null:
		push_error("FAIL SoulWalletLabel")
		failed += 1
	else:
		print("OK SoulWalletLabel")
	var witch_slot: Node = root.get_node_or_null("MenuWorld/WitchSlot")
	if witch_slot == null or witch_slot.get_child_count() < 1:
		push_error("FAIL witch not spawned")
		failed += 1
	else:
		print("OK witch spawned")
	## ScoreManager wallet via autoload node path ( -s has no global identifier ).
	var sm: Node = get_root().get_node_or_null("ScoreManager")
	if sm:
		sm.call("reset_run")
		sm.set("total_souls", 10)
		sm.call("add_souls", 7)
		sm.call("commit_run_souls")
		var total: int = int(sm.get("total_souls"))
		if total != 17:
			push_error("FAIL wallet bank total=%d" % total)
			failed += 1
		else:
			print("OK soul wallet bank")
		var spent: bool = bool(sm.call("spend_souls", 7))
		if not spent or int(sm.get("total_souls")) != 10:
			push_error("FAIL spend")
			failed += 1
		else:
			print("OK soul spend")
	else:
		push_warning("ScoreManager autoload missing in -s context")
	if failed > 0:
		quit(1)
	print("MainMenu upgrade OK")
	quit(0)
