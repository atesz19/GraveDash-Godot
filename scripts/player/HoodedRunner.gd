extends Node3D
## HoodedRunner — low-poly stylized humanoid (fake skeleton via MeshInstance pivots).
## Animations: idle, run, jump, slide, death. Built at runtime for Godot 4.7.2 safety.

signal animation_changed(anim_name: String)

const ANIM_IDLE: String = "idle"
const ANIM_RUN: String = "run"
const ANIM_JUMP: String = "jump"
const ANIM_SLIDE: String = "slide"
const ANIM_DEATH: String = "death"

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hip: Node3D = $Hip

var _current: String = ""
var _body_materials: Array[StandardMaterial3D] = []
var _normal_colors: Array[Color] = []
var _locked: bool = false  ## death locks until reset


func _ready() -> void:
	_collect_materials()
	_ensure_animations()
	play(ANIM_IDLE, true)


func _collect_materials() -> void:
	_body_materials.clear()
	_normal_colors.clear()
	for node in _find_meshes(self):
		var mesh_inst: MeshInstance3D = node
		var mat: Material = mesh_inst.get_surface_override_material(0)
		if mat == null and mesh_inst.mesh != null and mesh_inst.mesh.get_surface_count() > 0:
			mat = mesh_inst.mesh.surface_get_material(0)
		var std: StandardMaterial3D
		if mat is StandardMaterial3D:
			std = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			std = StandardMaterial3D.new()
			std.albedo_color = Color(0.18, 0.16, 0.2, 1.0)
			std.roughness = 0.85
		mesh_inst.set_surface_override_material(0, std)
		_body_materials.append(std)
		_normal_colors.append(std.albedo_color)


func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		out.append_array(_find_meshes(child))
	return out


func play(anim_name: String, force: bool = false) -> void:
	if _locked and anim_name != ANIM_DEATH and not force:
		return
	if anim_name == ANIM_DEATH:
		_locked = true
	if not force and _current == anim_name:
		return
	if anim_player == null:
		return
	if not anim_player.has_animation(anim_name):
		return
	_current = anim_name
	anim_player.play(anim_name)
	animation_changed.emit(anim_name)


func reset_pose() -> void:
	_locked = false
	_current = ""
	if hip:
		hip.rotation = Vector3.ZERO
		hip.position = Vector3(0.0, 0.95, 0.0)
	play(ANIM_IDLE, true)


func get_current_animation() -> String:
	return _current


func apply_tint(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0, alpha: float = 1.0) -> void:
	for i in _body_materials.size():
		var mat: StandardMaterial3D = _body_materials[i]
		var base: Color = _normal_colors[i]
		var tinted: Color = base.lerp(color, 0.65)
		tinted.a = alpha
		mat.albedo_color = tinted
		if alpha < 0.99:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.emission_enabled = emission_energy > 0.01
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy


func clear_tint() -> void:
	for i in _body_materials.size():
		var mat: StandardMaterial3D = _body_materials[i]
		mat.albedo_color = _normal_colors[i]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 1.0


func _ensure_animations() -> void:
	if anim_player == null:
		return
	## Drop any editor stubs; rebuild clean tracks.
	var lib := AnimationLibrary.new()
	lib.add_animation(ANIM_IDLE, _make_idle())
	lib.add_animation(ANIM_RUN, _make_run())
	lib.add_animation(ANIM_JUMP, _make_jump())
	lib.add_animation(ANIM_SLIDE, _make_slide())
	lib.add_animation(ANIM_DEATH, _make_death())
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", lib)


func _add_rot_track(anim: Animation, path: String, keys: Array) -> void:
	## keys: Array of [time: float, euler_degrees: Vector3]
	var idx: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, NodePath(path))
	for key in keys:
		var t: float = float(key[0])
		var e: Vector3 = key[1] as Vector3
		var q: Quaternion = Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		anim.rotation_track_insert_key(idx, t, q)


