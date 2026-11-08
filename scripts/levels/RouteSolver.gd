extends RefCounted
## RouteSolver — proves a layout is passable and returns the action list for one route.
##
## Mirrors PlayerController at 60 Hz: constant forward speed, jump impulse + gravity,
## 0.75 s roll with the short capsule, 0.2 s lane switch that overlaps both lanes while
## crossing, ramps / train roofs as walkable surfaces. Obstacles are the same solids the
## scenes use (TrackGeometry). A short reaction pause (CHAIN_TIME) follows every action,
## so chained inputs need real distance that grows with speed.
##
## Search: Dijkstra over (grid d, lane, level). Cost = 1 per action, a small cost per run
## step away from souls, so the chosen route follows soul trails where they exist.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Patterns = preload("res://scripts/levels/ChunkPatterns.gd")

const DT: float = 1.0 / 60.0
const DS: float = 0.5
const CHAIN_TIME: float = 0.2
const Z_MARGIN: float = 0.15
const Y_EPS: float = 0.05
const STEP_UP: float = 0.35
const RUN_COST_NO_SOUL: float = 0.02
const ACTIONS: Array[String] = ["jump", "roll", "left", "right"]

var _v: float = 10.5
var _length: float = 0.0
## Per lane: Array of PackedFloat32Array [d_lo, d_hi, y_lo, y_hi].
var _solids: Array = [[], [], []]
## Per lane: Array of [d0, d1] roof spans.
var _roofs: Array = [[], [], []]
## Per lane: Array of [d0, d1] ramp spans (height 0 at d0 -> roof at d1).
var _ramps: Array = [[], [], []]
## Per lane: Array of cart rest centers.
var _carts: Array = [[], [], []]
var _hot: PackedByteArray = PackedByteArray()
var _soul_cells: Dictionary = {}


static func solve(layout: Dictionary, v: float, start_lane: int = 1, start_d: float = 0.0, start_level: int = 0) -> Dictionary:
	var s := new()
	s._prepare(layout, v)
	return s._search(start_lane, start_d, start_level)


## Chain several layouts end to end (seam checks, autopilot planning windows).
static func concat(layouts: Array) -> Dictionary:
	var out: Dictionary = {"id": "concat", "length": 0.0, "speed": 0.0, "stretch": 1.0,
		"obstacles": [], "souls": [], "intensity": 1}
	var off: float = 0.0
	for lay in layouts:
		for o in lay["obstacles"]:
			var c: Dictionary = (o as Dictionary).duplicate()
			for key in ["d", "d0", "d1", "ramp_d0"]:
				if c.has(key):
					c[key] = float(c[key]) + off
			out["obstacles"].append(c)
		for so in lay["souls"]:
			var cs: Dictionary = (so as Dictionary).duplicate()
			cs["d"] = float(cs["d"]) + off
			out["souls"].append(cs)
		off += float(lay["length"])
	out["length"] = off
	return out


func _prepare(layout: Dictionary, v: float) -> void:
	_v = maxf(v, 1.0)
	_length = float(layout["length"])
	## One tick of travel on top of the margin: inputs land on a tick boundary, up to 1/60 s late.
	var pad: float = Geo.RADIUS + Z_MARGIN + _v * DT
	for o in layout["obstacles"]:
		var lane: int = int(o["lane"])
		var kind: String = str(o["kind"])
		var d0: float = float(o["d0"])
		var d1: float = float(o["d1"])
		match kind:
			Patterns.KIND_TRAIN:
				var has_ramp: bool = bool(o.get("ramp", false))
				_solids[lane].append(PackedFloat32Array([d0 - (0.0 if has_ramp else pad), d1 + pad, 0.0, Geo.TRAIN_ROOF - 0.06]))
				_roofs[lane].append(PackedFloat32Array([d0, d1]))
				if has_ramp:
					_ramps[lane].append(PackedFloat32Array([float(o["ramp_d0"]), d0]))
			Patterns.KIND_CART:
				_carts[lane].append(float(o["d"]))
			_:
				var band: Vector2 = Patterns.solid_band(kind)
				_solids[lane].append(PackedFloat32Array([d0 - pad, d1 + pad, band.x, band.y]))
	var cells: int = int(ceil((_length + 40.0) / DS)) + 2
	_hot.resize(cells)
	_hot.fill(0)
	var look_back: float = _v * 1.8 + 8.0
	for lane in 3:
		for sd in _solids[lane]:
			_mark_hot(float(sd[0]) - look_back, float(sd[1]))
		for rf in _roofs[lane]:
			_mark_hot(float(rf[1]) - look_back, float(rf[1]) + 2.0)
		for rp in _ramps[lane]:
			_mark_hot(float(rp[0]) - look_back, float(rp[1]))
		for cd in _carts[lane]:
			_mark_hot(float(cd) - Geo.CART_TRIGGER - look_back, float(cd) + 2.0)
	for so in layout["souls"]:
		var lvl: int = 1 if float(so["y"]) >= 1.5 else 0
		var ci: int = int(round(float(so["d"]) / DS))
		for di in range(-2, 3):
			_soul_cells[_key(ci + di, int(so["lane"]), lvl)] = true


