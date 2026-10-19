extends Node3D
## WitchRunner — wraps imported Witch skeletal FBX with authored locomotion clips.
## API matches HoodedRunner: play(idle/run/jump/slide/death), apply_tint/clear_tint.

signal animation_changed(anim_name: String)

const ANIM_IDLE: String = "idle"
const ANIM_RUN: String = "run"
const ANIM_JUMP: String = "jump"
const ANIM_SLIDE: String = "slide"
const ANIM_DEATH: String = "death"

## AdvancedSkeleton (Maya) bones typically aim along local +X; swing uses local ±Z.
const SWING_AXIS: Vector3 = Vector3(0.0, 0.0, 1.0)
const TWIST_AXIS: Vector3 = Vector3(1.0, 0.0, 0.0)
const SIDE_AXIS: Vector3 = Vector3(0.0, 1.0, 0.0)

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var model_root: Node3D = $Model

var _skeleton: Skeleton3D = null
var _current: String = ""
var _locked: bool = false
var _body_materials: Array[StandardMaterial3D] = []
var _normal_colors: Array[Color] = []

## Bone indices (resolved in _ready).
var _bone_hip_l: int = -1
var _bone_hip_r: int = -1
var _bone_knee_l: int = -1
var _bone_knee_r: int = -1
var _bone_shoulder_l: int = -1
var _bone_shoulder_r: int = -1
var _bone_elbow_l: int = -1
var _bone_elbow_r: int = -1
var _bone_spine1: int = -1
var _bone_spine2: int = -1
var _bone_chest: int = -1
var _bone_neck: int = -1
var _bone_head: int = -1
var _bone_root_m: int = -1


func _ready() -> void:
	_skeleton = _find_skeleton(model_root)
	if _skeleton == null:
		push_error("WitchRunner: Skeleton3D not found under Model")
		return
	_resolve_bones()
	_setup_materials()
	_ensure_animations()
	## Remove imported Take 001 player so it cannot override bone poses.
	var embedded: AnimationPlayer = _find_embedded_player(model_root)
	if embedded != null and embedded != anim_player:
		embedded.queue_free()
	play(ANIM_IDLE, true)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f: Skeleton3D = _find_skeleton(c)
		if f != null:
			return f
	return null


func _find_embedded_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var f: AnimationPlayer = _find_embedded_player(c)
		if f != null:
			return f
	return null


func _resolve_bones() -> void:
	_bone_hip_l = _skeleton.find_bone("Hip_L")
	_bone_hip_r = _skeleton.find_bone("Hip_R")
	_bone_knee_l = _skeleton.find_bone("Knee_L")
	_bone_knee_r = _skeleton.find_bone("Knee_R")
	_bone_shoulder_l = _skeleton.find_bone("Shoulder_L")
	_bone_shoulder_r = _skeleton.find_bone("Shoulder_R")
	_bone_elbow_l = _skeleton.find_bone("Elbow_L")
	_bone_elbow_r = _skeleton.find_bone("Elbow_R")
	_bone_spine1 = _skeleton.find_bone("Spine1_M")
	_bone_spine2 = _skeleton.find_bone("Spine2_M")
	_bone_chest = _skeleton.find_bone("Chest_M")
	_bone_neck = _skeleton.find_bone("Neck_M")
	_bone_head = _skeleton.find_bone("Head_M")
	_bone_root_m = _skeleton.find_bone("Root_M")


func _setup_materials() -> void:
	## Keep FBX materials. Colors live as VERTEX COLORS on the mesh; the imported
	## StandardMaterial3D already has vertex_color_use_as_albedo=true. Do NOT replace
	## with blank material_override — that made the witch a near-black silhouette.
	_body_materials.clear()
	_normal_colors.clear()
	var seen: Dictionary = {}
	var meshes: Array[MeshInstance3D] = _collect_meshes(model_root)
	for mi in meshes:
		mi.visible = true
		mi.layers = 1
		## Clear any leftover override from older builds.
		mi.material_override = null
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			if src == null:
				## Ensure vertex colors still render if a surface lost its mat.
				var fallback := StandardMaterial3D.new()
				fallback.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
				fallback.vertex_color_use_as_albedo = true
				fallback.roughness = 0.55
				mi.set_surface_override_material(s, fallback)
				_body_materials.append(fallback)
				_normal_colors.append(fallback.albedo_color)
				continue
			## Duplicate once per unique imported resource so tinting is safe.
			var key: int = src.get_instance_id()
			var std: StandardMaterial3D
			if seen.has(key):
				std = seen[key] as StandardMaterial3D
				mi.set_surface_override_material(s, std)
				continue
			if src is StandardMaterial3D:
				std = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				std = StandardMaterial3D.new()
				std.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			std.vertex_color_use_as_albedo = true
			## Keep albedo near white so vertex colors drive the look.
			if std.albedo_color.r < 0.2 and std.albedo_color.g < 0.2 and std.albedo_color.b < 0.2:
				std.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			std.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mi.set_surface_override_material(s, std)
			seen[key] = std
			_body_materials.append(std)
			_normal_colors.append(std.albedo_color)


