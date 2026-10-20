extends Node3D
## WitchRunner — AnimationTree locomotion (Idle↔Run↔Jump↔Slide↔Ghost↔Death).
## API: play(name), update_locomotion(...), apply_tint/clear_tint.

signal animation_changed(anim_name: String)

const ANIM_IDLE: String = "idle"
const ANIM_RUN: String = "run"
const ANIM_JUMP: String = "jump"
const ANIM_SLIDE: String = "slide"
const ANIM_DEATH: String = "death"
const ANIM_GHOST: String = "ghost"

const SWING_AXIS: Vector3 = Vector3(0.0, 0.0, 1.0)
const TWIST_AXIS: Vector3 = Vector3(1.0, 0.0, 0.0)
const SIDE_AXIS: Vector3 = Vector3(0.0, 1.0, 0.0)

const REF_RUN_SPEED: float = 13.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var model_root: Node3D = $Model

var anim_tree: AnimationTree = null
var _playback: AnimationNodeStateMachinePlayback = null
var _skeleton: Skeleton3D = null
var _current: String = ""
var _locked: bool = false
var _body_materials: Array[StandardMaterial3D] = []
var _normal_colors: Array[Color] = []
var _ghost_visual: bool = false
var _land_blend_t: float = 0.0

var _bone_root_m: int = -1


func _ready() -> void:
	_skeleton = _find_skeleton(model_root)
	if _skeleton == null:
		push_error("WitchRunner: Skeleton3D not found under Model")
		return
	_bone_root_m = _skeleton.find_bone("Root_M")
	_setup_materials()
	_ensure_animations()
	_build_animation_tree()
	var embedded: AnimationPlayer = _find_embedded_player(model_root)
	if embedded != null and embedded != anim_player:
		embedded.queue_free()
	play(ANIM_IDLE, true)


func _process(delta: float) -> void:
	if _land_blend_t > 0.0:
		_land_blend_t = maxf(0.0, _land_blend_t - delta)


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


func _setup_materials() -> void:
	_body_materials.clear()
	_normal_colors.clear()
	var seen: Dictionary = {}
	var meshes: Array[MeshInstance3D] = _collect_meshes(model_root)
	for mi in meshes:
		mi.visible = true
		mi.layers = 1
		mi.material_override = null
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			if src == null:
				var fallback := StandardMaterial3D.new()
				fallback.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
				fallback.vertex_color_use_as_albedo = true
				fallback.roughness = 0.55
				mi.set_surface_override_material(s, fallback)
				_body_materials.append(fallback)
				_normal_colors.append(fallback.albedo_color)
				continue
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
			if std.albedo_color.r < 0.2 and std.albedo_color.g < 0.2 and std.albedo_color.b < 0.2:
				std.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			## FBX points at Textures_export/M_witch_Base_color.png. Prefer vertex
			## colors: keep a valid white multiply texture if present, drop broken/empty slots.
			if std.albedo_texture != null:
				var tex_path: String = str(std.albedo_texture.resource_path)
				if tex_path == "" or tex_path == "res://":
					std.albedo_texture = null
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


## Simple API (menu / legacy). Maps to AnimationTree travel.
func play(anim_name: String, force: bool = false) -> void:
	if _locked and anim_name != ANIM_DEATH and not force:
		return
	if anim_name == ANIM_DEATH:
		_locked = true
	if not force and _current == anim_name:
		return
	_travel(anim_name, force)
	_current = anim_name
	animation_changed.emit(anim_name)


