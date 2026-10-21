extends RefCounted
class_name ChunkPatterns
## Fair Subway Surfers–style chunk pattern catalog (no pits/gaps).
## Each pattern: id, weight, diff_min, diff_max, biomes, obstacles[], souls[].
## Obstacle specs: {kind, lane, z, width?, ramp?, length?}
## Always ≥1 walkable lane; never block all 3 lanes in one Z-band.

const KIND_GRAVESTONE: String = "obstacle_gravestone"
const KIND_LOW: String = "obstacle_low"
const KIND_HIGH: String = "obstacle_high"
const KIND_SIDE: String = "obstacle_side"
const KIND_PLATFORM: String = "obstacle_platform"
const KIND_SOUL: String = "collectible_soul"
const KIND_BIG: String = "collectible_big_soul"
const KIND_COFFIN: String = "collectible_golden_coffin"

## Minimum Z gap between obstacle beats (react time).
const BEAT_GAP: float = 11.0
const SOUL_STEP: float = 2.2


static func all_patterns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	## --- Easy / intro ---
	out.append(_pat(
		"open_line_center", 14, 0, 2, [],
		[],
		_line_souls(1, 12.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"open_line_left", 10, 0, 3, [],
		[],
		_line_souls(0, 10.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"single_high_center_guide_left", 14, 0, 4, [],
		[_obs(KIND_HIGH, 1, 4.0)],
		_line_souls(0, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"single_low_left_guide_right", 13, 0, 5, [],
		[_obs(KIND_LOW, 0, 4.0)],
		_line_souls(2, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"single_grave_right_guide_center", 10, 0, 5, [],
		[_obs(KIND_GRAVESTONE, 2, 2.0)],
		_line_souls(1, 12.0, 4, KIND_SOUL)
	))
	## --- Mid: two-lane gates with one open ---
	out.append(_pat(
		"gate_high_open_center", 15, 1, 8, [],
		[
			_obs(KIND_HIGH, 0, 6.0),
			_obs(KIND_HIGH, 2, 6.0),
		],
		_line_souls(1, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"gate_low_open_left", 12, 1, 9, [],
		[
			_obs(KIND_LOW, 1, 6.0),
			_obs(KIND_LOW, 2, 6.0),
		],
		_line_souls(0, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"gate_mix_open_right", 12, 2, 10, [],
		[
			_obs(KIND_HIGH, 0, 6.0),
			_obs(KIND_LOW, 1, 6.0),
		],
		_line_souls(2, 14.0, 5, KIND_SOUL)
	))
	## --- Slide / jump alternating beats ---
	out.append(_pat(
		"low_then_high_stagger", 12, 2, 12, [],
		[
			_obs(KIND_LOW, 1, 12.0),
			_obs(KIND_HIGH, 0, -2.0),
		],
		_group_souls(2, 6.0, 3, KIND_SOUL)
	))
	out.append(_pat(
		"high_then_low_stagger", 12, 2, 12, [],
		[
			_obs(KIND_HIGH, 1, 12.0),
			_obs(KIND_LOW, 2, -2.0),
		],
		_group_souls(0, 6.0, 3, KIND_SOUL)
	))
	out.append(_pat(
		"stagger_left_high_right_low", 11, 2, 12, [],
		[
			_obs(KIND_HIGH, 0, 12.0),
			_obs(KIND_LOW, 2, -2.0),
		],
		_group_souls(1, 6.0, 3, KIND_SOUL)
	))
	## --- Arc guides past single blocks ---
	out.append(_pat(
		"arc_left_to_center_past_right_high", 11, 2, 10, [],
		[_obs(KIND_HIGH, 2, 0.0)],
		_arc_souls([0, 0, 1, 1, 1], 12.0, KIND_SOUL)
	))
	out.append(_pat(
		"arc_right_to_center_past_left_low", 11, 2, 10, [],
		[_obs(KIND_LOW, 0, 0.0)],
		_arc_souls([2, 2, 1, 1, 1], 12.0, KIND_SOUL)
	))
	## --- Platforms (1–2 lanes, optional ramp) ---
	out.append(_pat(
		"platform_center_ramp", 12, 2, 12, [],
		[_obs(KIND_PLATFORM, 1, 2.0, {"width": 1, "ramp": true, "length": 14.0})],
		_line_souls(1, 16.0, 3, KIND_SOUL) + _line_souls(0, -8.0, 3, KIND_SOUL)
	))
	out.append(_pat(
		"platform_left_jump_on", 10, 3, 14, [],
		[_obs(KIND_PLATFORM, 0, 0.0, {"width": 1, "ramp": false, "length": 14.0})],
		_line_souls(2, 12.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"platform_two_lane_ramp", 10, 4, 16, [],
		[_obs(KIND_PLATFORM, 0, 0.0, {"width": 2, "ramp": true, "length": 16.0})],
		_line_souls(2, 14.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"platform_right_two_lane", 9, 4, 16, [],
		[_obs(KIND_PLATFORM, 1, 0.0, {"width": 2, "ramp": true, "length": 15.0})],
		_line_souls(0, 14.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"platform_then_low_open", 9, 5, 18, [],
		[
			_obs(KIND_PLATFORM, 1, 10.0, {"width": 1, "ramp": true, "length": 12.0}),
			_obs(KIND_LOW, 0, -10.0),
		],
		_line_souls(2, 14.0, 3, KIND_SOUL)
	))
	## --- Side-incoming + open lane ---
	out.append(_pat(
		"side_then_gate_open_center", 8, 5, 20, [],
		[
			_obs(KIND_SIDE, 0, 12.0),
			_obs(KIND_HIGH, 0, -4.0),
			_obs(KIND_HIGH, 2, -4.0),
		],
		_line_souls(1, 14.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"side_right_then_open_left", 8, 5, 20, [],
		[
			_obs(KIND_SIDE, 2, 12.0),
			_obs(KIND_LOW, 1, -4.0),
			_obs(KIND_HIGH, 2, -4.0),
		],
		_line_souls(0, 14.0, 4, KIND_SOUL)
	))
	## --- Rewards ---
	out.append(_pat(
		"big_soul_open_center", 6, 2, 14, [],
		[
			_obs(KIND_HIGH, 0, 4.0),
			_obs(KIND_HIGH, 2, 4.0),
		],
		[_soul(KIND_BIG, 1, 10.0), _soul(KIND_SOUL, 1, 7.8), _soul(KIND_SOUL, 1, 5.6)]
	))
	out.append(_pat(
		"coffin_safe_lane", 3, 4, 20, [],
		[
			_obs(KIND_LOW, 1, 6.0),
			_obs(KIND_HIGH, 2, 6.0),
		],
		[_soul(KIND_COFFIN, 0, 12.0)]
	))
	out.append(_pat(
		"group_after_single_high", 10, 1, 8, [],
		[_obs(KIND_HIGH, 1, 10.0)],
		_group_souls(0, 2.0, 4, KIND_SOUL)
	))
	## --- Harder mixed (still fair) ---
	out.append(_pat(
		"double_stagger_hard", 7, 6, 20, [],
		[
			_obs(KIND_HIGH, 0, 14.0),
			_obs(KIND_HIGH, 1, 14.0),
			_obs(KIND_LOW, 2, 0.0),
			_obs(KIND_GRAVESTONE, 0, 0.0),
		],
		_arc_souls([2, 2, 1, 1, 0], 16.0, KIND_SOUL)
	))
	out.append(_pat(
		"platform_jump_then_high_side", 7, 7, 20, [],
		[
			_obs(KIND_PLATFORM, 0, 10.0, {"width": 1, "ramp": false, "length": 12.0}),
			_obs(KIND_HIGH, 2, -8.0),
		],
		_line_souls(1, 16.0, 3, KIND_SOUL)
	))
	## --- Castle-flavored ---
	out.append(_pat(
		"castle_gate_open_center", 10, 3, 20, PackedStringArray(["haunted_castle"]),
		[
			_obs(KIND_HIGH, 0, 6.0),
			_obs(KIND_HIGH, 2, 6.0),
		],
		_line_souls(1, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"castle_platform_ramp", 8, 4, 20, PackedStringArray(["haunted_castle"]),
		[_obs(KIND_PLATFORM, 1, 0.0, {"width": 1, "ramp": true, "length": 15.0})],
		_line_souls(0, 14.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"castle_arc_into_left", 8, 4, 20, PackedStringArray(["haunted_castle"]),
		[
			_obs(KIND_SIDE, 2, 10.0),
			_obs(KIND_LOW, 1, -6.0),
			_obs(KIND_HIGH, 2, -6.0),
		],
		_arc_souls([1, 1, 0, 0, 0], 14.0, KIND_SOUL)
	))
	_append_mirrored(out)
	return out


static func pick_pattern(
	rng: RandomNumberGenerator,
	difficulty: int,
	biome_id: String
) -> Dictionary:
	var catalog: Array[Dictionary] = all_patterns()
	var eligible: Array[Dictionary] = []
	var total_w: int = 0
	for p in catalog:
		var dmin: int = int(p.get("diff_min", 0))
		var dmax: int = int(p.get("diff_max", 99))
		if difficulty < dmin or difficulty > dmax:
			continue
		var biomes: Variant = p.get("biomes", PackedStringArray())
		if biomes is PackedStringArray and (biomes as PackedStringArray).size() > 0:
			if not (biomes as PackedStringArray).has(biome_id):
				continue
		var w: int = maxi(1, int(p.get("weight", 1)))
		eligible.append(p)
		total_w += w
	if eligible.is_empty():
		return _pat(
			"fallback_open_line", 1, 0, 99, [],
			[],
			_line_souls(1, 10.0, 4, KIND_SOUL)
		)
	var roll: int = rng.randi_range(0, total_w - 1)
	var acc: int = 0
	for p2 in eligible:
		acc += maxi(1, int(p2.get("weight", 1)))
		if roll < acc:
			return p2
	return eligible[eligible.size() - 1]


static func validate_pattern(pattern: Dictionary) -> bool:
	## Never allow a Z-band where lanes 0+1+2 are all blocked (platforms count width).
	var by_z: Dictionary = {}
	var obstacles: Array = pattern.get("obstacles", []) as Array
	for item in obstacles:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		var lane: int = clampi(int(d.get("lane", 0)), 0, 2)
		var width: int = clampi(int(d.get("width", 1)), 1, 2)
		if lane + width - 1 > 2:
			lane = 3 - width
		var z_val: float = float(d.get("z", 0.0))
		## Platforms span length — treat center band + neighbors lightly via wider band.
		var kind: String = str(d.get("kind", ""))
		var span: float = 4.0
		if kind == KIND_PLATFORM:
			span = maxf(6.0, float(d.get("length", 14.0)) * 0.35)
		var band: int = int(floor(z_val / span))
		var mask: int = int(by_z.get(band, 0))
		for i in width:
			mask |= (1 << (lane + i))
		by_z[band] = mask
		if mask == 7:
			return false
	return true


static func _pat(
	id: String,
	weight: int,
	diff_min: int,
	diff_max: int,
	biomes: PackedStringArray,
	obstacles: Array,
	souls: Array
) -> Dictionary:
	return {
		"id": id,
		"weight": weight,
		"diff_min": diff_min,
		"diff_max": diff_max,
		"biomes": biomes,
		"obstacles": obstacles,
		"souls": souls,
	}


static func _obs(kind: String, lane: int, z: float, extras: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {
		"kind": kind,
		"lane": lane,
		"z": z,
		"height_kind": "ground",
		"width": int(extras.get("width", 1)),
	}
	if extras.has("ramp"):
		d["ramp"] = bool(extras["ramp"])
	if extras.has("length"):
		d["length"] = float(extras["length"])
	return d


static func _soul(kind: String, lane: int, z: float) -> Dictionary:
	return {"kind": kind, "lane": lane, "z": z, "height_kind": "float"}


static func _line_souls(lane: int, start_z: float, count: int, kind: String) -> Array:
	var out: Array = []
	for i in count:
		out.append(_soul(kind, lane, start_z - float(i) * SOUL_STEP))
	return out


static func _group_souls(lane: int, center_z: float, count: int, kind: String) -> Array:
	var out: Array = []
	var half: float = float(count - 1) * 0.5
	for i in count:
		out.append(_soul(kind, lane, center_z + (half - float(i)) * SOUL_STEP))
	return out


static func _arc_souls(lanes: Array, start_z: float, kind: String) -> Array:
	var out: Array = []
	for i in lanes.size():
		var lane: int = clampi(int(lanes[i]), 0, 2)
		out.append(_soul(kind, lane, start_z - float(i) * SOUL_STEP))
	return out


static func _mirror_lane(lane: int) -> int:
	return 2 - lane


static func _mirror_spec(spec: Dictionary) -> Dictionary:
	var lane: int = int(spec.get("lane", 1))
	var width: int = clampi(int(spec.get("width", 1)), 1, 2)
	## Mirror left-most lane for multi-lane platforms.
	var mirrored_left: int = _mirror_lane(lane + width - 1)
	var out: Dictionary = {
		"kind": str(spec.get("kind", "")),
		"lane": mirrored_left,
		"z": float(spec.get("z", 0.0)),
		"height_kind": str(spec.get("height_kind", "float")),
		"width": width,
	}
	if spec.has("ramp"):
		out["ramp"] = bool(spec["ramp"])
	if spec.has("length"):
		out["length"] = float(spec["length"])
	return out


static func _append_mirrored(out: Array[Dictionary]) -> void:
	var base: Array[Dictionary] = out.duplicate()
	for p in base:
		var id: String = str(p.get("id", ""))
		if id.begins_with("open_line") or id.begins_with("gate_") and id.contains("center"):
			continue
		if id.contains("center") and not id.contains("left") and not id.contains("right"):
			if not id.contains("guide") and not id.contains("arc") and not id.contains("stagger"):
				continue
		var mobs: Array = []
		for o in (p.get("obstacles", []) as Array):
			if o is Dictionary:
				mobs.append(_mirror_spec(o as Dictionary))
		var msouls: Array = []
		for s in (p.get("souls", []) as Array):
			if s is Dictionary:
				msouls.append(_mirror_spec(s as Dictionary))
		var biomes: PackedStringArray = PackedStringArray()
		var biomes_v: Variant = p.get("biomes", PackedStringArray())
		if biomes_v is PackedStringArray:
			biomes = biomes_v as PackedStringArray
		out.append(_pat(
			id + "_mir",
			maxi(1, int(p.get("weight", 1)) - 2),
			int(p.get("diff_min", 0)),
			int(p.get("diff_max", 99)),
			biomes,
			mobs,
			msouls
		))