func _collect_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_collect_meshes(c))
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
	if _skeleton != null:
		_skeleton.reset_bone_poses()
	play(ANIM_IDLE, true)


func get_current_animation() -> String:
	return _current


func apply_tint(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0, alpha: float = 1.0) -> void:
	for i in _body_materials.size():
		var mat: StandardMaterial3D = _body_materials[i]
		var base: Color = _normal_colors[i]
		## Multiply-style tint keeps vertex colors readable under power-up FX.
		var tinted: Color = Color(base.r * color.r, base.g * color.g, base.b * color.b, alpha)
		## Soft lerp so ghost/cursed still reads on top of vertex paint.
		tinted = base.lerp(tinted, 0.85)
		tinted.a = alpha
		mat.albedo_color = tinted
		mat.vertex_color_use_as_albedo = true
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
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 1.0


func _ensure_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(ANIM_IDLE, _make_idle())
	lib.add_animation(ANIM_RUN, _make_run())
	lib.add_animation(ANIM_JUMP, _make_jump())
	lib.add_animation(ANIM_SLIDE, _make_slide())
	lib.add_animation(ANIM_DEATH, _make_death())
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", lib)


func _skel_path() -> String:
	## Paths are relative to this node (AnimationPlayer parent).
	return String(get_path_to(_skeleton))


func _bone_path(bone_name: String) -> String:
	return "%s:%s" % [_skel_path(), bone_name]


func _quat_axis(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


func _add_bone_rot(anim: Animation, bone_name: String, keys: Array) -> void:
	## keys: Array of [time: float, degrees: float] around SWING_AXIS, OR
	## [time, Quaternion] / [time, Vector3 euler_degrees on swing/side/twist].
	if _skeleton.find_bone(bone_name) < 0:
		return
	var idx: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, NodePath(_bone_path(bone_name)))
	for key in keys:
		var t: float = float(key[0])
		var q: Quaternion
		var payload: Variant = key[1]
		if payload is Quaternion:
			q = payload as Quaternion
		elif payload is Vector3:
			var e: Vector3 = payload as Vector3
			q = _quat_axis(SWING_AXIS, e.x) * _quat_axis(SIDE_AXIS, e.y) * _quat_axis(TWIST_AXIS, e.z)
		else:
			q = _quat_axis(SWING_AXIS, float(payload))
		anim.rotation_track_insert_key(idx, t, q)


func _add_bone_pos(anim: Animation, bone_name: String, keys: Array) -> void:
	if _skeleton.find_bone(bone_name) < 0:
		return
	var idx: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(idx, NodePath(_bone_path(bone_name)))
	for key in keys:
		anim.position_track_insert_key(idx, float(key[0]), key[1] as Vector3)


func _make_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	_add_bone_rot(a, "Spine2_M", [
		[0.0, 2.0], [1.0, -2.0], [2.0, 2.0],
	])
	_add_bone_rot(a, "Chest_M", [
		[0.0, 1.5], [1.0, -1.5], [2.0, 1.5],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, Vector3(3.0, 4.0, 0.0)],
		[1.0, Vector3(-2.0, -4.0, 0.0)],
		[2.0, Vector3(3.0, 4.0, 0.0)],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 8.0], [1.0, 12.0], [2.0, 8.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 8.0], [1.0, 12.0], [2.0, 8.0],
	])
	_add_bone_rot(a, "Elbow_L", [[0.0, 15.0], [2.0, 15.0]])
	_add_bone_rot(a, "Elbow_R", [[0.0, 15.0], [2.0, 15.0]])
	_add_bone_rot(a, "Hip_L", [[0.0, 2.0], [2.0, 2.0]])
	_add_bone_rot(a, "Hip_R", [[0.0, 2.0], [2.0, 2.0]])
	return a