## Preferred driver from PlayerController — smooth state + run-speed scale.
func update_locomotion(
	alive: bool,
	sliding: bool,
	on_floor: bool,
	run_speed: float,
	ghost: bool,
	playing: bool,
	just_landed: bool = false,
	force: bool = false
) -> void:
	_ghost_visual = ghost
	if not alive or _locked:
		_travel(ANIM_DEATH, true)
		_current = ANIM_DEATH
		return
	## Run cadence scales with speed (clamped so it never looks frantic).
	var speed_scale: float = clampf(run_speed / REF_RUN_SPEED, 0.85, 1.55)
	if anim_tree:
		anim_tree.set("parameters/Run/scale/scale", speed_scale)
		anim_tree.set("parameters/Ghost/scale/scale", speed_scale * 0.85)
	if just_landed:
		_land_blend_t = 0.22
	var want: String = ANIM_IDLE
	if sliding:
		want = ANIM_SLIDE
	elif not on_floor:
		want = ANIM_JUMP
	elif playing and run_speed > 0.5:
		want = ANIM_GHOST if ghost else ANIM_RUN
	elif ghost:
		want = ANIM_GHOST
	else:
		want = ANIM_IDLE
	## Soft land: briefly prefer Run blend after touchdown even if jump still finishing.
	if _land_blend_t > 0.0 and on_floor and not sliding and want == ANIM_JUMP:
		want = ANIM_GHOST if ghost else ANIM_RUN
	if force or want != _current:
		_travel(want, force)
		_current = want
		animation_changed.emit(want)


func reset_pose() -> void:
	_locked = false
	_current = ""
	_land_blend_t = 0.0
	if _skeleton != null:
		_skeleton.reset_bone_poses()
	play(ANIM_IDLE, true)


func get_current_animation() -> String:
	return _current


func apply_tint(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0, alpha: float = 1.0) -> void:
	for i in _body_materials.size():
		var mat: StandardMaterial3D = _body_materials[i]
		var base: Color = _normal_colors[i]
		var tinted: Color = Color(base.r * color.r, base.g * color.g, base.b * color.b, alpha)
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


# --- AnimationTree -----------------------------------------------------------

func _build_animation_tree() -> void:
	if anim_tree != null:
		anim_tree.queue_free()
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.anim_player = anim_player.get_path()
	add_child(anim_tree)
	var sm := AnimationNodeStateMachine.new()
	## Nodes
	sm.add_node("Idle", _anim_node(ANIM_IDLE), Vector2(0, 80))
	sm.add_node("Run", _scaled_anim_node(ANIM_RUN, "scale"), Vector2(220, 80))
	sm.add_node("Jump", _anim_node(ANIM_JUMP), Vector2(440, 0))
	sm.add_node("Slide", _anim_node(ANIM_SLIDE), Vector2(440, 160))
	sm.add_node("Ghost", _scaled_anim_node(ANIM_GHOST, "scale"), Vector2(220, 200))
	sm.add_node("Death", _anim_node(ANIM_DEATH), Vector2(660, 80))
	## Transitions (bidirectional where needed).
	_add_tr(sm, "Idle", "Run", 0.18)
	_add_tr(sm, "Run", "Idle", 0.2)
	_add_tr(sm, "Idle", "Jump", 0.08)
	_add_tr(sm, "Run", "Jump", 0.06)
	_add_tr(sm, "Ghost", "Jump", 0.08)
	_add_tr(sm, "Jump", "Run", 0.16)
	_add_tr(sm, "Jump", "Idle", 0.18)
	_add_tr(sm, "Jump", "Ghost", 0.16)
	_add_tr(sm, "Idle", "Slide", 0.1)
	_add_tr(sm, "Run", "Slide", 0.08)
	_add_tr(sm, "Ghost", "Slide", 0.1)
	_add_tr(sm, "Slide", "Run", 0.22)
	_add_tr(sm, "Slide", "Idle", 0.22)
	_add_tr(sm, "Slide", "Ghost", 0.22)
	_add_tr(sm, "Idle", "Ghost", 0.2)
	_add_tr(sm, "Run", "Ghost", 0.18)
	_add_tr(sm, "Ghost", "Run", 0.2)
	_add_tr(sm, "Ghost", "Idle", 0.2)
	## Death from anywhere.
	for from_name in ["Idle", "Run", "Jump", "Slide", "Ghost"]:
		_add_tr(sm, from_name, "Death", 0.12)
	## Start → Idle
	var start_tr := AnimationNodeStateMachineTransition.new()
	start_tr.xfade_time = 0.0
	sm.add_transition("Start", "Idle", start_tr)
	anim_tree.tree_root = sm
	anim_tree.active = true
	_playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _playback:
		_playback.start("Idle")


