extends RefCounted
class_name ChunkPatterns
## Hand-authored track sections (Subway Surfers style, horror re-theme).
##
## A section is longer than one chunk and is authored in meters at the reference speed
## (START_SPEED). `build_layout(section, speed)` stretches it for the speed it will be run
## at: free-standing beats spread by stretch_for_speed(v) so reaction distance grows with
## speed, while rigid groups (train complexes, roof chains, their soul trails) keep exact
## spacing so roof-to-roof jumps stay physically identical. Soul arcs are generated from the
## real jump trajectory at that speed.
##
## Distance coordinate `d` grows in the run direction (world z = section_start_z - d).
## Fairness is proven offline by RouteSolver (tools/validate_fairness.gd).

const Geo = preload("res://scripts/levels/TrackGeometry.gd")

const KIND_LOW: String = "obstacle_low"
const KIND_HIGH: String = "obstacle_high"
const KIND_GRAVESTONE: String = "obstacle_gravestone"
const KIND_BLOCK: String = "obstacle_block"
const KIND_TRAIN: String = "obstacle_train"
const KIND_CART: String = "obstacle_cart"
const KIND_SOUL: String = "collectible_soul"
const KIND_BIG: String = "collectible_big_soul"
const KIND_COFFIN: String = "collectible_golden_coffin"

const OBSTACLE_KINDS: Array[String] = [KIND_LOW, KIND_HIGH, KIND_GRAVESTONE, KIND_BLOCK, KIND_TRAIN, KIND_CART]

## Difficulty bands by run distance (m). Band speeds follow the PlayerController ramp.
const BAND_DISTANCE: Array[float] = [300.0, 700.0, 1150.0, 1700.0]
const BAND_NAMES: Array[String] = ["warmup", "easy", "medium", "hard", "expert"]
const BAND_COUNT: int = 5

## Clear run-up at the start of every section (reference meters, stretched).
const LEAD_IN: float = 12.0
const TAIL_CLEAR: float = 3.0
const SOUL_STEP: float = 2.4
const LOW_SOUL_Y: float = -0.55
const STRETCH_EXP: float = 0.7
const STRETCH_MAX: float = 2.0

## Rhythm: after this many non-breath sections in a row, force a breath section.
const MAX_TENSION_RUN: int = 3

static var _catalog: Array[Dictionary] = []


# --- Bands / speed ---------------------------------------------------------------

static func band_for_distance(dist: float) -> int:
	for i in BAND_DISTANCE.size():
		if dist < BAND_DISTANCE[i]:
			return i
	return BAND_COUNT - 1


static func band_speed_range(band: int) -> Vector2:
	var b: int = clampi(band, 0, BAND_COUNT - 1)
	var lo: float = Geo.START_SPEED if b == 0 else Geo.speed_at_distance(BAND_DISTANCE[b - 1])
	var hi: float = Geo.MAX_SPEED if b >= BAND_DISTANCE.size() else Geo.speed_at_distance(BAND_DISTANCE[b])
	return Vector2(lo, hi)


static func stretch_for_speed(v: float) -> float:
	return clampf(pow(maxf(v, Geo.START_SPEED) / Geo.START_SPEED, STRETCH_EXP), 1.0, STRETCH_MAX)


# --- Catalog -------------------------------------------------------------------------

static func all_sections() -> Array[Dictionary]:
	if _catalog.is_empty():
		_catalog = _build_catalog()
	return _catalog


static func find_section(id: String) -> Dictionary:
	for s in all_sections():
		if str(s["id"]) == id:
			return s
	return {}


