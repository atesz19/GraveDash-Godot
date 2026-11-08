extends SceneTree
## Headless: Subway-Surfers obstacle rules, checked against the real collision shapes.
##   low barrier  — jump OR roll   (rolling capsule passes below, jump apex clears the top)
##   high barrier — roll only      (rolling passes, standing hits, a jump cannot clear it)
##   gravestone / block — change lane (no gap underneath, too tall for low tricks)
##   train — rideable StaticBody on the rideable layer + lethal sides/front, optional ramp
##   cart  — Area3D hazard that starts rolling toward the player inside the trigger range
## Also checks LevelGenerator pool registration and that legacy kinds are gone.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Patterns = preload("res://scripts/levels/ChunkPatterns.gd")

const SCENES: Dictionary = {
	"obstacle_low": "res://scenes/obstacles/ObstacleLow.tscn",
	"obstacle_high": "res://scenes/obstacles/ObstacleHigh.tscn",
	"obstacle_gravestone": "res://scenes/obstacles/ObstacleGravestone.tscn",
	"obstacle_block": "res://scenes/obstacles/ObstacleBlock.tscn",
	"obstacle_train": "res://scenes/obstacles/ObstacleTrain.tscn",
	"obstacle_cart": "res://scenes/obstacles/ObstacleCart.tscn",
}

var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("OK ", msg)
	else:
		push_error("FAIL " + msg)
		failed += 1


