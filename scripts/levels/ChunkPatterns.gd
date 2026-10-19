extends RefCounted
class_name ChunkPatterns
## Fair Subway Surfers–style chunk pattern catalog.
## Each pattern is a Dictionary:
##   id, weight, diff_min, diff_max, biomes (PackedStringArray, empty = all),
##   obstacles: Array[{kind, lane, z}],
##   souls: Array[{kind, lane, z}],
## Lanes are always 0/1/2 → X [-2.5, 0, 2.5]. Patterns never block all 3 lanes.

const KIND_GRAVESTONE: String = "obstacle_gravestone"
const KIND_PIT: String = "obstacle_pit"
const KIND_SIDE: String = "obstacle_side"
const KIND_SOUL: String = "collectible_soul"
const KIND_BIG: String = "collectible_big_soul"
const KIND_COFFIN: String = "collectible_golden_coffin"

## Minimum Z gap between obstacle "beats" inside one pattern (readability).
const BEAT_GAP: float = 10.0
## Soul spacing along a line / arc.
const SOUL_STEP: float = 2.2


static func all_patterns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	## --- Easy / intro ---
	out.append(_pat(
		"open_line_center", 12, 0, 2, [],
		[],
		_line_souls(1, 12.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"open_line_left", 10, 0, 3, [],
		[],
		_line_souls(0, 10.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"single_block_center_guide_left", 14, 0, 4, [],
		[_obs(KIND_GRAVESTONE, 1, 4.0)],
		_line_souls(0, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"single_block_left_guide_right", 14, 0, 4, [],
		[_obs(KIND_GRAVESTONE, 0, 4.0)],
		_line_souls(2, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"single_block_right_guide_center", 12, 0, 5, [],
		[_obs(KIND_GRAVESTONE, 2, 2.0)],
		_line_souls(1, 12.0, 4, KIND_SOUL)
	))
	## --- Mid: two-lane blocks with one open ---
	out.append(_pat(
		"gate_open_center", 16, 1, 8, [],
		[
			_obs(KIND_GRAVESTONE, 0, 6.0),
			_obs(KIND_GRAVESTONE, 2, 6.0),
		],
		_line_souls(1, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"gate_open_left", 14, 1, 8, [],
		[
			_obs(KIND_GRAVESTONE, 1, 6.0),
			_obs(KIND_GRAVESTONE, 2, 6.0),
		],
		_line_souls(0, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"gate_open_right", 14, 1, 8, [],
		[
			_obs(KIND_GRAVESTONE, 0, 6.0),
			_obs(KIND_GRAVESTONE, 1, 6.0),
		],
		_line_souls(2, 14.0, 5, KIND_SOUL)
	))
	## --- Arc / lane-transition soul guides ---
	out.append(_pat(
		"arc_left_to_center_past_right_block", 12, 2, 9, [],
		[_obs(KIND_GRAVESTONE, 2, 0.0)],
		_arc_souls([0, 0, 1, 1, 1], 12.0, KIND_SOUL)
	))
	out.append(_pat(
		"arc_right_to_center_past_left_block", 12, 2, 9, [],
		[_obs(KIND_GRAVESTONE, 0, 0.0)],
		_arc_souls([2, 2, 1, 1, 1], 12.0, KIND_SOUL)
	))
	out.append(_pat(
		"arc_center_to_left_into_gate", 11, 2, 10, [],
		[
			_obs(KIND_GRAVESTONE, 1, -6.0),
			_obs(KIND_GRAVESTONE, 2, -6.0),
		],
		_arc_souls([1, 1, 0, 0, 0], 12.0, KIND_SOUL)
	))
	out.append(_pat(
		"arc_center_to_right_into_gate", 11, 2, 10, [],
		[
			_obs(KIND_GRAVESTONE, 0, -6.0),
			_obs(KIND_GRAVESTONE, 1, -6.0),
		],
		_arc_souls([1, 1, 2, 2, 2], 12.0, KIND_SOUL)
	))
	## --- Two-beat stagger (react gap) ---
	out.append(_pat(
		"stagger_left_then_right", 13, 2, 12, [],
		[
			_obs(KIND_GRAVESTONE, 0, 10.0),
			_obs(KIND_GRAVESTONE, 2, -4.0),
		],
		_group_souls(1, 4.0, 3, KIND_SOUL)
	))
	out.append(_pat(
		"stagger_right_then_left", 13, 2, 12, [],
		[
			_obs(KIND_GRAVESTONE, 2, 10.0),
			_obs(KIND_GRAVESTONE, 0, -4.0),
		],
		_group_souls(1, 4.0, 3, KIND_SOUL)
	))
	out.append(_pat(
		"stagger_center_then_side", 10, 3, 14, [],
		[
			_obs(KIND_PIT, 1, 10.0),
			_obs(KIND_GRAVESTONE, 0, -4.0),
		],
		_line_souls(2, 14.0, 4, KIND_SOUL)
	))
	## --- Pit readable (jump later; still dodgeable by lane) ---
	out.append(_pat(
		"pit_left_line_center", 10, 2, 10, [],
		[_obs(KIND_PIT, 0, 4.0)],
		_line_souls(1, 12.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"pit_right_line_center", 10, 2, 10, [],
		[_obs(KIND_PIT, 2, 4.0)],
		_line_souls(1, 12.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"pit_center_line_left", 9, 3, 12, [],
		[_obs(KIND_PIT, 1, 2.0)],
		_line_souls(0, 12.0, 4, KIND_SOUL)
	))
	## --- Short soul groups on open lanes ---
	out.append(_pat(
		"group_after_single", 11, 1, 8, [],
		[_obs(KIND_GRAVESTONE, 1, 10.0)],
		_group_souls(0, 2.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"group_open_right_after_gate", 10, 2, 9, [],
		[
			_obs(KIND_GRAVESTONE, 0, 8.0),
			_obs(KIND_GRAVESTONE, 1, 8.0),
		],
		_group_souls(2, 0.0, 4, KIND_SOUL)
	))
	## --- Rewards ---
	out.append(_pat(
		"big_soul_open_center", 6, 2, 14, [],
		[
			_obs(KIND_GRAVESTONE, 0, 4.0),
			_obs(KIND_GRAVESTONE, 2, 4.0),
		],
		[_soul(KIND_BIG, 1, 10.0), _soul(KIND_SOUL, 1, 7.8), _soul(KIND_SOUL, 1, 5.6)]
	))
	out.append(_pat(
		"coffin_safe_lane", 3, 4, 20, [],
		[
			_obs(KIND_GRAVESTONE, 1, 6.0),
			_obs(KIND_GRAVESTONE, 2, 6.0),
		],
		[_soul(KIND_COFFIN, 0, 12.0)]
	))
	## --- Harder: side-incoming + gates (still always one free lane) ---
	out.append(_pat(
		"side_then_gate_open_center", 8, 5, 20, [],
		[
			_obs(KIND_SIDE, 0, 10.0),
			_obs(KIND_GRAVESTONE, 0, -4.0),
			_obs(KIND_GRAVESTONE, 2, -4.0),
		],
		_line_souls(1, 14.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"side_right_then_open_left", 8, 5, 20, [],
		[
			_obs(KIND_SIDE, 2, 10.0),
			_obs(KIND_GRAVESTONE, 1, -4.0),
			_obs(KIND_GRAVESTONE, 2, -4.0),
		],
		_line_souls(0, 14.0, 4, KIND_SOUL)
	))
	out.append(_pat(
		"double_stagger_hard", 7, 6, 20, [],
		[
			_obs(KIND_GRAVESTONE, 0, 12.0),
			_obs(KIND_GRAVESTONE, 1, 12.0),
			_obs(KIND_PIT, 2, -2.0),
			_obs(KIND_GRAVESTONE, 0, -2.0),
		],
		_arc_souls([2, 2, 1, 1, 0], 14.0, KIND_SOUL)
	))
	## --- Castle-flavored (still fair; biome filter optional) ---
	out.append(_pat(
		"castle_gate_open_center", 10, 3, 20, PackedStringArray(["haunted_castle"]),
		[
			_obs(KIND_GRAVESTONE, 0, 6.0),
			_obs(KIND_GRAVESTONE, 2, 6.0),
		],
		_line_souls(1, 14.0, 5, KIND_SOUL)
	))
	out.append(_pat(
		"castle_arc_into_left", 9, 4, 20, PackedStringArray(["haunted_castle"]),
		[
			_obs(KIND_SIDE, 2, 8.0),
			_obs(KIND_GRAVESTONE, 1, -6.0),
			_obs(KIND_GRAVESTONE, 2, -6.0),
		],
		_arc_souls([1, 1, 0, 0, 0], 14.0, KIND_SOUL)
	))
	## Mirror a few for variety without new choreography.
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
		## Fallback: open center line — always fair.
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
	## Never allow a single Z-band where lanes 0+1+2 are all blocked.
	var by_z: Dictionary = {}
	var obstacles: Array = pattern.get("obstacles", []) as Array
	for item in obstacles:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		var lane: int = clampi(int(d.get("lane", 0)), 0, 2)
		var z_val: float = float(d.get("z", 0.0))
		var band: int = int(floor(z_val / 4.0))
		var mask: int = int(by_z.get(band, 0))
		mask |= (1 << lane)
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


static func _obs(kind: String, lane: int, z: float) -> Dictionary:
	return {"kind": kind, "lane": lane, "z": z, "height_kind": "ground"}


static func _soul(kind: String, lane: int, z: float) -> Dictionary:
	return {"kind": kind, "lane": lane, "z": z, "height_kind": "float"}


static func _line_souls(lane: int, start_z: float, count: int, kind: String) -> Array:
	var out: Array = []
	for i in count:
		## Runner moves toward -Z; place ahead→behind as descending Z.
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
	return {
		"kind": str(spec.get("kind", "")),
		"lane": _mirror_lane(lane),
		"z": float(spec.get("z", 0.0)),
		"height_kind": str(spec.get("height_kind", "float")),
	}


static func _append_mirrored(out: Array[Dictionary]) -> void:
	var base: Array[Dictionary] = out.duplicate()
	for p in base:
		var id: String = str(p.get("id", ""))
		if id.begins_with("open_line") or id.begins_with("gate_open_center"):
			continue
		if id.contains("center") and not id.contains("left") and not id.contains("right"):
			## Symmetric enough — skip.
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