static func _build_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	const L := 0
	const C := 1
	const R := 2

	# ---------------- Warm-up / teaching ----------------
	out.append(_sec("first_steps", 0, 0, 4, 1, 62.0, [
		_line(C, 13.0, 5),
		_obs(KIND_LOW, C, 32.0), _arc(C, 32.0),
		_line(C, 40.0, 3),
		_obs(KIND_HIGH, L, 52.0), _obs(KIND_HIGH, R, 52.0),
		_line(C, 46.0, 5),
	], [], false))

	out.append(_sec("roll_school", 0, 1, 4, 2, 72.0, [
		_line(C, 12.0, 3),
		_obs(KIND_HIGH, C, 23.0), _line(C, 20.6, 3, LOW_SOUL_Y),
		_obs(KIND_BLOCK, L, 40.0), _obs(KIND_BLOCK, R, 40.0),
		_line(C, 33.0, 4),
		_obs(KIND_LOW, L, 57.0), _obs(KIND_LOW, C, 57.0), _obs(KIND_LOW, R, 57.0),
		_arc(C, 57.0),
	], [], false))

	out.append(_sec("lane_weave", 0, 2, 4, 2, 80.0, [
		_obs(KIND_BLOCK, C, 20.0),
		_zig([C, C, L, L, L], 9.0),
		_obs(KIND_LOW, L, 34.0), _arc(L, 34.0),
		_obs(KIND_BLOCK, L, 52.0), _obs(KIND_HIGH, C, 52.0),
		_zig([L, C, R, R, R], 39.0),
		_obs(KIND_BLOCK, R, 68.0),
		_zig([R, C, C, C], 58.0),
	]))

	out.append(_sec("first_hearse", 0, 2, 4, 2, 82.0, [
		_train(C, 22.0, 2, true, "t"), _ride(C, 22.0, 2, true, "t"),
		_obs(KIND_LOW, L, 30.0), _obs(KIND_LOW, R, 30.0),
		_obs(KIND_GRAVESTONE, L, 62.0), _obs(KIND_GRAVESTONE, R, 62.0),
		_line(C, 52.0, 4),
		_obs(KIND_HIGH, C, 74.0), _line(C, 71.6, 3, LOW_SOUL_Y),
	], [], false))

	# ---------------- Breath sections (all bands) ----------------
	out.append(_sec("soul_road", 0, 4, 3, 1, 60.0, [
		_zig([C, C, C, L, L, L, C, C, C, R, R, R, C, C], 12.0),
		_soul(KIND_BIG, C, 50.0),
	], [], false))

	out.append(_sec("graveside_rest", 0, 4, 3, 1, 56.0, [
		_line(L, 12.0, 6),
		_obs(KIND_GRAVESTONE, C, 28.0), _obs(KIND_GRAVESTONE, R, 32.0),
		_zig([L, C, C, C, C], 30.0),
		_soul(KIND_BIG, C, 46.0),
	]))

	out.append(_sec("lantern_rest", 1, 4, 3, 1, 58.0, [
		_obs(KIND_BLOCK, L, 24.0), _obs(KIND_BLOCK, R, 24.0),
		_line(C, 14.0, 4), _soul(KIND_BIG, C, 24.0),
		_zig([C, R, R, R, R], 32.0),
		_obs(KIND_LOW, R, 50.0), _arc(R, 50.0),
	]))

	# ---------------- Easy / medium ----------------
	out.append(_sec("hearse_procession", 1, 3, 4, 3, 86.0, [
		_train(C, 20.0, 2, true, "p"), _ride(C, 20.0, 2, true, "p"),
		_train(L, 30.0, 3, false, "p"), _line(L, 41.0, 7, Geo.TRAIN_ROOF, "p"),
		_obs(KIND_LOW, R, 28.0),
		_obs(KIND_BLOCK, R, 50.0),
		_obs(KIND_HIGH, C, 68.0),
		_obs(KIND_LOW, L, 76.0),
	]))

	out.append(_sec("roof_hop", 1, 4, 4, 3, 90.0, [
		_train(C, 18.0, 2, true, "h"), _ride(C, 18.0, 2, true, "h"),
		_arc(C, 38.8, Geo.TRAIN_ROOF, "h"),
		_train(C, 40.8, 2, false, "h"), _line(C, 43.5, 7, Geo.TRAIN_ROOF, "h"),
		_arc(C, 61.6, Geo.TRAIN_ROOF, "h"),
		_train(C, 63.6, 1, false, "h"), _line(C, 66.0, 3, Geo.TRAIN_ROOF, "h"),
		_obs(KIND_BLOCK, L, 32.0), _obs(KIND_LOW, L, 56.0),
		_obs(KIND_HIGH, R, 42.0), _obs(KIND_BLOCK, R, 68.0),
	]))

	out.append(_sec("crypt_maze", 1, 3, 4, 3, 84.0, [
		_obs(KIND_BLOCK, L, 15.0), _obs(KIND_BLOCK, C, 15.0),
		_zig([C, R, R, R], 6.0),
		_obs(KIND_BLOCK, R, 29.0), _obs(KIND_LOW, C, 29.0),
		_zig([R, C], 21.0), _arc(C, 29.0),
		_obs(KIND_BLOCK, C, 43.0), _obs(KIND_HIGH, L, 43.0),
		_zig([C, R, R], 36.0),
		_obs(KIND_LOW, L, 57.0), _obs(KIND_LOW, C, 57.0), _obs(KIND_LOW, R, 57.0),
		_arc(R, 57.0),
		_obs(KIND_BLOCK, L, 71.0), _obs(KIND_BLOCK, R, 71.0),
		_zig([R, C, C, C], 63.0),
	]))

	out.append(_sec("cart_alley", 1, 4, 3, 2, 96.0, [
		_obs(KIND_HIGH, L, 20.0), _obs(KIND_LOW, R, 20.0),
		_line(C, 13.0, 5),
		_zig([C, L, L, L], 26.0),
		_obs(KIND_BLOCK, R, 46.0),
		_obs(KIND_LOW, L, 58.0), _arc(L, 58.0),
		_line(L, 64.0, 4),
		_obs(KIND_CART, C, 88.0),
	]))

	out.append(_sec("barrier_rhythm", 1, 4, 3, 2, 86.0, [
		_obs(KIND_LOW, L, 16.0), _obs(KIND_LOW, C, 16.0), _obs(KIND_LOW, R, 16.0),
		_arc(C, 16.0),
		_obs(KIND_HIGH, L, 30.0), _obs(KIND_HIGH, C, 30.0), _obs(KIND_BLOCK, R, 30.0),
		_line(C, 27.6, 3, LOW_SOUL_Y),
		_obs(KIND_LOW, L, 44.0), _obs(KIND_BLOCK, C, 44.0), _obs(KIND_HIGH, R, 44.0),
		_zig([C, L], 36.0), _arc(L, 44.0),
		_obs(KIND_BLOCK, L, 58.0), _obs(KIND_LOW, C, 58.0), _obs(KIND_LOW, R, 58.0),
		_zig([L, C], 50.0), _arc(C, 58.0),
		_obs(KIND_HIGH, L, 72.0), _obs(KIND_HIGH, C, 72.0), _obs(KIND_HIGH, R, 72.0),
		_line(C, 69.6, 3, LOW_SOUL_Y),
	]))

	# ---------------- Medium / hard ----------------
	out.append(_sec("funeral_express", 2, 4, 4, 3, 118.0, [
		_train(R, 18.0, 4, true, "f"), _ride(R, 18.0, 2, true, "f"),
		_train(C, 48.0, 3, false, "f"), _line(C, 53.0, 8, Geo.TRAIN_ROOF, "f"),
		_train(L, 70.0, 4, false, "f"), _line(L, 76.0, 6, Geo.TRAIN_ROOF, "f"),
		_soul(KIND_COFFIN, L, 94.0, Geo.TRAIN_ROOF, "f"), _line(L, 98.0, 3, Geo.TRAIN_ROOF, "f"),
		_obs(KIND_LOW, L, 28.0, "f"), _obs(KIND_HIGH, L, 48.0, "f"),
		_obs(KIND_LOW, R, 74.0, "f"), _obs(KIND_HIGH, R, 96.0, "f"),
	]))

	out.append(_sec("skybridge", 2, 4, 3, 3, 108.0, [
		_train(L, 18.0, 2, true, "s"), _ride(L, 18.0, 1, true, "s"),
		_train(C, 32.0, 2, false, "s"), _line(C, 35.0, 6, Geo.TRAIN_ROOF, "s"),
		_arc(C, 52.8, Geo.TRAIN_ROOF, "s"),
		_train(C, 54.8, 2, false, "s"), _line(C, 57.0, 4, Geo.TRAIN_ROOF, "s"),
		_train(R, 68.0, 3, false, "s"), _line(R, 70.0, 10, Geo.TRAIN_ROOF, "s"),
		_obs(KIND_BLOCK, R, 34.0, "s"), _obs(KIND_LOW, R, 50.0, "s"),
		_obs(KIND_HIGH, L, 52.0, "s"), _obs(KIND_BLOCK, L, 74.0, "s"), _obs(KIND_LOW, L, 94.0, "s"),
	]))

	out.append(_sec("twin_carts", 2, 4, 3, 3, 112.0, [
		_line(C, 14.0, 4),
		_obs(KIND_HIGH, C, 36.0), _line(C, 33.6, 3, LOW_SOUL_Y),
		_obs(KIND_LOW, C, 58.0), _arc(C, 58.0),
		_obs(KIND_HIGH, C, 82.0), _line(C, 79.6, 3, LOW_SOUL_Y),
		_obs(KIND_CART, L, 72.0),
		_obs(KIND_CART, R, 104.0),
	], [], false))

	out.append(_sec("coffin_heist", 2, 4, 2, 2, 90.0, [
		_train(C, 20.0, 3, true, "c"), _ride(C, 20.0, 2, true, "c"),
		_soul(KIND_COFFIN, C, 44.0, Geo.TRAIN_ROOF, "c"), _line(C, 47.0, 6, Geo.TRAIN_ROOF, "c"),
		_obs(KIND_BLOCK, L, 32.0), _obs(KIND_BLOCK, R, 32.0),
		_obs(KIND_LOW, L, 56.0), _obs(KIND_HIGH, R, 56.0),
		_obs(KIND_BLOCK, C, 78.0),
	], [], false))

	out.append(_sec("gauntlet", 3, 4, 3, 3, 112.0, [
		_obs(KIND_LOW, L, 14.0), _obs(KIND_HIGH, C, 14.0), _obs(KIND_BLOCK, R, 14.0),
		_arc(L, 14.0),
		_obs(KIND_BLOCK, L, 29.0), _obs(KIND_LOW, C, 29.0), _obs(KIND_LOW, R, 29.0),
		_zig([L, C], 20.0), _arc(C, 29.0),
		_obs(KIND_HIGH, L, 44.0), _obs(KIND_BLOCK, C, 44.0), _obs(KIND_HIGH, R, 44.0),
		_line(R, 41.6, 3, LOW_SOUL_Y),
		_obs(KIND_LOW, L, 59.0), _obs(KIND_LOW, C, 59.0), _obs(KIND_LOW, R, 59.0),
		_arc(R, 59.0),
		_obs(KIND_BLOCK, L, 74.0), _obs(KIND_BLOCK, C, 74.0), _obs(KIND_HIGH, R, 74.0),
		_line(R, 71.6, 3, LOW_SOUL_Y),
		_obs(KIND_LOW, R, 89.0), _obs(KIND_BLOCK, C, 89.0), _obs(KIND_LOW, L, 89.0),
		_arc(R, 89.0),
		_obs(KIND_HIGH, L, 104.0), _obs(KIND_HIGH, C, 104.0), _obs(KIND_BLOCK, R, 104.0),
		_zig([R, C], 94.0), _line(C, 101.6, 3, LOW_SOUL_Y),
	]))

	# ---------------- Castle flavour ----------------
	out.append(_sec("portcullis_hall", 1, 4, 3, 2, 84.0, [
		_obs(KIND_HIGH, L, 18.0), _obs(KIND_HIGH, C, 18.0), _obs(KIND_HIGH, R, 18.0),
		_line(C, 15.6, 3, LOW_SOUL_Y),
		_obs(KIND_BLOCK, C, 34.0), _obs(KIND_LOW, L, 34.0), _obs(KIND_LOW, R, 34.0),
		_zig([C, L], 26.0), _arc(L, 34.0),
		_train(C, 54.0, 2, true, "w"), _ride(C, 54.0, 2, true, "w"),
		_obs(KIND_HIGH, L, 60.0), _obs(KIND_HIGH, R, 66.0),
	], PackedStringArray(["haunted_castle"]), false))

	out.append(_sec("wagon_hall", 2, 4, 3, 3, 112.0, [
		_train(L, 30.0, 4, true, "g"), _ride(L, 30.0, 3, true, "g"),
		_train(R, 36.0, 3, true, "g"),
		_line(C, 14.0, 4),
		_zig([C, L], 22.0),
		_obs(KIND_CART, C, 104.0),
		_obs(KIND_LOW, L, 84.0), _obs(KIND_LOW, R, 84.0),
	], PackedStringArray(["haunted_castle"])))

	_append_mirrored(out)
	return out


