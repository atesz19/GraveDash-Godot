extends SceneTree
## Headless: SkinManager catalog, buy/equip persist, runners load & animate.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var sm: Node = get_root().get_node_or_null("SkinManager")
	if sm == null:
		push_error("FAIL SkinManager missing")
		quit(1)
		return
	var catalog: Array = sm.call("get_catalog")
	if catalog.size() < 5:
		push_error("FAIL catalog size=%d" % catalog.size())
		failed += 1
	else:
		print("OK catalog=", catalog.size())
	## Prices
	var expect := {
		"witch": 0,
		"skeleton_minion": 10000,
		"skeleton_rogue": 20000,
		"skeleton_warrior": 25000,
		"skeleton_mage": 30000,
	}
	for skin in catalog:
		var id: String = str(skin.get("id", ""))
		var price: int = int(skin.get("price", -1))
		if expect.has(id) and int(expect[id]) != price:
			push_error("FAIL price %s got %d" % [id, price])
			failed += 1
		else:
			print("OK price ", id, "=", price)
		var path: String = str(skin.get("runner_scene", ""))
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("FAIL runner %s" % path)
			failed += 1
			continue
		var runner: Node3D = packed.instantiate() as Node3D
		get_root().add_child(runner)
		await process_frame
		await process_frame
		await process_frame
		if not runner.has_method("play"):
			push_error("FAIL no play() on %s" % id)
			failed += 1
		else:
			runner.call("play", "run", true)
			await process_frame
			print("OK runner ", id, " play run")
		## Skeleton must resolve KayKit bones.
		if id != "witch":
			var skel: Skeleton3D = _find_skel(runner)
			if skel == null:
				push_error("FAIL no skeleton %s" % id)
				failed += 1
			elif skel.find_bone("upperleg.l") < 0 and skel.find_bone("Hip_L") < 0:
				push_error("FAIL unexpected bones %s" % id)
				failed += 1
			else:
				print("OK bones ", id)
		runner.queue_free()
		await process_frame

	## Buy / equip with fake wallet.
	var score: Node = get_root().get_node_or_null("ScoreManager")
	if score:
		score.set("total_souls", 100000)
		var err: String = str(sm.call("buy_skin", "skeleton_minion"))
		if err != "":
			push_error("FAIL buy minion: %s" % err)
			failed += 1
		else:
			print("OK buy minion")
		if not bool(sm.call("is_owned", "skeleton_minion")):
			push_error("FAIL not owned after buy")
			failed += 1
		err = str(sm.call("equip_skin", "skeleton_minion"))
		if err != "" or str(sm.get("equipped_id")) != "skeleton_minion":
			push_error("FAIL equip minion")
			failed += 1
		else:
			print("OK equip minion")
		## Persist round-trip via save keys.
		var save: Node = get_root().get_node_or_null("SaveSystem")
		if save:
			var owned: Variant = save.call("get_value", "skins_owned", [])
			var eq: String = str(save.call("get_value", "skin_equipped", ""))
			print("OK save owned=", owned, " equipped=", eq)
			if eq != "skeleton_minion":
				push_error("FAIL save equipped")
				failed += 1

	## create_runner returns equipped.
	var created: Node3D = sm.call("create_runner") as Node3D
	if created == null:
		push_error("FAIL create_runner")
		failed += 1
	else:
		get_root().add_child(created)
		await process_frame
		print("OK create_runner=", created.name)
		created.queue_free()

	## MenuWorld uses SkinManager.
	var menu_ps: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu: Node = menu_ps.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	var slot: Node = menu.get_node_or_null("MenuWorld/WitchSlot")
	if slot == null or slot.get_child_count() < 1:
		push_error("FAIL menu witch slot empty")
		failed += 1
	else:
		print("OK menu preview=", slot.get_child(0).name)
	var list: Node = menu.find_child("SkinList", true, false)
	if list == null or list.get_child_count() < 5:
		push_error("FAIL SkinList rows=%d" % (list.get_child_count() if list else -1))
		failed += 1
	else:
		print("OK SkinList rows=", list.get_child_count())

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_skins")
	quit(0)


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f := _find_skel(c)
		if f:
			return f
	return null