func _mark_hot(a: float, b: float) -> void:
	var i0: int = clampi(int(floor(a / DS)), 0, _hot.size() - 1)
	var i1: int = clampi(int(ceil(b / DS)), 0, _hot.size() - 1)
	for i in range(i0, i1 + 1):
		_hot[i] = 1


static func _key(i: int, lane: int, level: int) -> int:
	return (i * 3 + lane) * 2 + level


# --- Search -------------------------------------------------------------------------

func _search(start_lane: int, start_d: float, start_level: int) -> Dictionary:
	var goal_i: int = int(ceil(_length / DS))
	var i0: int = int(ceil(start_d / DS))
	if start_level == 0 and _state_y(start_lane, float(i0) * DS, 1) > 0.05:
		start_level = 1
	var start_key: int = _key(i0, start_lane, start_level)
	var dist: Dictionary = {start_key: 0.0}
	var parent: Dictionary = {}
	var heap_cost: Array[float] = [0.0]
	var heap_key: Array[int] = [start_key]
	var expanded: int = 0
	var goal_key: int = -1
	while not heap_key.is_empty():
		var cost: float = heap_cost[0]
		var key: int = heap_key[0]
		_heap_pop(heap_cost, heap_key)
		if cost > float(dist.get(key, INF)) + 1e-6:
			continue
		expanded += 1
		var level: int = key % 2
		var lane: int = (key / 2) % 3
		var i: int = key / 6
		if i >= goal_i:
			goal_key = key
			break
		if expanded > 400000:
			break
		var d: float = float(i) * DS
		var y: float = _state_y(lane, d, level)
		var moves: Array = ["run"]
		if i < _hot.size() and _hot[i] == 1:
			moves.append_array(ACTIONS)
		for mv in moves:
			var res: Array = _sim(d, lane, y, str(mv))
			if res.is_empty():
				continue
			## Snap ahead: obstacles are wider than one cell + one tick, so nothing is skipped.
			var ni: int = int(ceil(float(res[0]) / DS - 1e-4))
			var nkey: int = _key(ni, int(res[1]), 1 if float(res[2]) > 0.05 else 0)
			var step_cost: float = 1.0
			if mv == "run":
				step_cost = 0.0 if _soul_cells.has(nkey) else RUN_COST_NO_SOUL
			var nc: float = cost + step_cost
			if nc < float(dist.get(nkey, INF)) - 1e-6:
				dist[nkey] = nc
				parent[nkey] = [key, mv, d]
				_heap_push(heap_cost, heap_key, nc, nkey)
	if goal_key < 0:
		return {"ok": false, "expanded": expanded, "actions": [], "fail_d": _furthest(dist)}
	var actions: Array = []
	var k: int = goal_key
	while parent.has(k):
		var p: Array = parent[k]
		if str(p[1]) != "run":
			actions.push_front({"d": float(p[2]), "action": str(p[1])})
		k = int(p[0])
	return {"ok": true, "expanded": expanded, "actions": actions, "cost": float(dist[goal_key]),
		"end_lane": (goal_key / 2) % 3, "end_level": goal_key % 2}


func _furthest(dist: Dictionary) -> float:
	var best: int = 0
	for key in dist.keys():
		best = maxi(best, int(key) / 6)
	return float(best) * DS


func _state_y(lane: int, d: float, level: int) -> float:
	if level == 0:
		return 0.0
	var best: float = 0.0
	for rf in _roofs[lane]:
		if d >= float(rf[0]) and d <= float(rf[1]) + 0.25:
			best = maxf(best, Geo.TRAIN_ROOF)
	for rp in _ramps[lane]:
		if d >= float(rp[0]) and d <= float(rp[1]):
			best = maxf(best, Geo.TRAIN_ROOF * (d - float(rp[0])) / (float(rp[1]) - float(rp[0])))
	return best


## Highest walkable surface in `lane` at `d` that a body at height `y` can stand on.
func _surface(lane: int, d: float, y: float) -> float:
	var best: float = 0.0
	for rf in _roofs[lane]:
		if d >= float(rf[0]) and d <= float(rf[1]) + 0.25 and Geo.TRAIN_ROOF <= y + STEP_UP:
			best = maxf(best, Geo.TRAIN_ROOF)
	for rp in _ramps[lane]:
		if d >= float(rp[0]) and d <= float(rp[1]):
			var h: float = Geo.TRAIN_ROOF * (d - float(rp[0])) / (float(rp[1]) - float(rp[0]))
			if h <= y + STEP_UP:
				best = maxf(best, h)
	return best


