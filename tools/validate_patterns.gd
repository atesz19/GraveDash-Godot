extends SceneTree
## Headless: validate ChunkPatterns catalog (no pits, free-lane, new kinds).

const ChunkPatternsScript = preload("res://scripts/levels/ChunkPatterns.gd")

const ALLOWED_OBS: Array[String] = [
	"obstacle_gravestone",
	"obstacle_low",
	"obstacle_high",
	"obstacle_side",
	"obstacle_platform",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: Array[Dictionary] = ChunkPatternsScript.all_patterns()
	var failed: int = 0
	var kind_counts: Dictionary = {}
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
				if group_name == "obstacles":
					var kind: String = str(d.get("kind", ""))
					if kind == "obstacle_pit":
						push_error("FAIL pit still in pattern %s" % id)
						failed += 1
					elif not ALLOWED_OBS.has(kind):
						push_error("FAIL unknown kind %s in %s" % [kind, id])
						failed += 1
					else:
						kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
					var width: int = int(d.get("width", 1))
					if width < 1 or width > 2 or lane + width - 1 > 2:
						push_error("FAIL width/lane in %s" % id)
						failed += 1
	for k in ALLOWED_OBS:
		print("kind %s count=%d" % [k, int(kind_counts.get(k, 0))])
		if int(kind_counts.get(k, 0)) <= 0:
			push_error("FAIL missing kind in catalog: %s" % k)
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
	## Scene file presence (instantiate via deferred tool that has autoloads).
	for path in [
		"res://scenes/obstacles/ObstacleLow.tscn",
		"res://scenes/obstacles/ObstacleHigh.tscn",
		"res://scenes/obstacles/ObstaclePlatform.tscn",
	]:
		if not ResourceLoader.exists(path):
			push_error("FAIL missing %s" % path)
			failed += 1
		else:
			print("OK resource ", path)
	if failed > 0:
		push_error("Pattern validation failed: %d" % failed)
		quit(1)
	print("All patterns OK")
	quit(0)
