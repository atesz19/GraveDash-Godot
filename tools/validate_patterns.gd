extends SceneTree
## Headless: validate the ChunkPatterns section catalog — structure, kinds, band coverage,
## rhythm (tension/breath), layout_errors at every band speed, and director picks.
## Route fairness (a passable line through every section) lives in validate_fairness.gd.

const Patterns = preload("res://scripts/levels/ChunkPatterns.gd")
const Geo = preload("res://scripts/levels/TrackGeometry.gd")

const OBSTACLE_KINDS: Array[String] = [
	Patterns.KIND_LOW, Patterns.KIND_HIGH, Patterns.KIND_GRAVESTONE,
	Patterns.KIND_BLOCK, Patterns.KIND_TRAIN, Patterns.KIND_CART,
]
const SOUL_KINDS: Array[String] = [Patterns.KIND_SOUL, Patterns.KIND_BIG, Patterns.KIND_COFFIN]
const SCENES: Array[String] = [
	"res://scenes/obstacles/ObstacleLow.tscn",
	"res://scenes/obstacles/ObstacleHigh.tscn",
	"res://scenes/obstacles/ObstacleGravestone.tscn",
	"res://scenes/obstacles/ObstacleBlock.tscn",
	"res://scenes/obstacles/ObstacleTrain.tscn",
	"res://scenes/obstacles/ObstacleCart.tscn",
]

var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("FAIL " + msg)
	failed += 1


func _run() -> void:
	var catalog: Array[Dictionary] = Patterns.all_sections()
	print("sections=%d" % catalog.size())
	var kind_counts: Dictionary = {}
	var band_cover: Array[int] = []
	band_cover.resize(Patterns.BAND_COUNT)
	var breath_cover: Array[int] = []
	breath_cover.resize(Patterns.BAND_COUNT)
	var ids: Dictionary = {}
	for sec in catalog:
		var id: String = str(sec["id"])
		if ids.has(id):
			_fail("duplicate id %s" % id)
		ids[id] = true
		var b0: int = int(sec["band_min"])
		var b1: int = int(sec["band_max"])
		if b0 < 0 or b1 >= Patterns.BAND_COUNT or b0 > b1:
			_fail("%s bands %d..%d" % [id, b0, b1])
			continue
		for b in range(b0, b1 + 1):
			band_cover[b] += 1
			if int(sec["intensity"]) <= 1:
				breath_cover[b] += 1
		for b in range(b0, b1 + 1):
			var speeds: Vector2 = Patterns.band_speed_range(b)
			for v in [speeds.x, (speeds.x + speeds.y) * 0.5, speeds.y]:
				var lay: Dictionary = Patterns.build_layout(sec, v)
				for e in Patterns.layout_errors(lay):
					_fail("%s @%.1f: %s" % [id, v, e])
				if float(lay["length"]) <= 45.0:
					_fail("%s shorter than one chunk (%.1f m)" % [id, float(lay["length"])])
				for o in lay["obstacles"]:
					var kind: String = str(o["kind"])
					if not OBSTACLE_KINDS.has(kind):
						_fail("%s unknown obstacle %s" % [id, kind])
					if int(o["lane"]) < 0 or int(o["lane"]) > 2:
						_fail("%s lane %d" % [id, int(o["lane"])])
					kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
					if kind == Patterns.KIND_TRAIN and (int(o["cars"]) < 1 or int(o["cars"]) > Geo.MAX_CARS):
						_fail("%s train cars %d" % [id, int(o["cars"])])
				for s in lay["souls"]:
					if not SOUL_KINDS.has(str(s["kind"])):
						_fail("%s unknown soul %s" % [id, str(s["kind"])])
				if (lay["souls"] as Array).is_empty():
					_fail("%s has no soul trail" % id)
	for k in OBSTACLE_KINDS:
		print("kind %s count=%d" % [k, int(kind_counts.get(k, 0))])
		if int(kind_counts.get(k, 0)) <= 0:
			_fail("kind unused: %s" % k)
	for b in Patterns.BAND_COUNT:
		print("band %d %-7s sections=%d breath=%d" % [b, Patterns.BAND_NAMES[b], band_cover[b], breath_cover[b]])
		if band_cover[b] < 4:
			_fail("band %d has only %d sections" % [b, band_cover[b]])
		if breath_cover[b] < 1:
			_fail("band %d has no breath section" % b)

	for biome in ["graveyard", "haunted_castle"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var history: Array = []
		var tension_run: int = 0
		var prev_intensity: int = 0
		for i in 400:
			var band: int = mini(i / 60, Patterns.BAND_COUNT - 1)
			var sec: Dictionary = Patterns.pick_section(rng, band, biome, history)
			if sec.is_empty():
				_fail("pick empty band=%d biome=%s" % [band, biome])
				break
			var id: String = str(sec["id"])
			if band < int(sec["band_min"]) or band > int(sec["band_max"]):
				_fail("pick %s outside band %d" % [id, band])
			var biomes: PackedStringArray = sec.get("biomes", PackedStringArray())
			if not biomes.is_empty() and not biomes.has(biome):
				_fail("pick %s wrong biome %s" % [id, biome])
			if history.slice(maxi(0, history.size() - 3)).has(id):
				_fail("pick %s repeated within 3" % id)
			var inten: int = int(sec["intensity"])
			if inten >= 3 and prev_intensity >= 3:
				_fail("back-to-back intensity 3 (%s)" % id)
			tension_run = 0 if inten <= 1 else tension_run + 1
			if tension_run > 3:
				_fail("no breath after 3 tension sections (%s)" % id)
			prev_intensity = inten
			history.append(id)
			if history.size() > 12:
				history.pop_front()
		print("director %s: 400 picks OK" % biome)

	for path in SCENES:
		if not ResourceLoader.exists(path):
			_fail("missing %s" % path)
		else:
			print("OK resource ", path)
	if failed > 0:
		push_error("Pattern validation failed: %d" % failed)
		quit(1)
		return
	print("All patterns OK")
	quit(0)
