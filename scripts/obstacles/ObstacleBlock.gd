extends "res://scripts/obstacles/ObstacleBase.gd"
## Full-height block ("crypt wall") — a stone crypt facade filling one lane. Change lane.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Kit = preload("res://scripts/obstacles/ObstacleMeshKit.gd")

@onready var hitbox: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	super._ready()
	var box := BoxShape3D.new()
	box.size = Vector3(Geo.BLOCK_WIDTH, Geo.BLOCK_TOP, Geo.BLOCK_DEPTH)
	hitbox.shape = box
	hitbox.position = Vector3(0.0, Geo.BLOCK_TOP * 0.5, 0.0)
	if not has_node("Visual"):
		var mi := MeshInstance3D.new()
		mi.name = "Visual"
		mi.mesh = _mesh()
		add_child(mi)


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation = Vector3.ZERO


static func _mesh() -> ArrayMesh:
	var hit: ArrayMesh = Kit.cached("crypt_wall")
	if hit:
		return hit
	var k := Kit.new()
	var w: float = Geo.BLOCK_WIDTH
	var d: float = Geo.BLOCK_DEPTH
	var body_h: float = Geo.BLOCK_TOP - 0.45
	var front: float = d * 0.5
	k.box(Vector3(w, body_h, d), Vector3(0.0, body_h * 0.5, 0.0), "stone_crypt")
	k.box(Vector3(w + 0.12, 0.2, d + 0.12), Vector3(0.0, 0.1, 0.0), "stone_crypt")
	k.box(Vector3(w + 0.1, 0.14, d + 0.1), Vector3(0.0, body_h + 0.02, 0.0), "stone_crypt")
	## Gabled roof flush with BLOCK_TOP; cross rises above (out of any reachable height).
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 0.1, Geo.BLOCK_TOP - body_h - 0.05, d + 0.1)
	k.add(roof, "stone_crypt", Transform3D(Basis(), Vector3(0.0, body_h + 0.05 + roof.size.y * 0.5, 0.0)))
	k.box(Vector3(0.14, 0.75, 0.14), Vector3(0.0, Geo.BLOCK_TOP + 0.3, 0.0), "stone_crypt")
	k.box(Vector3(0.5, 0.13, 0.14), Vector3(0.0, Geo.BLOCK_TOP + 0.42, 0.0), "stone_crypt")
	## Corner pilasters.
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.26, body_h, 0.2), Vector3(sx * (w * 0.5 - 0.1), body_h * 0.5, front + 0.02), "stone_crypt")
	## Iron door with a violet glow seeping from the frame, bone epitaph above.
	k.box(Vector3(1.12, 1.95, 0.05), Vector3(0.0, 1.07, front + 0.01), "window_violet")
	k.box(Vector3(1.0, 1.85, 0.08), Vector3(0.0, 1.02, front + 0.04), "iron_black")
	k.cyl(0.5, 0.5, 0.08, Vector3(0.0, 1.95, front + 0.04), "iron_black", Vector3(90.0, 0.0, 0.0), 10, Vector3(1.0, 1.0, 0.6))
	for bx in [-0.28, 0.0, 0.28]:
		k.box(Vector3(0.05, 1.7, 0.06), Vector3(bx, 1.0, front + 0.1), "iron_black")
	k.box(Vector3(0.06, 0.06, 0.05), Vector3(0.36, 1.0, front + 0.14), "trim_gold")
	k.box(Vector3(0.9, 0.22, 0.05), Vector3(0.0, body_h - 0.3, front + 0.03), "bone")
	## Grave candles at the foot.
	for sx in [-0.8, 0.8]:
		k.cyl(0.05, 0.05, 0.22, Vector3(sx, 0.31, front + 0.12), "bone", Vector3.ZERO, 6)
		k.sphere(0.035, Vector3(sx, 0.45, front + 0.12), "lantern_flame")
	return Kit.store("crypt_wall", k.commit())