func _run() -> void:
	var nodes: Dictionary = {}
	for kind in SCENES.keys():
		var path: String = SCENES[kind]
		if not ResourceLoader.exists(path):
			_check(false, "missing scene %s" % path)
			continue
		var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		get_root().add_child(n)
		nodes[kind] = n
	await process_frame
	await physics_frame

	var apex: float = Geo.jump_height(Geo.jump_air_time() * 0.5)
	var slide_top: float = Geo.SLIDE_H
	var stand_top: float = Geo.STAND_H
	print("player: slide top=%.2f stand top=%.2f jump apex=%.2f" % [slide_top, stand_top, apex])

	if nodes.has("obstacle_low"):
		var r: Vector2 = _y_range(nodes["obstacle_low"])
		_check(r.x > slide_top + 0.05, "low: rolling passes under (bottom %.2f > %.2f)" % [r.x, slide_top])
		_check(r.x < stand_top - 0.2, "low: running hits (bottom %.2f)" % r.x)
		_check(r.y < apex - 0.3, "low: jump clears (top %.2f < apex %.2f)" % [r.y, apex])
	if nodes.has("obstacle_high"):
		var r: Vector2 = _y_range(nodes["obstacle_high"])
		_check(r.x > slide_top + 0.05, "high: rolling passes under (bottom %.2f)" % r.x)
		_check(r.x < stand_top - 0.2, "high: running hits (bottom %.2f)" % r.x)
		_check(r.y > apex + 0.3, "high: cannot be jumped (top %.2f > apex %.2f)" % [r.y, apex])
	for kind in ["obstacle_gravestone", "obstacle_block"]:
		if nodes.has(kind):
			var r: Vector2 = _y_range(nodes[kind])
			_check(r.x < 0.05, "%s: no gap underneath (bottom %.2f)" % [kind, r.x])
			_check(r.y > slide_top + 0.2, "%s: cannot be rolled under (top %.2f)" % [kind, r.y])
	if nodes.has("obstacle_block"):
		_check(_y_range(nodes["obstacle_block"]).y > apex + 0.5, "block: cannot be jumped")

	if nodes.has("obstacle_train"):
		var train: Node3D = nodes["obstacle_train"]
		train.call("configure", 1, 0.0, {"cars": 3, "ramp": true})
		train.call("on_spawned")
		await physics_frame
		var body: StaticBody3D = train.get_node_or_null("Body") as StaticBody3D
		_check(body != null and body.collision_layer == Geo.LAYER_RIDEABLE, "train body on rideable layer %d" % Geo.LAYER_RIDEABLE)
		_check(body != null and (body.collision_layer & 1) == 0, "train body off world layer (camera spring arm)")
		var hz: Area3D = train.get_node_or_null("Hazard") as Area3D
		_check(hz != null and hz.collision_layer == 4 and hz.collision_mask == 2, "train hazard area layer 4 / mask 2")
		var ramp: StaticBody3D = train.get_node_or_null("Ramp") as StaticBody3D
		_check(ramp != null and (ramp.collision_layer & Geo.LAYER_RIDEABLE) != 0, "train ramp collides")
		var expected_len: float = Geo.train_length(3)
		_check(is_equal_approx(float(train.get("length_z")), expected_len), "train length %.1f m for 3 cars" % expected_len)
		var lanes: Array = train.call("occupied_lanes")
		_check(lanes.size() == 1 and int(lanes[0]) == 1, "train occupies its lane only %s" % str(lanes))
		_check(train.is_in_group("train") and not train.is_in_group("obstacle"),
			"train group 'train' only (Holy Light never deletes a ridden train)")
		var roof: float = _y_range(body).y if body != null else 0.0
		_check(absf(roof - Geo.TRAIN_ROOF) < 0.01, "train roof at %.2f" % roof)
		_check(Geo.TRAIN_ROOF > apex + 0.2, "train roof unreachable by a ground jump (ramp required)")

	if nodes.has("obstacle_cart"):
		var cart: Area3D = nodes["obstacle_cart"] as Area3D
		_check(cart != null and cart.collision_layer == 4, "cart hazard layer 4")
		var r: Vector2 = _y_range(cart)
		_check(r.x < 0.05 and r.y > apex + 0.3, "cart: change lane only (%.2f..%.2f)" % [r.x, r.y])

	var pool: Node = get_root().get_node_or_null("ObjectPool")
	if pool == null:
		_check(false, "ObjectPool autoload")
	else:
		var gen := Node3D.new()
		gen.set_script(load("res://scripts/LevelGenerator.gd"))
		gen.call("_ensure_scenes")
		gen.call("_register_pools")
		for pid in SCENES.keys():
			_check(bool(pool.call("has_pool", pid)), "pool %s" % pid)
		for legacy in ["obstacle_pit", "obstacle_side", "obstacle_platform"]:
			_check(not bool(pool.call("has_pool", legacy)), "legacy pool %s absent" % legacy)
		gen.free()

	var used: Dictionary = {}
	for sec in Patterns.all_sections():
		for o in Patterns.build_layout(sec, Geo.START_SPEED)["obstacles"]:
			used[str(o["kind"])] = true
	for kind in SCENES.keys():
		_check(used.has(kind), "kind %s used by the section catalog" % kind)
	for kind in used.keys():
		_check(SCENES.has(kind), "catalog kind %s has a scene" % kind)

	if failed > 0:
		push_error("SS obstacles FAILED (%d)" % failed)
		quit(1)
		return
	print("SS obstacles OK")
	quit(0)


## World-space vertical extent of every box/convex collision shape under `n`.
func _y_range(n: Node) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var p := cs.get_parent()
		if p is Area3D and p != n and p.name == "Hazard":
			continue
		var aabb: AABB = _shape_aabb(cs.shape)
		var xf: Transform3D = cs.global_transform
		var w: AABB = xf * aabb
		lo = minf(lo, w.position.y)
		hi = maxf(hi, w.end.y)
	return Vector2(lo, hi)


func _shape_aabb(s: Shape3D) -> AABB:
	if s is BoxShape3D:
		var sz: Vector3 = (s as BoxShape3D).size
		return AABB(-sz * 0.5, sz)
	if s is CylinderShape3D:
		var cy := s as CylinderShape3D
		return AABB(Vector3(-cy.radius, -cy.height * 0.5, -cy.radius), Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0))
	if s is CapsuleShape3D:
		var ca := s as CapsuleShape3D
		return AABB(Vector3(-ca.radius, -ca.height * 0.5, -ca.radius), Vector3(ca.radius * 2.0, ca.height, ca.radius * 2.0))
	if s is ConvexPolygonShape3D:
		var pts: PackedVector3Array = (s as ConvexPolygonShape3D).points
		var a := AABB(pts[0], Vector3.ZERO)
		for p in pts:
			a = a.expand(p)
		return a
	return AABB()
