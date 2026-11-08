extends "res://scripts/obstacles/ObstacleBase.gd"
## Runaway coffin cart — rolls down its lane toward the player once they are within
## CART_TRIGGER meters. Too tall to jump; change lane before it arrives.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Kit = preload("res://scripts/obstacles/ObstacleMeshKit.gd")

const WHEEL_R: float = 0.48

var _rolling: bool = false
var _travelled: float = 0.0
var _axles: Array[Node3D] = []


func _ready() -> void:
	super._ready()
	_fit_hitbox()
	if not has_node("Visual"):
		var mi := MeshInstance3D.new()
		mi.name = "Visual"
		mi.mesh = _body_mesh()
		add_child(mi)
		for az in [Geo.CART_LEN * 0.32, -Geo.CART_LEN * 0.32]:
			var axle := MeshInstance3D.new()
			axle.mesh = _axle_mesh()
			axle.position = Vector3(0.0, WHEEL_R, az)
			add_child(axle)
			_axles.append(axle)


func _fit_hitbox() -> void:
	## Bed + wheels across the full cart, upright coffin in the middle of the lane.
	var bed: CollisionShape3D = $CollisionShape3D
	var bed_box := BoxShape3D.new()
	bed_box.size = Vector3(Geo.CART_WIDTH, 1.05, Geo.CART_LEN)
	bed.shape = bed_box
	bed.position = Vector3(0.0, 0.525, 0.0)
	var coffin: CollisionShape3D = get_node_or_null("CoffinShape") as CollisionShape3D
	if coffin == null:
		coffin = CollisionShape3D.new()
		coffin.name = "CoffinShape"
		add_child(coffin)
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.0, Geo.CART_TOP - 0.95, 0.7)
	coffin.shape = cbox
	coffin.position = Vector3(0.0, (Geo.CART_TOP + 0.95) * 0.5, 0.0)


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation = Vector3.ZERO
	_reset_motion()


func _reset_motion() -> void:
	_rolling = false
	_travelled = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not GameManager.is_playing():
		return
	if not _rolling:
		var player := GameManager.player as Node3D
		if player != null and is_instance_valid(player):
			var gap: float = player.global_position.z - global_position.z
			if gap > 0.0 and gap <= Geo.CART_TRIGGER:
				_rolling = true
		return
	if _travelled >= Geo.CART_MAX_TRAVEL:
		return
	var step: float = Geo.CART_SPEED * delta
	position.z += step
	_travelled += step
	for axle in _axles:
		axle.rotate_x(step / WHEEL_R)


static func _body_mesh() -> ArrayMesh:
	var hit: ArrayMesh = Kit.cached("cart_body")
	if hit:
		return hit
	var k := Kit.new()
	var w: float = Geo.CART_WIDTH
	var l: float = Geo.CART_LEN
	k.box(Vector3(w - 0.1, 0.18, l), Vector3(0.0, 0.78, 0.0), "wood_planks")
	k.box(Vector3(w - 0.3, 0.12, l - 0.2), Vector3(0.0, 0.62, 0.0), "iron_black")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.08, 0.26, l), Vector3(sx * (w * 0.5 - 0.09), 0.98, 0.0), "wood_planks")
		k.box(Vector3(0.1, 0.05, l + 0.04), Vector3(sx * (w * 0.5 - 0.09), 1.12, 0.0), "iron_black")
	## Upright coffin, lid facing the player, chained to the bed.
	var coffin_h: float = Geo.CART_TOP - 0.95
	var cy: float = 0.95 + coffin_h * 0.5
	k.coffin_plate(1.0, coffin_h, 0.62, Vector3(0.0, cy, 0.0), "wood_coffin")
	k.coffin_plate(0.86, coffin_h - 0.16, 0.66, Vector3(0.0, cy, 0.0), "lacquer_black")
	k.box(Vector3(0.1, coffin_h * 0.55, 0.05), Vector3(0.0, cy + 0.06, 0.34), "trim_silver")
	k.box(Vector3(0.44, 0.1, 0.05), Vector3(0.0, cy + coffin_h * 0.16, 0.34), "trim_silver")
	k.sphere(0.04, Vector3(-0.1, cy + coffin_h * 0.33, 0.33), "ghost_eye")
	k.sphere(0.04, Vector3(0.1, cy + coffin_h * 0.33, 0.33), "ghost_eye")
	k.box(Vector3(1.06, 0.05, 0.7), Vector3(0.0, cy - 0.2, 0.0), "iron_black")
	## Lantern pole at the front corner.
	k.cyl(0.035, 0.035, 1.5, Vector3(0.72, 1.6, l * 0.5 - 0.15), "iron_black", Vector3.ZERO, 6)
	k.box(Vector3(0.22, 0.28, 0.22), Vector3(0.72, 2.42, l * 0.5 - 0.15), "iron_black")
	k.box(Vector3(0.15, 0.2, 0.24), Vector3(0.72, 2.42, l * 0.5 - 0.15), "lantern_flame")
	k.cyl(0.0, 0.16, 0.14, Vector3(0.72, 2.63, l * 0.5 - 0.15), "iron_black", Vector3.ZERO, 4)
	return Kit.store("cart_body", k.commit())


static func _axle_mesh() -> ArrayMesh:
	var hit: ArrayMesh = Kit.cached("cart_axle")
	if hit:
		return hit
	var k := Kit.new()
	for sx in [-1.0, 1.0]:
		var x: float = sx * (Geo.CART_WIDTH * 0.5 - 0.02)
		k.cyl(WHEEL_R, WHEEL_R, 0.12, Vector3(x, 0.0, 0.0), "wood_coffin", Vector3(0.0, 0.0, 90.0), 10)
		k.cyl(WHEEL_R + 0.02, WHEEL_R + 0.02, 0.05, Vector3(x + sx * 0.04, 0.0, 0.0), "iron_black", Vector3(0.0, 0.0, 90.0), 10)
		k.cyl(0.1, 0.1, 0.2, Vector3(x, 0.0, 0.0), "trim_silver", Vector3(0.0, 0.0, 90.0), 6)
		k.box(Vector3(0.06, WHEEL_R * 1.9, 0.06), Vector3(x + sx * 0.07, 0.0, 0.0), "wood_planks")
		k.box(Vector3(0.06, 0.06, WHEEL_R * 1.9), Vector3(x + sx * 0.07, 0.0, 0.0), "wood_planks")
	k.cyl(0.05, 0.05, Geo.CART_WIDTH - 0.1, Vector3.ZERO, "iron_black", Vector3(0.0, 0.0, 90.0), 6)
	return Kit.store("cart_axle", k.commit())
