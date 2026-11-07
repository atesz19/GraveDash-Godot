extends SceneTree
## Headless: soul economy model + UpgradeManager persistence/purchase checks.
## godot --headless --path . --script res://tools/validate_economy.gd
##
## Model: walk a run with PlayerController's speed ramp, sample ChunkPatterns for the
## soul value spawned per chunk, apply a pickup rate, then add mission rewards and the
## multiplier bonus. Asserts the balance targets against EconomyConfig costs.

const Economy = preload("res://scripts/economy/EconomyConfig.gd")
const ChunkPatternsScript = preload("res://scripts/levels/ChunkPatterns.gd")

const START_SPEED: float = 10.5
const MAX_SPEED: float = 25.0
const RAMP: float = 0.17
const CHUNK_LENGTH: float = 45.0
const SAFE_CHUNKS: int = 1
const INTRO_SOULS: int = 6

## Player skill assumptions (share of spawned soul value actually picked up).
const PICKUP_RATE_CASUAL: float = 0.55
const PICKUP_RATE_GOOD: float = 0.75
## Typical mission completions in a 2.5 min run (avg reward ≈ mean of table).
const MISSIONS_PER_RUN: float = 1.5
const TYPICAL_MULT: int = 3


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var per_diff: Dictionary = {}
	for d in 21:
		var total: float = 0.0
		var samples: int = 400
		for i in samples:
			total += _pattern_value(ChunkPatternsScript.pick_pattern(rng, d, "graveyard"), 5)
		per_diff[d] = total / float(samples)
	print("Soul value spawned per chunk: d0=%.1f d5=%.1f d10=%.1f d20=%.1f" % [
		per_diff[0], per_diff[5], per_diff[10], per_diff[20]])

	var mission_avg: float = 0.0
	for k in Economy.MISSION_REWARDS.keys():
		mission_avg += float(Economy.MISSION_REWARDS[k])
	mission_avg /= float(Economy.MISSION_REWARDS.size())

	var cheapest: int = 1 << 30
	var max_total: int = 0
	for def in Economy.UPGRADES:
		var uid: String = str(def["id"])
		cheapest = mini(cheapest, Economy.cost_for_next(uid, 0))
		max_total = maxi(max_total, Economy.total_cost_to_max(uid))
	var all_upgrades: int = 0
	for def in Economy.UPGRADES:
		all_upgrades += Economy.total_cost_to_max(str(def["id"]))
	var premium_skin: int = 0
	for k in Economy.SKIN_PRICES.keys():
		premium_skin = maxi(premium_skin, int(Economy.SKIN_PRICES[k]))

	var typical_payout: int = 0
	for secs in [60.0, 120.0, 150.0, 180.0]:
		var spawned: float = _spawned_value_for_run(secs, per_diff)
		var casual: int = int(spawned * PICKUP_RATE_CASUAL)
		var good: int = int(spawned * PICKUP_RATE_GOOD)
		var missions: int = int(MISSIONS_PER_RUN * mission_avg * secs / 150.0)
		var bonus: int = int(float(casual) * Economy.multiplier_bonus_ratio(TYPICAL_MULT))
		var payout: int = casual + missions + bonus
		if is_equal_approx(secs, 150.0):
			typical_payout = payout
		print("Run %3ds: spawned=%d collected casual=%d good=%d missions≈%d bonus(x%d)≈%d payout≈%d" % [
			int(secs), int(spawned), casual, good, missions, TYPICAL_MULT, bonus, payout])

	print("Cheapest upgrade level=%d, one upgrade maxed=%d, all upgrades=%d, premium skin=%d" % [
		cheapest, max_total, all_upgrades, premium_skin])
	print("Runs (2.5 min typical payout %d): max one upgrade=%.1f, premium skin=%.1f, everything=%.1f" % [
		typical_payout, float(max_total) / typical_payout, float(premium_skin) / typical_payout,
		float(all_upgrades + _sum_skins()) / typical_payout])

	if typical_payout < cheapest:
		push_error("FAIL typical run (%d) cannot afford cheapest upgrade (%d)" % [typical_payout, cheapest])
		failed += 1
	if float(max_total) / typical_payout < 10.0:
		push_error("FAIL maxing an upgrade takes < 10 runs")
		failed += 1
	if float(premium_skin) / typical_payout < 20.0:
		push_error("FAIL premium skin takes < 20 runs")
		failed += 1

	for def in Economy.UPGRADES:
		var uid2: String = str(def["id"])
		var prev: int = 0
		for lvl in Economy.max_level(uid2):
			var c: int = Economy.cost_for_next(uid2, lvl)
			if c <= prev:
				push_error("FAIL %s cost not increasing at L%d" % [uid2, lvl + 1])
				failed += 1
			prev = c
		if Economy.cost_for_next(uid2, Economy.max_level(uid2)) != -1:
			push_error("FAIL %s maxed level still has a cost" % uid2)
			failed += 1

	failed += await _check_upgrade_manager()
	failed += _check_payout()
	failed += await _check_run_start_upgrades()

	if failed > 0:
		push_error("FAILED checks=%d" % failed)
		quit(1)
		return
	print("PASS validate_economy")
	quit(0)


func _sum_skins() -> int:
	var t: int = 0
	for k in Economy.SKIN_PRICES.keys():
		t += int(Economy.SKIN_PRICES[k])
	return t