# --- Director --------------------------------------------------------------------

## Weighted pick with rhythm: breath sections after tension runs, no immediate repeats.
static func pick_section(
	rng: RandomNumberGenerator,
	band: int,
	biome_id: String,
	history: Array = []
) -> Dictionary:
	var tension_run: int = 0
	for i in range(history.size() - 1, -1, -1):
		var past: Dictionary = find_section(str(history[i]))
		if past.is_empty() or int(past.get("intensity", 1)) <= 1:
			break
		tension_run += 1
	var last_int: int = 1
	if not history.is_empty():
		last_int = int(find_section(str(history[history.size() - 1])).get("intensity", 1))
	var recent: Array = history.slice(maxi(0, history.size() - 3))
	var eligible: Array[Dictionary] = []
	var total_w: int = 0
	for pass_i in 3:
		eligible.clear()
		total_w = 0
		for s in all_sections():
			if band < int(s["band_min"]) or band > int(s["band_max"]):
				continue
			var biomes: PackedStringArray = s["biomes"]
			if biomes.size() > 0 and not biomes.has(biome_id):
				continue
			var inten: int = int(s["intensity"])
			if pass_i < 2:
				if tension_run >= MAX_TENSION_RUN and inten > 1:
					continue
				if last_int >= 3 and inten >= 3:
					continue
			if pass_i < 1 and (recent.has(s["id"]) or recent.has(s["base_id"])):
				continue
			eligible.append(s)
			total_w += int(s["weight"])
		if not eligible.is_empty():
			break
	if eligible.is_empty():
		return find_section("soul_road")
	var roll: int = rng.randi_range(0, total_w - 1)
	for s in eligible:
		roll -= int(s["weight"])
		if roll < 0:
			return s
	return eligible[eligible.size() - 1]


