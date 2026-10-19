extends SceneTree
## Headless: validate ChunkPatterns catalog (free-lane + lane bounds).

const ChunkPatternsScript = preload("res://scripts/levels/ChunkPatterns.gd")


func _init() -> void:
	var catalog: Array[Dictionary] = ChunkPatternsScript.all_patterns()
	var failed: int = 0
	print("patterns=%d" % catalog.size())
	for p in catalog:
		var id: String = str(p.get("id", "?"))
		if not ChunkPatternsScript.validate_pattern(p):
			push_error("FAIL full-block: %s" % id)
			failed += 1
			continue
		for group_name in ["obstacles", "souls"]:
			var specs: Array = p.get(group_name, []) as Array
			for item in specs:
				if not (item is Dictionary):
					continue
				var d: Dictionary = item as Dictionary
				var lane: int = int(d.get("lane", -1))
				if lane < 0 or lane > 2:
					push_error("FAIL lane %d in %s/%s" % [lane, id, group_name])
					failed += 1
	for diff in [0, 2, 5, 10, 15]:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(diff + 1)
		var picked: Dictionary = ChunkPatternsScript.pick_pattern(rng, diff, "graveyard")
		if picked.is_empty() or not ChunkPatternsScript.validate_pattern(picked):
			push_error("FAIL pick diff=%d" % diff)
			failed += 1
		else:
			print("pick diff=%d -> %s" % [diff, str(picked.get("id", "?"))])
	var castle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	castle_rng.seed = 42
	var castle: Dictionary = ChunkPatternsScript.pick_pattern(castle_rng, 6, "haunted_castle")
	print("pick castle -> %s" % str(castle.get("id", "?")))
	if failed > 0:
		push_error("Pattern validation failed: %d" % failed)
		quit(1)
	print("All patterns OK")
	quit(0)