func _add_pos_track(anim: Animation, path: String, keys: Array) -> void:
	var idx: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(idx, NodePath(path))
	for key in keys:
		var t: float = float(key[0])
		var p: Vector3 = key[1] as Vector3
		anim.position_track_insert_key(idx, t, p)


func _make_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.6
	a.loop_mode = Animation.LOOP_LINEAR
	## Soft breath on torso / hip.
	_add_pos_track(a, "Hip", [
		[0.0, Vector3(0.0, 0.95, 0.0)],
		[0.8, Vector3(0.0, 0.98, 0.0)],
		[1.6, Vector3(0.0, 0.95, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso", [
		[0.0, Vector3(2.0, 0.0, 0.0)],
		[0.8, Vector3(-2.0, 0.0, 0.0)],
		[1.6, Vector3(2.0, 0.0, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmL", [
		[0.0, Vector3(8.0, 0.0, 12.0)],
		[0.8, Vector3(12.0, 0.0, 16.0)],
		[1.6, Vector3(8.0, 0.0, 12.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmR", [
		[0.0, Vector3(8.0, 0.0, -12.0)],
		[0.8, Vector3(12.0, 0.0, -16.0)],
		[1.6, Vector3(8.0, 0.0, -12.0)],
	])
	_add_rot_track(a, "Hip/LegL", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
	_add_rot_track(a, "Hip/LegR", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
	return a


func _make_run() -> Animation:
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(a, "Hip", [
		[0.0, Vector3(0.0, 0.95, 0.0)],
		[0.1375, Vector3(0.0, 1.02, 0.0)],
		[0.275, Vector3(0.0, 0.95, 0.0)],
		[0.4125, Vector3(0.0, 1.02, 0.0)],
		[0.55, Vector3(0.0, 0.95, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso", [
		[0.0, Vector3(8.0, 6.0, 0.0)],
		[0.275, Vector3(8.0, -6.0, 0.0)],
		[0.55, Vector3(8.0, 6.0, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso/Head", [
		[0.0, Vector3(-6.0, -4.0, 0.0)],
		[0.275, Vector3(-6.0, 4.0, 0.0)],
		[0.55, Vector3(-6.0, -4.0, 0.0)],
	])
	## Opposite arm/leg swing — runner faces -Z so X rotation pumps limbs.
	_add_rot_track(a, "Hip/Torso/ArmL", [
		[0.0, Vector3(42.0, 0.0, 18.0)],
		[0.275, Vector3(-38.0, 0.0, 14.0)],
		[0.55, Vector3(42.0, 0.0, 18.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmR", [
		[0.0, Vector3(-38.0, 0.0, -14.0)],
		[0.275, Vector3(42.0, 0.0, -18.0)],
		[0.55, Vector3(-38.0, 0.0, -14.0)],
	])
	_add_rot_track(a, "Hip/LegL", [
		[0.0, Vector3(-40.0, 0.0, 0.0)],
		[0.275, Vector3(36.0, 0.0, 0.0)],
		[0.55, Vector3(-40.0, 0.0, 0.0)],
	])
	_add_rot_track(a, "Hip/LegR", [
		[0.0, Vector3(36.0, 0.0, 0.0)],
		[0.275, Vector3(-40.0, 0.0, 0.0)],
		[0.55, Vector3(36.0, 0.0, 0.0)],
	])
	_add_rot_track(a, "Hip/LegL/LowerL", [
		[0.0, Vector3(25.0, 0.0, 0.0)],
		[0.275, Vector3(8.0, 0.0, 0.0)],
		[0.55, Vector3(25.0, 0.0, 0.0)],
	])
	_add_rot_track(a, "Hip/LegR/LowerR", [
		[0.0, Vector3(8.0, 0.0, 0.0)],
		[0.275, Vector3(25.0, 0.0, 0.0)],
		[0.55, Vector3(8.0, 0.0, 0.0)],
	])
	return a


func _make_jump() -> Animation:
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_NONE
	_add_pos_track(a, "Hip", [
		[0.0, Vector3(0.0, 0.95, 0.0)],
		[0.15, Vector3(0.0, 1.05, 0.0)],
		[0.7, Vector3(0.0, 1.0, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso", [
		[0.0, Vector3(-8.0, 0.0, 0.0)],
		[0.2, Vector3(12.0, 0.0, 0.0)],
		[0.7, Vector3(5.0, 0.0, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmL", [
		[0.0, Vector3(-50.0, 0.0, 25.0)],
		[0.7, Vector3(-35.0, 0.0, 20.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmR", [
		[0.0, Vector3(-50.0, 0.0, -25.0)],
		[0.7, Vector3(-35.0, 0.0, -20.0)],
	])
	_add_rot_track(a, "Hip/LegL", [
		[0.0, Vector3(-20.0, 0.0, 8.0)],
		[0.25, Vector3(15.0, 0.0, 10.0)],
		[0.7, Vector3(-10.0, 0.0, 6.0)],
	])
	_add_rot_track(a, "Hip/LegR", [
		[0.0, Vector3(-10.0, 0.0, -8.0)],
		[0.25, Vector3(25.0, 0.0, -10.0)],
		[0.7, Vector3(-5.0, 0.0, -6.0)],
	])
	return a


func _make_slide() -> Animation:
	var a := Animation.new()
	a.length = 0.45
	a.loop_mode = Animation.LOOP_NONE
	_add_pos_track(a, "Hip", [
		[0.0, Vector3(0.0, 0.95, 0.0)],
		[0.12, Vector3(0.0, 0.45, 0.15)],
		[0.45, Vector3(0.0, 0.4, 0.2)],
	])
	_add_rot_track(a, "Hip", [
		[0.0, Vector3.ZERO],
		[0.15, Vector3(70.0, 0.0, 0.0)],
		[0.45, Vector3(75.0, 0.0, 0.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmL", [
		[0.0, Vector3(20.0, 0.0, 30.0)],
		[0.45, Vector3(10.0, 0.0, 50.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmR", [
		[0.0, Vector3(20.0, 0.0, -30.0)],
		[0.45, Vector3(-40.0, 0.0, -20.0)],
	])
	_add_rot_track(a, "Hip/LegL", [
		[0.0, Vector3.ZERO],
		[0.45, Vector3(-20.0, 0.0, 5.0)],
	])
	_add_rot_track(a, "Hip/LegR", [
		[0.0, Vector3.ZERO],
		[0.45, Vector3(35.0, 0.0, -5.0)],
	])
	return a


func _make_death() -> Animation:
	var a := Animation.new()
	a.length = 0.85
	a.loop_mode = Animation.LOOP_NONE
	_add_pos_track(a, "Hip", [
		[0.0, Vector3(0.0, 0.95, 0.0)],
		[0.25, Vector3(0.15, 0.7, 0.1)],
		[0.55, Vector3(0.25, 0.25, 0.35)],
		[0.85, Vector3(0.3, 0.15, 0.45)],
	])
	_add_rot_track(a, "Hip", [
		[0.0, Vector3.ZERO],
		[0.3, Vector3(25.0, 35.0, -20.0)],
		[0.85, Vector3(85.0, 50.0, -15.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmL", [
		[0.0, Vector3.ZERO],
		[0.4, Vector3(-60.0, 0.0, 40.0)],
		[0.85, Vector3(-20.0, 0.0, 70.0)],
	])
	_add_rot_track(a, "Hip/Torso/ArmR", [
		[0.0, Vector3.ZERO],
		[0.4, Vector3(-40.0, 0.0, -55.0)],
		[0.85, Vector3(10.0, 0.0, -80.0)],
	])
	_add_rot_track(a, "Hip/LegL", [
		[0.0, Vector3.ZERO],
		[0.85, Vector3(-30.0, 0.0, 15.0)],
	])
	_add_rot_track(a, "Hip/LegR", [
		[0.0, Vector3.ZERO],
		[0.85, Vector3(50.0, 0.0, -20.0)],
	])
	return a