func _anim_node(anim_name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = anim_name
	return n


func _scaled_anim_node(anim_name: String, scale_node: String) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var anim_n := AnimationNodeAnimation.new()
	anim_n.animation = anim_name
	bt.add_node("anim", anim_n, Vector2(0, 0))
	var ts := AnimationNodeTimeScale.new()
	bt.add_node(scale_node, ts, Vector2(220, 0))
	bt.connect_node(scale_node, 0, "anim")
	bt.connect_node("output", 0, scale_node)
	return bt


func _add_tr(sm: AnimationNodeStateMachine, from_name: String, to_name: String, xfade: float) -> void:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	t.reset = true
	sm.add_transition(from_name, to_name, t)


func _travel(anim_name: String, force: bool = false) -> void:
	var state: String = _state_for_anim(anim_name)
	if _playback == null:
		if anim_player and anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
		return
	var cur: String = str(_playback.get_current_node())
	if not force and cur == state:
		return
	## Death is terminal.
	if cur == "Death" and state != "Death":
		return
	_playback.travel(state)


func _state_for_anim(anim_name: String) -> String:
	match anim_name:
		ANIM_IDLE:
			return "Idle"
		ANIM_RUN:
			return "Run"
		ANIM_JUMP:
			return "Jump"
		ANIM_SLIDE:
			return "Slide"
		ANIM_GHOST:
			return "Ghost"
		ANIM_DEATH:
			return "Death"
		_:
			return "Idle"


# --- Clip authoring ----------------------------------------------------------

func _ensure_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(ANIM_IDLE, _make_idle())
	lib.add_animation(ANIM_RUN, _make_run())
	lib.add_animation(ANIM_JUMP, _make_jump())
	lib.add_animation(ANIM_SLIDE, _make_slide())
	lib.add_animation(ANIM_DEATH, _make_death())
	lib.add_animation(ANIM_GHOST, _make_ghost())
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", lib)
	anim_player.playback_default_blend_time = 0.12


func _skel_path() -> String:
	return String(get_path_to(_skeleton))


func _bone_path(bone_name: String) -> String:
	return "%s:%s" % [_skel_path(), bone_name]


func _quat_axis(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


func _add_bone_rot(anim: Animation, bone_name: String, keys: Array) -> void:
	if _skeleton.find_bone(bone_name) < 0:
		return
	var idx: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, NodePath(_bone_path(bone_name)))
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
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
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
	for key in keys:
		anim.position_track_insert_key(idx, float(key[0]), key[1] as Vector3)


func _rest_root() -> Vector3:
	if _bone_root_m < 0:
		return Vector3.ZERO
	return _skeleton.get_bone_rest(_bone_root_m).origin


func _make_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.4
	a.loop_mode = Animation.LOOP_LINEAR
	## Soft breath + weight shift — less stiff than a flat hold.
	_add_bone_rot(a, "Spine1_M", [
		[0.0, Vector3(2.0, 0.0, 0.0)],
		[1.2, Vector3(-1.5, 0.0, 0.0)],
		[2.4, Vector3(2.0, 0.0, 0.0)],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, Vector3(3.0, 3.0, 0.0)],
		[1.2, Vector3(-2.0, -3.0, 0.0)],
		[2.4, Vector3(3.0, 3.0, 0.0)],
	])
	_add_bone_rot(a, "Chest_M", [
		[0.0, Vector3(2.0, -2.0, 0.0)],
		[1.2, Vector3(-1.0, 2.5, 0.0)],
		[2.4, Vector3(2.0, -2.0, 0.0)],
	])
	_add_bone_rot(a, "Neck_M", [
		[0.0, 2.0], [1.2, -2.0], [2.4, 2.0],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, Vector3(4.0, 6.0, 0.0)],
		[0.8, Vector3(1.0, 2.0, 0.0)],
		[1.6, Vector3(-3.0, -6.0, 0.0)],
		[2.4, Vector3(4.0, 6.0, 0.0)],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 10.0], [1.2, 16.0], [2.4, 10.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 12.0], [1.2, 8.0], [2.4, 12.0],
	])
	_add_bone_rot(a, "Elbow_L", [[0.0, 18.0], [1.2, 22.0], [2.4, 18.0]])
	_add_bone_rot(a, "Elbow_R", [[0.0, 20.0], [1.2, 16.0], [2.4, 20.0]])
	_add_bone_rot(a, "Hip_L", [
		[0.0, 4.0], [1.2, 1.0], [2.4, 4.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 2.0], [1.2, 5.0], [2.4, 2.0],
	])
	_add_bone_rot(a, "Knee_L", [[0.0, 8.0], [2.4, 8.0]])
	_add_bone_rot(a, "Knee_R", [[0.0, 10.0], [2.4, 10.0]])
	var root: Vector3 = _rest_root()
	_add_bone_pos(a, "Root_M", [
		[0.0, root],
		[1.2, root + Vector3(0.0, 0.015, 0.0)],
		[2.4, root],
	])
	return a