# --- Layout ------------------------------------------------------------------------

## Expand a section into concrete obstacles / souls for running speed `v`.
static func build_layout(section: Dictionary, v: float) -> Dictionary:
	var k: float = stretch_for_speed(v)
	var items: Array = section["items"]
	var anchors: Dictionary = {}
	for it in items:
		var g: String = str(it.get("g", ""))
		if g != "":
			anchors[g] = minf(float(anchors.get(g, INF)), _item_min_d(it))
	var obstacles: Array = []
	var souls: Array = []
	for it in items:
		var g: String = str(it.get("g", ""))
		var t: String = str(it["t"])
		var d0: float = float(it.get("d", 0.0))
		var d: float = d0 * k
		if g != "":
			var a: float = float(anchors[g])
			d = a * k + (d0 - a)
		match t:
			"obs":
				obstacles.append(_make_obstacle(str(it["kind"]), int(it["lane"]), d, it))
			"line":
				var step: float = SOUL_STEP if g != "" else SOUL_STEP * k
				for i in int(it["n"]):
					souls.append(_soul_out(KIND_SOUL, int(it["lane"]), d + float(i) * step, float(it.get("y", 0.0))))
			"zig":
				var zstep: float = SOUL_STEP if g != "" else SOUL_STEP * k
				var lanes: Array = it["lanes"]
				for i in lanes.size():
					souls.append(_soul_out(KIND_SOUL, int(lanes[i]), d + float(i) * zstep, 0.0))
			"arc":
				souls.append_array(_arc_souls(int(it["lane"]), d, v, float(it.get("y", 0.0))))
			"ride":
				souls.append_array(_ride_souls(int(it["lane"]), d, int(it["cars"]), bool(it["ramp"])))
			"soul":
				souls.append(_soul_out(str(it["kind"]), int(it["lane"]), d, float(it.get("y", 0.0))))
	var layout: Dictionary = {
		"id": section["id"],
		"length": float(section["length"]) * k,
		"speed": v,
		"stretch": k,
		"intensity": section["intensity"],
		"obstacles": obstacles,
		"souls": souls,
	}
	layout["powerup_slots"] = _powerup_slots(layout)
	return layout


