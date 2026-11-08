extends "res://scripts/obstacles/ObstacleBase.gd"
## Low barrier ("bone barricade") — striped board on A-frame legs, open underneath.
## Jump over it OR roll under it. The hitbox is exactly the board, so the rule is geometric:
## a rolling capsule (0.9 m) passes below, a jump apex clears the top.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Kit = preload("res://scripts/obstacles/ObstacleMeshKit.gd")

@onready var hitbox: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	super._ready()
	_fit_hitbox()
	_build_visual()


func _fit_hitbox() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(Geo.LOW_WIDTH, Geo.LOW_TOP - Geo.LOW_BOTTOM, Geo.LOW_DEPTH)
	hitbox.shape = box
	hitbox.position = Vector3(0.0, (Geo.LOW_TOP + Geo.LOW_BOTTOM) * 0.5, 0.0)


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	super.configure(lane, z_offset, extras)
	position.y = 0.0
	rotation = Vector3.ZERO


func _build_visual() -> void:
	if has_node("Visual"):
		return
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	mi.mesh = _mesh()
	add_child(mi)


static func _mesh() -> ArrayMesh:
	var hit: ArrayMesh = Kit.cached("low_barrier")
	if hit:
		return hit
	var k := Kit.new()
	var mid_y: float = (Geo.LOW_TOP + Geo.LOW_BOTTOM) * 0.5
	var h: float = Geo.LOW_TOP - Geo.LOW_BOTTOM
	k.box(Vector3(2.1, h - 0.04, 0.12), Vector3(0.0, mid_y, 0.0), "warning_stripes")
	k.box(Vector3(2.16, 0.05, 0.16), Vector3(0.0, Geo.LOW_TOP - 0.02, 0.0), "iron_black")
	k.box(Vector3(2.16, 0.04, 0.15), Vector3(0.0, Geo.LOW_BOTTOM + 0.02, 0.0), "iron_black")
	for sx in [-1.0, 1.0]:
		## A-frame legs splay along Z, outside the player capsule (x = ±1.0).
		for sz in [-1.0, 1.0]:
			k.box(Vector3(0.09, 1.42, 0.08), Vector3(sx * 1.02, 0.66, sz * 0.2), "wood_planks", Vector3(sz * 14.0, 0.0, 0.0))
		k.box(Vector3(0.08, 0.06, 0.5), Vector3(sx * 1.02, 0.35, 0.0), "wood_planks")
		k.cyl(0.07, 0.07, 0.16, Vector3(sx * 0.98, Geo.LOW_TOP + 0.09, 0.0), "lantern_flame", Vector3.ZERO, 6)
		k.box(Vector3(0.14, 0.04, 0.14), Vector3(sx * 0.98, Geo.LOW_TOP + 0.19, 0.0), "iron_black")
	## Skull plaque on the board face (stays inside the hitbox band).
	k.sphere(0.12, Vector3(0.0, mid_y + 0.02, 0.07), "bone", Vector3(1.0, 0.95, 0.6))
	k.sphere(0.028, Vector3(-0.045, mid_y + 0.04, 0.14), "ghost_eye")
	k.sphere(0.028, Vector3(0.045, mid_y + 0.04, 0.14), "ghost_eye")
	return Kit.store("low_barrier", k.commit())
