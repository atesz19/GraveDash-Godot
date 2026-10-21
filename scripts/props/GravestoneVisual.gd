extends Node3D
## Applies PBR material to an instanced gravestone FBX and seats it on the ground.

@export var material: Material
@export var ground_align: bool = true
## Uniform visual scale on top of FBX root scale (imported ~1m tall).
@export var visual_scale: float = 1.0


func _ready() -> void:
	if visual_scale != 1.0:
		scale = Vector3.ONE * visual_scale
	_apply_material(self)
	if ground_align:
		call_deferred("_align_to_ground")


func _apply_material(n: Node) -> void:
	if material == null:
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.material_override = material
	for c in n.get_children():
		_apply_material(c)


func _align_to_ground() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	if meshes.is_empty():
		return
	var combined: AABB
	var first := true
	for mi in meshes:
		var local_aabb: AABB = mi.get_aabb()
		var xf := mi.global_transform * local_aabb
		if first:
			combined = xf
			first = false
		else:
			combined = combined.merge(xf)
	## Lift so the lowest vertex sits on y=0 in parent space.
	var bottom_y: float = combined.position.y
	global_position.y -= bottom_y


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes(c, out)