static func _make_obstacle(kind: String, lane: int, d: float, it: Dictionary) -> Dictionary:
	var o: Dictionary = {"kind": kind, "lane": lane, "d": d}
	match kind:
		KIND_TRAIN:
			var cars: int = int(it.get("cars", 2))
			o["cars"] = cars
			o["ramp"] = bool(it.get("ramp", false))
			o["d0"] = d
			o["d1"] = d + Geo.train_length(cars)
			o["ramp_d0"] = d - Geo.RAMP_LEN if o["ramp"] else d
		KIND_CART:
			o["d0"] = d - Geo.CART_LEN * 0.5
			o["d1"] = d + Geo.CART_LEN * 0.5
		_:
			var depth: float = obstacle_depth(kind)
			o["d0"] = d - depth * 0.5
			o["d1"] = d + depth * 0.5
	return o


static func obstacle_depth(kind: String) -> float:
	match kind:
		KIND_LOW:
			return Geo.LOW_DEPTH
		KIND_HIGH:
			return Geo.HIGH_DEPTH
		KIND_GRAVESTONE:
			return Geo.GRAVE_DEPTH
		KIND_BLOCK:
			return Geo.BLOCK_DEPTH
		KIND_CART:
			return Geo.CART_LEN
	return 1.0


## Distance the cart has rolled toward the player when they meet, at speed v.
static func cart_travel(v: float) -> float:
	return Geo.CART_SPEED * Geo.CART_TRIGGER / (v + Geo.CART_SPEED)


