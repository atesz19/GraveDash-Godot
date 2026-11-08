extends "res://scripts/obstacles/ObstacleBase.gd"
## High barrier ("hanging coffin gate") — a coffin lid hangs on chains between two posts.
## Roll under only: the lid starts above the rolling capsule and reaches higher than any jump.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Kit = preload("res://scripts/obstacles/ObstacleMeshKit.gd")

@onready var hitbox: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	super._ready()
	var box := BoxShape3D.new()
	box.size = Vector3(Geo.HIGH_WIDTH, Geo.HIGH_TOP - Geo.HIGH_BOTTOM, Geo.HIGH_DEPTH)
	hitbox.shape = box
	hitbox.position = Vector3(0.0, (Geo.HIGH_TOP + Geo.HIGH_BOTTOM) * 0.5, 0.0)
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
	var hit: ArrayMesh = Kit.cached("high_barrier")
	if hit:
		return hit
	var k := Kit.new()
	var lid_h: float = Geo.HIGH_TOP - 0.18 - Geo.HIGH_BOTTOM
	var lid_y: float = Geo.HIGH_BOTTOM + lid_h * 0.5
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.2, 3.5, 0.22), Vector3(sx * 1.16, 1.75, 0.0), "wood_planks")
		k.box(Vector3(0.3, 0.16, 0.32), Vector3(sx * 1.16, 0.08, 0.0), "iron_black")
		k.cyl(0.0, 0.11, 0.3, Vector3(sx * 1.16, 3.65, 0.0), "iron_black", Vector3.ZERO, 4)
		## Chains from the crossbeam to the lid shoulders.
		k.cyl(0.025, 0.025, 0.2, Vector3(sx * 0.42, Geo.HIGH_TOP - 0.08, 0.0), "iron_black", Vector3.ZERO, 4)
	k.box(Vector3(2.7, 0.24, 0.3), Vector3(0.0, Geo.HIGH_TOP + 0.1, 0.0), "wood_planks")
	k.box(Vector3(2.74, 0.05, 0.32), Vector3(0.0, Geo.HIGH_TOP - 0.03, 0.0), "iron_black")
	## Coffin lid (hexagon, pointy top/bottom) with a bone cross.
	k.coffin_plate(1.9, lid_h, Geo.HIGH_DEPTH - 0.06, Vector3(0.0, lid_y, 0.0), "wood_coffin")
	k.coffin_plate(1.7, lid_h - 0.2, Geo.HIGH_DEPTH - 0.02, Vector3(0.0, lid_y, 0.0), "lacquer_oxblood")
	k.box(Vector3(0.14, lid_h * 0.62, 0.06), Vector3(0.0, lid_y + 0.05, Geo.HIGH_DEPTH * 0.5), "bone")
	k.box(Vector3(0.78, 0.14, 0.06), Vector3(0.0, lid_y + lid_h * 0.16, Geo.HIGH_DEPTH * 0.5), "bone")
	## Skull on the beam with glowing eyes.
	k.sphere(0.15, Vector3(0.0, Geo.HIGH_TOP + 0.36, 0.06), "bone", Vector3(1.0, 0.95, 0.85))
	k.sphere(0.035, Vector3(-0.055, Geo.HIGH_TOP + 0.38, 0.19), "ghost_eye")
	k.sphere(0.035, Vector3(0.055, Geo.HIGH_TOP + 0.38, 0.19), "ghost_eye")
	return Kit.store("high_barrier", k.commit())