func _pattern_value(pattern: Dictionary, big_value: int) -> float:
	var v: float = 0.0
	for s in pattern.get("souls", []) as Array:
		match str((s as Dictionary).get("kind", "")):
			"collectible_big_soul":
				v += big_value
			"collectible_golden_coffin":
				v += Economy.GOLDEN_COFFIN_VALUE
			_:
				v += Economy.SOUL_ORB_VALUE
	return v


func _spawned_value_for_run(seconds: float, per_diff: Dictionary) -> float:
	var t: float = 0.0
	var dist: float = 0.0
	var dt: float = 0.1
	while t < seconds:
		dist += clampf(START_SPEED + t * RAMP, START_SPEED, MAX_SPEED) * dt
		t += dt
	var chunks: int = int(dist / CHUNK_LENGTH)
	var value: float = float(INTRO_SOULS)
	for i in range(SAFE_CHUNKS, chunks):
		value += float(per_diff[clampi(i - SAFE_CHUNKS, 0, 20)])
	return value


func _check_payout() -> int:
	var failed: int = 0
	var sm: Node = get_root().get_node_or_null("ScoreManager")
	var mm: Node = get_root().get_node_or_null("MissionManager")
	var saved_total: int = int(sm.get("total_souls"))
	var saved_mult: int = int(mm.get("multiplier"))
	sm.call("reset_run")
	sm.set("total_souls", 1000)
	mm.set("multiplier", 5)
	sm.call("add_souls", 100)
	sm.call("add_mission_souls", 50)
	var expected: int = 100 + 50 + int(100.0 * Economy.multiplier_bonus_ratio(5))
	sm.call("commit_run_souls")
	sm.call("commit_run_souls")
	var payout: Dictionary = sm.get("last_run_payout")
	if int(sm.get("total_souls")) != 1000 + expected or int(payout.get("total", -1)) != expected:
		push_error("FAIL payout wallet=%d payout=%s expected=%d" % [int(sm.get("total_souls")), payout, expected])
		failed += 1
	else:
		print("OK run payout banked once: ", payout)
	sm.call("add_mission_souls", 10)
	if int(sm.get("run_mission_souls")) != 50:
		push_error("FAIL mission souls accepted after banking")
		failed += 1
	mm.set("multiplier", saved_mult)
	sm.call("reset_run")
	sm.set("total_souls", saved_total)
	sm.call("_write_persisted", "total_souls", saved_total)
	return failed


func _check_run_start_upgrades() -> int:
	var failed: int = 0
	var um: Node = get_root().get_node_or_null("UpgradeManager")
	var gm: Node = get_root().get_node_or_null("GameManager")
	var saved_levels: Dictionary = (um.get("levels") as Dictionary).duplicate()
	um.set("levels", {"head_start": 2, "starting_chance": Economy.max_level("starting_chance")})
	var main: Node = (load("res://scenes/levels/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for i in 4:
		await process_frame
	var player: Node = gm.get("player") as Node
	if player == null:
		push_error("FAIL no player in Main.tscn")
		failed += 1
	else:
		var hs: float = float(player.get("head_start_remaining"))
		if not bool(player.get("has_second_chance")) or not bool(player.get("is_ghost")) or hs <= 0.0:
			push_error("FAIL run-start upgrades chance=%s ghost=%s head_start=%.2f" % [
				player.get("has_second_chance"), player.get("is_ghost"), hs])
			failed += 1
		else:
			print("OK run start: Second Chance + Head Start ghost sprint (%.1fs left)" % hs)
	main.queue_free()
	await process_frame
	um.set("levels", saved_levels)
	gm.set("state", 0)
	return failed


func _check_upgrade_manager() -> int:
	var failed: int = 0
	var um: Node = get_root().get_node_or_null("UpgradeManager")
	var sm: Node = get_root().get_node_or_null("ScoreManager")
	if um == null or sm == null:
		push_error("FAIL UpgradeManager/ScoreManager autoload missing")
		return 1
	await process_frame
	var saved_total: int = int(sm.get("total_souls"))
	var saved_levels: Dictionary = (um.get("levels") as Dictionary).duplicate()
	um.set("levels", {})
	sm.set("total_souls", 100)
	if um.call("buy_upgrade", "ghost_duration") == "":
		push_error("FAIL bought upgrade without enough souls")
		failed += 1
	sm.set("total_souls", 10000)
	var err: String = um.call("buy_upgrade", "ghost_duration")
	var lvl: int = int(um.call("get_level", "ghost_duration"))
	var expected_left: int = 10000 - Economy.cost_for_next("ghost_duration", 0)
	if err != "" or lvl != 1 or int(sm.get("total_souls")) != expected_left:
		push_error("FAIL buy_upgrade err=%s lvl=%d wallet=%d" % [err, lvl, int(sm.get("total_souls"))])
		failed += 1
	else:
		print("OK buy ghost_duration L1, wallet=", sm.get("total_souls"))
	var dur: float = float(um.call("get_powerup_duration", "ghost_form"))
	if not is_equal_approx(dur, Economy.value_at("ghost_duration", 1)):
		push_error("FAIL ghost duration %.1f" % dur)
		failed += 1
	else:
		print("OK ghost duration L1=", dur)
	um.set("levels", {"magnet_radius": 99})
	if int(um.call("get_level", "magnet_radius")) != Economy.max_level("magnet_radius"):
		push_error("FAIL level clamp")
		failed += 1
	um.set("levels", saved_levels)
	um.call("_save")
	sm.set("total_souls", saved_total)
	sm.call("_write_persisted", "total_souls", saved_total)
	return failed