static func _soul_out(kind: String, lane: int, d: float, y: float) -> Dictionary:
	return {"kind": kind, "lane": clampi(lane, 0, 2), "d": d, "y": y}


static func _arc_souls(lane: int, center: float, v: float, base_y: float) -> Array:
	var air: float = Geo.jump_air_time()
	var span: float = v * air
	var n: int = clampi(int(round(span / 2.4)), 4, 7)
	var start: float = center - span * 0.5
	var out: Array = []
	for i in n:
		var f: float = (float(i) + 0.5) / float(n)
		var t: float = f * air
		out.append(_soul_out(KIND_SOUL, lane, start + v * t, base_y + Geo.jump_height(t) * 0.9))
	return out


static func _ride_souls(lane: int, front: float, cars_with_souls: int, ramp: bool) -> Array:
	var out: Array = []
	var d: float = front - (Geo.RAMP_LEN - 1.0 if ramp else -1.5)
	var end_d: float = front + Geo.train_length(cars_with_souls) - 1.0
	while d <= end_d:
		var y: float = Geo.TRAIN_ROOF
		if d < front:
			y = Geo.TRAIN_ROOF * (1.0 - (front - d) / Geo.RAMP_LEN)
		out.append(_soul_out(KIND_SOUL, lane, d, y))
		d += SOUL_STEP
	return out


static func _powerup_slots(layout: Dictionary) -> Array:
	var slots: Array = []
	var length: float = float(layout["length"])
	for frac in [0.3, 0.55, 0.8]:
		var d: float = length * frac
		for lane in [1, 0, 2]:
			if lane_clear(layout, lane, d - 8.0, d + 8.0) and not _soul_near(layout, lane, d, 2.0):
				slots.append({"lane": lane, "d": d})
				break
	return slots