func _make_run() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	## Opposite limb phase — readable at runner camera distance.
	_add_bone_rot(a, "Hip_L", [
		[0.0, -48.0], [0.3, 42.0], [0.6, -48.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 42.0], [0.3, -48.0], [0.6, 42.0],
	])
	_add_bone_rot(a, "Knee_L", [
		[0.0, 70.0], [0.15, 25.0], [0.3, 12.0], [0.45, 55.0], [0.6, 70.0],
	])
	_add_bone_rot(a, "Knee_R", [
		[0.0, 12.0], [0.15, 55.0], [0.3, 70.0], [0.45, 25.0], [0.6, 12.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 48.0], [0.3, -42.0], [0.6, 48.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, -42.0], [0.3, 48.0], [0.6, -42.0],
	])
	_add_bone_rot(a, "Elbow_L", [
		[0.0, 65.0], [0.3, 28.0], [0.6, 65.0],
	])
	_add_bone_rot(a, "Elbow_R", [
		[0.0, 28.0], [0.3, 65.0], [0.6, 28.0],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, Vector3(6.0, 8.0, 0.0)],
		[0.3, Vector3(6.0, -8.0, 0.0)],
		[0.6, Vector3(6.0, 8.0, 0.0)],
	])
	_add_bone_rot(a, "Chest_M", [
		[0.0, Vector3(4.0, -6.0, 0.0)],
		[0.3, Vector3(4.0, 6.0, 0.0)],
		[0.6, Vector3(4.0, -6.0, 0.0)],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, Vector3(-8.0, -5.0, 0.0)],
		[0.3, Vector3(-8.0, 5.0, 0.0)],
		[0.6, Vector3(-8.0, -5.0, 0.0)],
	])
	## Soft vertical bob via Root_M pose position (rest is ~y 0.9 in bone space).
	if _bone_root_m >= 0:
		var rest_origin: Vector3 = _skeleton.get_bone_rest(_bone_root_m).origin
		_add_bone_pos(a, "Root_M", [
			[0.0, rest_origin],
			[0.15, rest_origin + Vector3(0.0, 0.04, 0.0)],
			[0.3, rest_origin],
			[0.45, rest_origin + Vector3(0.0, 0.04, 0.0)],
			[0.6, rest_origin],
		])
	return a


func _make_jump() -> Animation:
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_NONE
	_add_bone_rot(a, "Hip_L", [
		[0.0, -15.0], [0.2, 20.0], [0.7, -8.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, -10.0], [0.2, 28.0], [0.7, -5.0],
	])
	_add_bone_rot(a, "Knee_L", [
		[0.0, 40.0], [0.25, 70.0], [0.7, 25.0],
	])
	_add_bone_rot(a, "Knee_R", [
		[0.0, 35.0], [0.25, 65.0], [0.7, 20.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, -55.0], [0.7, -30.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, -55.0], [0.7, -30.0],
	])
	_add_bone_rot(a, "Elbow_L", [[0.0, 20.0], [0.7, 30.0]])
	_add_bone_rot(a, "Elbow_R", [[0.0, 20.0], [0.7, 30.0]])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, -10.0], [0.2, 12.0], [0.7, 4.0],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, 10.0], [0.3, -15.0], [0.7, -5.0],
	])
	return a


func _make_slide() -> Animation:
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_NONE
	_add_bone_rot(a, "Root_M", [
		[0.0, 0.0], [0.15, 55.0], [0.4, 65.0],
	])
	_add_bone_rot(a, "Spine1_M", [
		[0.0, 0.0], [0.4, 15.0],
	])
	_add_bone_rot(a, "Hip_L", [
		[0.0, 0.0], [0.4, -25.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 0.0], [0.4, 40.0],
	])
	_add_bone_rot(a, "Knee_L", [[0.0, 10.0], [0.4, 30.0]])
	_add_bone_rot(a, "Knee_R", [[0.0, 10.0], [0.4, 80.0]])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 10.0], [0.4, 50.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 10.0], [0.4, -40.0],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, 0.0], [0.4, 20.0],
	])
	if _bone_root_m >= 0:
		var rest_origin: Vector3 = _skeleton.get_bone_rest(_bone_root_m).origin
		_add_bone_pos(a, "Root_M", [
			[0.0, rest_origin],
			[0.4, rest_origin + Vector3(0.0, -0.35, 0.12)],
		])
	return a


func _make_death() -> Animation:
	var a := Animation.new()
	a.length = 0.9
	a.loop_mode = Animation.LOOP_NONE
	_add_bone_rot(a, "Root_M", [
		[0.0, 0.0],
		[0.35, Vector3(25.0, 40.0, -15.0)],
		[0.9, Vector3(80.0, 55.0, -10.0)],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, 0.0], [0.9, 35.0],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, 0.0], [0.5, -30.0], [0.9, 15.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 0.0], [0.4, -70.0], [0.9, -20.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 0.0], [0.4, -50.0], [0.9, 15.0],
	])
	_add_bone_rot(a, "Hip_L", [
		[0.0, 0.0], [0.9, -35.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 0.0], [0.9, 55.0],
	])
	_add_bone_rot(a, "Knee_L", [[0.0, 5.0], [0.9, 40.0]])
	_add_bone_rot(a, "Knee_R", [[0.0, 5.0], [0.9, 70.0]])
	if _bone_root_m >= 0:
		var rest_origin: Vector3 = _skeleton.get_bone_rest(_bone_root_m).origin
		_add_bone_pos(a, "Root_M", [
			[0.0, rest_origin],
			[0.5, rest_origin + Vector3(0.1, -0.4, 0.2)],
			[0.9, rest_origin + Vector3(0.2, -0.7, 0.35)],
		])
	return a