func _make_run() -> Animation:
	var a := Animation.new()
	a.length = 0.72
	a.loop_mode = Animation.LOOP_LINEAR
	## 4-phase cycle: contact → mid → opposite contact → mid (more natural than 2-key ping-pong).
	_add_bone_rot(a, "Hip_L", [
		[0.0, -38.0], [0.18, -10.0], [0.36, 40.0], [0.54, 8.0], [0.72, -38.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 40.0], [0.18, 8.0], [0.36, -38.0], [0.54, -10.0], [0.72, 40.0],
	])
	_add_bone_rot(a, "Knee_L", [
		[0.0, 58.0], [0.12, 22.0], [0.36, 14.0], [0.5, 48.0], [0.62, 72.0], [0.72, 58.0],
	])
	_add_bone_rot(a, "Knee_R", [
		[0.0, 14.0], [0.12, 48.0], [0.24, 72.0], [0.36, 58.0], [0.5, 22.0], [0.72, 14.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 42.0], [0.18, 12.0], [0.36, -36.0], [0.54, -8.0], [0.72, 42.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, -36.0], [0.18, -8.0], [0.36, 42.0], [0.54, 12.0], [0.72, -36.0],
	])
	_add_bone_rot(a, "Elbow_L", [
		[0.0, 58.0], [0.36, 32.0], [0.72, 58.0],
	])
	_add_bone_rot(a, "Elbow_R", [
		[0.0, 32.0], [0.36, 58.0], [0.72, 32.0],
	])
	_add_bone_rot(a, "Spine1_M", [
		[0.0, Vector3(5.0, 4.0, 0.0)],
		[0.36, Vector3(5.0, -4.0, 0.0)],
		[0.72, Vector3(5.0, 4.0, 0.0)],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, Vector3(7.0, 7.0, 0.0)],
		[0.36, Vector3(7.0, -7.0, 0.0)],
		[0.72, Vector3(7.0, 7.0, 0.0)],
	])
	_add_bone_rot(a, "Chest_M", [
		[0.0, Vector3(3.0, -5.0, 0.0)],
		[0.36, Vector3(3.0, 5.0, 0.0)],
		[0.72, Vector3(3.0, -5.0, 0.0)],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, Vector3(-6.0, -4.0, 0.0)],
		[0.36, Vector3(-6.0, 4.0, 0.0)],
		[0.72, Vector3(-6.0, -4.0, 0.0)],
	])
	var root: Vector3 = _rest_root()
	_add_bone_pos(a, "Root_M", [
		[0.0, root],
		[0.18, root + Vector3(0.0, 0.035, 0.0)],
		[0.36, root],
		[0.54, root + Vector3(0.0, 0.035, 0.0)],
		[0.72, root],
	])
	return a


