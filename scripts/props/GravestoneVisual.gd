extends Node3D
## Applies PBR material to an instanced gravestone FBX and seats it on the ground.

@export var material: Material
@export var ground_align: bool = true
## Uniform visual scale on top of FBX root scale (imported ~1m tall).
@export var visual_scale: float = 1.0


const SINK: float = 0.02

var _seat_y: float = 0.0


func _ready() -> void:
	if visual_scale != 1.0:
		scale = Vector3.ONE * visual_scale
	_apply_material(self)
	if ground_align:
		## Deferred: spawners often set position right after add_child.
		(func() -> void:
			_seat_y = position.y
			_align_to_ground()
		).call_deferred()


func _apply_material(n: Node) -> void:
	if material == null:
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.material_override = material
	for c in n.get_children():
		_apply_material(c)


func _align_to_ground() -> void:
	if not is_inside_tree():
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	if meshes.is_empty():
		return
	var parent_3d := get_parent() as Node3D
	var to_parent: Transform3D = parent_3d.global_transform.affine_inverse() if parent_3d else Transform3D.IDENTITY
	var bottom_y: float = INF
	for mi in meshes:
		var aabb: AABB = (to_parent * mi.global_transform) * mi.get_aabb()
		bottom_y = minf(bottom_y, aabb.position.y)
	## The authored local Y is the ground height (shoulder top, field, floor); bury the base slightly.
	position.y += _seat_y - bottom_y - SINK
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes(c, out)