func _collides(lane: int, d: float, y: float, h: float) -> bool:
	for sd in _solids[lane]:
		if d < float(sd[0]) or d > float(sd[1]):
			continue
		if y + Y_EPS < float(sd[3]) and y + h - Y_EPS > float(sd[2]):
			return true
	for rp in _ramps[lane]:
		if d >= float(rp[0]) and d <= float(rp[1]):
			var rh: float = Geo.TRAIN_ROOF * (d - float(rp[0])) / (float(rp[1]) - float(rp[0]))
			if y < rh - STEP_UP:
				return true
	for cd in _carts[lane]:
		var rest: float = float(cd)
		var trigger_d: float = rest - Geo.CART_TRIGGER
		var center: float = rest
		if d > trigger_d:
			center = rest - minf((d - trigger_d) * Geo.CART_SPEED / _v, Geo.CART_MAX_TRAVEL)
		var half: float = Geo.CART_LEN * 0.5 + Geo.RADIUS + Z_MARGIN + _v * DT
		if absf(d - center) <= half and y + Y_EPS < Geo.CART_TOP:
			return true
	return false


## Simulate one move from a grounded state. Returns [d_end, lane_end, y_end] or [] if hit.
func _sim(d_start: float, lane: int, y_start: float, move: String) -> Array:
	var d: float = d_start
	var y: float = y_start
	var vy: float = 0.0
	var grounded: bool = true
	var lane_from: int = lane
	var lane_to: int = lane
	var switching: bool = false
	var switch_t: float = 0.0
	var sliding: bool = false
	var slide_t: float = 0.0
	var first_tick: bool = false
	match move:
		"jump":
			vy = Geo.JUMP_VELOCITY
			grounded = false
			first_tick = true
		"roll":
			sliding = true
			## The controller ticks the slide timer on its start frame; plan for a slightly short roll.
			slide_t = Geo.SLIDE_TIME - 2.0 * DT
		"left", "right":
			lane_to = lane + (-1 if move == "left" else 1)
			if lane_to < 0 or lane_to > 2:
				return []
			switching = true
	var action_done: bool = move == "run"
	var chain_left: float = 0.0 if move == "run" else CHAIN_TIME
	var run_target: float = d_start + DS
	var t: float = 0.0
	while t < 6.0:
		t += DT
		d += _v * DT
		var occ_from: bool = true
		var occ_to: bool = false
		var support: int = lane_from
		if switching:
			switch_t += DT
			occ_from = switch_t <= 0.1
			occ_to = switch_t >= 0.04
			support = lane_to if switch_t >= Geo.LANE_TIME / 3.0 else lane_from
			if switch_t >= Geo.LANE_TIME:
				switching = false
				lane_from = lane_to
				support = lane_to
				occ_from = true
				occ_to = false
		if grounded:
			var s: float = _surface(support, d, y)
			if s < y - 0.05:
				grounded = false
				vy = 0.0
			else:
				y = s
		if not grounded:
			if first_tick:
				first_tick = false
			else:
				vy -= Geo.GRAVITY * DT
			var ny: float = y + vy * DT
			if vy <= 0.0:
				var land: float = _surface(support, d, y)
				if ny <= land:
					ny = land
					grounded = true
					vy = 0.0
			y = ny
		if sliding:
			slide_t -= DT
			if slide_t <= 0.0 or not grounded:
				sliding = false
		var h: float = Geo.SLIDE_H if sliding else Geo.STAND_H
		if occ_from and _collides(lane_from, d, y, h):
			return []
		if occ_to and _collides(lane_to, d, y, h):
			return []
		if d >= _length + 20.0 and grounded:
			return [d, lane_from, y]
		if not action_done:
			if grounded and not switching and not sliding:
				action_done = true
			continue
		if chain_left > 0.0:
			chain_left -= DT
			continue
		if not grounded:
			continue
		if move == "run" and d < run_target:
			continue
		return [d, lane_from, y]
	return []


# --- Binary heap ------------------------------------------------------------------

static func _heap_push(costs: Array[float], keys: Array[int], c: float, k: int) -> void:
	costs.append(c)
	keys.append(k)
	var i: int = costs.size() - 1
	while i > 0:
		var p: int = (i - 1) >> 1
		if costs[p] <= costs[i]:
			break
		var tc: float = costs[p]
		costs[p] = costs[i]
		costs[i] = tc
		var tk: int = keys[p]
		keys[p] = keys[i]
		keys[i] = tk
		i = p


static func _heap_pop(costs: Array[float], keys: Array[int]) -> void:
	var last: int = costs.size() - 1
	costs[0] = costs[last]
	keys[0] = keys[last]
	costs.resize(last)
	keys.resize(last)
	var i: int = 0
	var n: int = costs.size()
	while true:
		var l: int = 2 * i + 1
		var r: int = l + 1
		var m: int = i
		if l < n and costs[l] < costs[m]:
			m = l
		if r < n and costs[r] < costs[m]:
			m = r
		if m == i:
			break
		var tc: float = costs[m]
		costs[m] = costs[i]
		costs[i] = tc
		var tk: int = keys[m]
		keys[m] = keys[i]
		keys[i] = tk
		i = m