func _make_jump() -> Animation:
	var a := Animation.new()
	a.length = 0.95
	a.loop_mode = Animation.LOOP_NONE
	## Anticipation crouch → extend → air tuck → land bend.
	_add_bone_rot(a, "Hip_L", [
		[0.0, 18.0], [0.12, 35.0], [0.28, -8.0], [0.55, 12.0], [0.78, 40.0], [0.95, 16.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 14.0], [0.12, 30.0], [0.28, 5.0], [0.55, 18.0], [0.78, 36.0], [0.95, 12.0],
	])
	_add_bone_rot(a, "Knee_L", [
		[0.0, 35.0], [0.12, 70.0], [0.3, 45.0], [0.55, 55.0], [0.78, 78.0], [0.95, 28.0],
	])
	_add_bone_rot(a, "Knee_R", [
		[0.0, 30.0], [0.12, 65.0], [0.3, 40.0], [0.55, 50.0], [0.78, 72.0], [0.95, 24.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 20.0], [0.12, -15.0], [0.3, -60.0], [0.55, -45.0], [0.8, 10.0], [0.95, 15.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 18.0], [0.12, -12.0], [0.3, -58.0], [0.55, -42.0], [0.8, 8.0], [0.95, 12.0],
	])
	_add_bone_rot(a, "Elbow_L", [
		[0.0, 40.0], [0.3, 25.0], [0.55, 35.0], [0.95, 30.0],
	])
	_add_bone_rot(a, "Elbow_R", [
		[0.0, 38.0], [0.3, 22.0], [0.55, 32.0], [0.95, 28.0],
	])
	_add_bone_rot(a, "Spine1_M", [
		[0.0, 8.0], [0.12, 18.0], [0.3, -8.0], [0.78, 16.0], [0.95, 4.0],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, 6.0], [0.12, 14.0], [0.3, -6.0], [0.78, 12.0], [0.95, 2.0],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, 8.0], [0.12, 15.0], [0.35, -18.0], [0.78, 10.0], [0.95, -2.0],
	])
	var root: Vector3 = _rest_root()
	_add_bone_pos(a, "Root_M", [
		[0.0, root],
		[0.12, root + Vector3(0.0, -0.08, 0.02)],
		[0.3, root + Vector3(0.0, 0.06, -0.02)],
		[0.55, root + Vector3(0.0, 0.04, 0.0)],
		[0.78, root + Vector3(0.0, -0.12, 0.04)],
		[0.95, root + Vector3(0.0, -0.02, 0.0)],
	])
	return a


func _make_slide() -> Animation:
	var a := Animation.new()
	a.length = 0.85
	a.loop_mode = Animation.LOOP_NONE
	## Dive into low lean, hold compact slide pose (readable crouch).
	_add_bone_rot(a, "Root_M", [
		[0.0, 0.0], [0.18, Vector3(48.0, 8.0, -6.0)], [0.55, Vector3(62.0, 10.0, -8.0)], [0.85, Vector3(58.0, 8.0, -6.0)],
	])
	_add_bone_rot(a, "Spine1_M", [
		[0.0, 0.0], [0.25, 18.0], [0.85, 22.0],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, 0.0], [0.25, 12.0], [0.85, 16.0],
	])
	_add_bone_rot(a, "Chest_M", [
		[0.0, 0.0], [0.3, Vector3(10.0, -12.0, 0.0)], [0.85, Vector3(12.0, -14.0, 0.0)],
	])
	_add_bone_rot(a, "Hip_L", [
		[0.0, 0.0], [0.3, -30.0], [0.85, -28.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 0.0], [0.3, 48.0], [0.85, 52.0],
	])
	_add_bone_rot(a, "Knee_L", [[0.0, 12.0], [0.3, 35.0], [0.85, 40.0]])
	_add_bone_rot(a, "Knee_R", [[0.0, 12.0], [0.3, 85.0], [0.85, 90.0]])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 10.0], [0.3, 55.0], [0.85, 60.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 10.0], [0.3, -50.0], [0.85, -45.0],
	])
	_add_bone_rot(a, "Elbow_L", [[0.0, 20.0], [0.85, 45.0]])
	_add_bone_rot(a, "Elbow_R", [[0.0, 20.0], [0.85, 35.0]])
	_add_bone_rot(a, "Head_M", [
		[0.0, 0.0], [0.3, Vector3(18.0, -8.0, 0.0)], [0.85, Vector3(22.0, -10.0, 0.0)],
	])
	var root: Vector3 = _rest_root()
	_add_bone_pos(a, "Root_M", [
		[0.0, root],
		[0.25, root + Vector3(0.02, -0.28, 0.1)],
		[0.85, root + Vector3(0.03, -0.38, 0.14)],
	])
	return a