## True when no obstacle (incl. ramps and a cart's rolling corridor) touches [a, b] in lane.
static func lane_clear(layout: Dictionary, lane: int, a: float, b: float) -> bool:
	for o in layout["obstacles"]:
		if int(o["lane"]) != lane:
			continue
		var lo: float = float(o.get("ramp_d0", o["d0"]))
		if str(o["kind"]) == KIND_CART:
			lo -= Geo.CART_TRIGGER
		if lo <= b and float(o["d1"]) >= a:
			return false
	return true


static func _soul_near(layout: Dictionary, lane: int, d: float, r: float) -> bool:
	for s in layout["souls"]:
		if int(s["lane"]) == lane and absf(float(s["d"]) - d) < r:
			return true
	return false


static func soul_value(layout: Dictionary, big_value: int = 5, coffin_value: int = 25) -> int:
	var v: int = 0
	for s in layout["souls"]:
		match str(s["kind"]):
			KIND_BIG:
				v += big_value
			KIND_COFFIN:
				v += coffin_value
			_:
				v += 1
	return v


# --- Static checks ------------------------------------------------------------------

## Structural problems in a built layout ("" list = ok). Fairness itself: RouteSolver.
static func layout_errors(layout: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var id: String = str(layout["id"])
	var length: float = float(layout["length"])
	var k: float = float(layout["stretch"])
	var v: float = float(layout["speed"])
	var obs: Array = layout["obstacles"]
	for o in obs:
		var lane: int = int(o["lane"])
		var kind: String = str(o["kind"])
		if lane < 0 or lane > 2:
			errs.append("%s: lane %d out of range" % [id, lane])
		if not OBSTACLE_KINDS.has(kind):
			errs.append("%s: unknown kind %s" % [id, kind])
		var lo: float = float(o.get("ramp_d0", o["d0"]))
		if kind == KIND_CART:
			lo = float(o["d0"]) - cart_travel(v)
		if lo < LEAD_IN * k - 0.01:
			errs.append("%s: %s lane %d starts at %.1f inside lead-in %.1f" % [id, kind, lane, lo, LEAD_IN * k])
		if float(o["d1"]) > length - TAIL_CLEAR:
			errs.append("%s: %s lane %d ends at %.1f past section end %.1f" % [id, kind, lane, float(o["d1"]), length])
	for i in obs.size():
		for j in range(i + 1, obs.size()):
			var a: Dictionary = obs[i]
			var b: Dictionary = obs[j]
			if int(a["lane"]) != int(b["lane"]):
				continue
			var a_lo: float = _blocking_lo(a, v)
			var b_lo: float = _blocking_lo(b, v)
			if a_lo < float(b["d1"]) + 1.0 and b_lo < float(a["d1"]) + 1.0:
				errs.append("%s: %s and %s overlap in lane %d (v=%.1f)" % [id, a["kind"], b["kind"], int(a["lane"]), v])
	for s in layout["souls"]:
		var sl: int = int(s["lane"])
		var sd: float = float(s["d"])
		var sy: float = Geo.SOUL_FLOAT_Y + float(s["y"])
		for o in obs:
			if int(o["lane"]) != sl:
				continue
			var kind: String = str(o["kind"])
			if kind == KIND_CART:
				if sd > float(o["d0"]) - cart_travel(Geo.START_SPEED) - 3.0 and sd < float(o["d1"]) + 1.0:
					errs.append("%s: soul in cart corridor lane %d d=%.1f" % [id, sl, sd])
				continue
			if kind == KIND_TRAIN:
				if sd > float(o["d0"]) - 0.3 and sd < float(o["d1"]) + 0.3 and sy < Geo.TRAIN_ROOF + 0.3:
					errs.append("%s: soul inside train lane %d d=%.1f" % [id, sl, sd])
				continue
			var band: Vector2 = solid_band(kind)
			if sd > float(o["d0"]) - 0.35 and sd < float(o["d1"]) + 0.35 and sy + 0.3 > band.x and sy - 0.3 < band.y:
				errs.append("%s: soul inside %s lane %d d=%.1f" % [id, kind, sl, sd])
	return errs


static func _blocking_lo(o: Dictionary, v: float) -> float:
	if str(o["kind"]) == KIND_CART:
		return float(o["d0"]) - cart_travel(v) - 4.0
	return float(o.get("ramp_d0", o["d0"]))


## Vertical solid range of a static ground obstacle (lane-centred player).
static func solid_band(kind: String) -> Vector2:
	match kind:
		KIND_LOW:
			return Vector2(Geo.LOW_BOTTOM, Geo.LOW_TOP)
		KIND_HIGH:
			return Vector2(Geo.HIGH_BOTTOM, Geo.HIGH_TOP)
		KIND_GRAVESTONE:
			return Vector2(0.0, Geo.GRAVE_TOP)
		KIND_BLOCK:
			return Vector2(0.0, Geo.BLOCK_TOP)
		KIND_CART:
			return Vector2(0.0, Geo.CART_TOP)
		KIND_TRAIN:
			return Vector2(0.0, Geo.TRAIN_HAZARD_TOP)
	return Vector2(0.0, 3.0)


# --- Authoring helpers ------------------------------------------------------------

static func _sec(id: String, band_min: int, band_max: int, weight: int, intensity: int, length: float,
		items: Array, biomes: PackedStringArray = PackedStringArray(), mirror: bool = true) -> Dictionary:
	return {
		"id": id, "base_id": id, "band_min": band_min, "band_max": band_max, "weight": weight,
		"intensity": intensity, "length": length, "items": items, "biomes": biomes, "mirror": mirror,
	}


static func _obs(kind: String, lane: int, d: float, g: String = "") -> Dictionary:
	return {"t": "obs", "kind": kind, "lane": lane, "d": d, "g": g}


static func _train(lane: int, d: float, cars: int, ramp: bool, g: String) -> Dictionary:
	return {"t": "obs", "kind": KIND_TRAIN, "lane": lane, "d": d, "cars": cars, "ramp": ramp, "g": g}


static func _line(lane: int, d: float, n: int, y: float = 0.0, g: String = "") -> Dictionary:
	return {"t": "line", "lane": lane, "d": d, "n": n, "y": y, "g": g}


static func _zig(lanes: Array, d: float, g: String = "") -> Dictionary:
	return {"t": "zig", "lanes": lanes, "d": d, "g": g}


static func _arc(lane: int, d: float, y: float = 0.0, g: String = "") -> Dictionary:
	return {"t": "arc", "lane": lane, "d": d, "y": y, "g": g}


static func _ride(lane: int, front: float, cars_with_souls: int, ramp: bool, g: String) -> Dictionary:
	return {"t": "ride", "lane": lane, "d": front, "cars": cars_with_souls, "ramp": ramp, "g": g}


static func _soul(kind: String, lane: int, d: float, y: float = 0.0, g: String = "") -> Dictionary:
	return {"t": "soul", "kind": kind, "lane": lane, "d": d, "y": y, "g": g}


## Group anchor uses the earliest point an item occupies (ramps start before the train).
static func _item_min_d(it: Dictionary) -> float:
	var d: float = float(it.get("d", 0.0))
	if str(it.get("kind", "")) == KIND_TRAIN and bool(it.get("ramp", false)):
		return d - Geo.RAMP_LEN
	if str(it.get("t", "")) == "ride" and bool(it.get("ramp", false)):
		return d - Geo.RAMP_LEN
	return d


static func _append_mirrored(out: Array[Dictionary]) -> void:
	var base: Array[Dictionary] = out.duplicate()
	for s in base:
		if not bool(s["mirror"]):
			continue
		var items: Array = []
		for it in s["items"]:
			var m: Dictionary = (it as Dictionary).duplicate(true)
			if m.has("lane"):
				m["lane"] = 2 - int(m["lane"])
			if m.has("lanes"):
				var ml: Array = []
				for ln in m["lanes"]:
					ml.append(2 - int(ln))
				m["lanes"] = ml
			items.append(m)
		var copy: Dictionary = s.duplicate()
		copy["id"] = str(s["id"]) + "_mir"
		copy["items"] = items
		copy["mirror"] = false
		out.append(copy)