func _make_ghost() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	## Floaty, longer stride, trailing arms — reads as phase form while moving.
	_add_bone_rot(a, "Hip_L", [
		[0.0, -28.0], [0.25, 8.0], [0.5, 32.0], [0.75, -6.0], [1.0, -28.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 32.0], [0.25, -6.0], [0.5, -28.0], [0.75, 8.0], [1.0, 32.0],
	])
	_add_bone_rot(a, "Knee_L", [
		[0.0, 40.0], [0.5, 18.0], [1.0, 40.0],
	])
	_add_bone_rot(a, "Knee_R", [
		[0.0, 18.0], [0.5, 40.0], [1.0, 18.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, Vector3(-25.0, 10.0, 0.0)],
		[0.5, Vector3(-40.0, -8.0, 0.0)],
		[1.0, Vector3(-25.0, 10.0, 0.0)],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, Vector3(-40.0, -8.0, 0.0)],
		[0.5, Vector3(-25.0, 10.0, 0.0)],
		[1.0, Vector3(-40.0, -8.0, 0.0)],
	])
	_add_bone_rot(a, "Elbow_L", [[0.0, 25.0], [0.5, 40.0], [1.0, 25.0]])
	_add_bone_rot(a, "Elbow_R", [[0.0, 40.0], [0.5, 25.0], [1.0, 40.0]])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, Vector3(-4.0, 6.0, 0.0)],
		[0.5, Vector3(-4.0, -6.0, 0.0)],
		[1.0, Vector3(-4.0, 6.0, 0.0)],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, Vector3(-10.0, 8.0, 0.0)],
		[0.5, Vector3(-10.0, -8.0, 0.0)],
		[1.0, Vector3(-10.0, 8.0, 0.0)],
	])
	var root: Vector3 = _rest_root()
	_add_bone_pos(a, "Root_M", [
		[0.0, root + Vector3(0.0, 0.06, 0.0)],
		[0.5, root + Vector3(0.0, 0.12, 0.0)],
		[1.0, root + Vector3(0.0, 0.06, 0.0)],
	])
	return a


func _make_death() -> Animation:
	var a := Animation.new()
	a.length = 1.15
	a.loop_mode = Animation.LOOP_NONE
	## Stagger → collapse → settle (holds final pose).
	_add_bone_rot(a, "Root_M", [
		[0.0, 0.0],
		[0.2, Vector3(12.0, -18.0, 8.0)],
		[0.55, Vector3(45.0, 35.0, -12.0)],
		[0.9, Vector3(78.0, 50.0, -8.0)],
		[1.15, Vector3(82.0, 52.0, -6.0)],
	])
	_add_bone_rot(a, "Spine1_M", [
		[0.0, 0.0], [0.4, 20.0], [1.15, 40.0],
	])
	_add_bone_rot(a, "Spine2_M", [
		[0.0, 0.0], [0.5, 28.0], [1.15, 42.0],
	])
	_add_bone_rot(a, "Head_M", [
		[0.0, 0.0], [0.25, -25.0], [0.7, 20.0], [1.15, 28.0],
	])
	_add_bone_rot(a, "Shoulder_L", [
		[0.0, 0.0], [0.3, -75.0], [0.8, -30.0], [1.15, -15.0],
	])
	_add_bone_rot(a, "Shoulder_R", [
		[0.0, 0.0], [0.35, -55.0], [0.8, 20.0], [1.15, 25.0],
	])
	_add_bone_rot(a, "Elbow_L", [[0.0, 15.0], [0.5, 55.0], [1.15, 40.0]])
	_add_bone_rot(a, "Elbow_R", [[0.0, 15.0], [0.5, 45.0], [1.15, 30.0]])
	_add_bone_rot(a, "Hip_L", [
		[0.0, 0.0], [0.5, -40.0], [1.15, -45.0],
	])
	_add_bone_rot(a, "Hip_R", [
		[0.0, 0.0], [0.5, 50.0], [1.15, 60.0],
	])
	_add_bone_rot(a, "Knee_L", [[0.0, 8.0], [0.6, 55.0], [1.15, 50.0]])
	_add_bone_rot(a, "Knee_R", [[0.0, 8.0], [0.6, 75.0], [1.15, 80.0]])
	var root: Vector3 = _rest_root()
	_add_bone_pos(a, "Root_M", [
		[0.0, root],
		[0.35, root + Vector3(0.05, -0.15, 0.08)],
		[0.75, root + Vector3(0.15, -0.45, 0.25)],
		[1.15, root + Vector3(0.22, -0.72, 0.38)],
	])
	return a
