extends Node3D
## Rideable hearse train — 1..4 coupled carriages, optional plank ramp in front.
## Origin = front face (the end the player meets). Carriages extend toward -Z, the ramp
## toward +Z. Roof is walkable (StaticBody on the rideable layer); the body volume below
## the roof is lethal, so the front face / sides are a "change lane or ramp up" obstacle.

const Geo = preload("res://scripts/levels/TrackGeometry.gd")
const Kit = preload("res://scripts/obstacles/ObstacleMeshKit.gd")

var pool_id: String = ""
var lane_index: int = 1
var local_z: float = 0.0
var cars: int = 2
var has_ramp: bool = false
var length_z: float = 0.0

var _body: StaticBody3D
var _body_shape: BoxShape3D
var _ramp: StaticBody3D
var _ramp_col: CollisionShape3D
var _ramp_mesh: MeshInstance3D
var _hazard: Area3D
var _hazard_shape: BoxShape3D
var _car_meshes: Array[MeshInstance3D] = []
var _tail_mesh: MeshInstance3D
var _theme: String = ""
var _dodge_counted: bool = false


func _ready() -> void:
	add_to_group("train")
	_build_nodes()
	set_physics_process(false)


func _build_nodes() -> void:
	if _body != null:
		return
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = Geo.LAYER_RIDEABLE
	_body.collision_mask = 0
	var bcol := CollisionShape3D.new()
	_body_shape = BoxShape3D.new()
	bcol.shape = _body_shape
	_body.add_child(bcol)
	add_child(_body)

	_ramp = StaticBody3D.new()
	_ramp.name = "Ramp"
	_ramp.collision_layer = Geo.LAYER_RIDEABLE
	_ramp.collision_mask = 0
	_ramp_col = CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	var hw: float = 1.0
	wedge.points = PackedVector3Array([
		Vector3(-hw, 0.0, Geo.RAMP_LEN), Vector3(hw, 0.0, Geo.RAMP_LEN),
		Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0),
		Vector3(-hw, Geo.TRAIN_ROOF, 0.0), Vector3(hw, Geo.TRAIN_ROOF, 0.0),
	])
	_ramp_col.shape = wedge
	_ramp.add_child(_ramp_col)
	add_child(_ramp)
	_ramp_mesh = MeshInstance3D.new()
	_ramp_mesh.mesh = _ramp_visual()
	add_child(_ramp_mesh)

	_hazard = Area3D.new()
	_hazard.name = "Hazard"
	_hazard.collision_layer = 4
	_hazard.collision_mask = 2
	_hazard.monitorable = true
	var hcol := CollisionShape3D.new()
	_hazard_shape = BoxShape3D.new()
	hcol.shape = _hazard_shape
	_hazard.add_child(hcol)
	add_child(_hazard)
	_hazard.body_entered.connect(_on_hazard_entered)

	for i in Geo.MAX_CARS:
		var mi := MeshInstance3D.new()
		add_child(mi)
		_car_meshes.append(mi)
	_tail_mesh = MeshInstance3D.new()
	add_child(_tail_mesh)


func configure(lane: int, z_offset: float, extras: Dictionary = {}) -> void:
	_build_nodes()
	lane_index = clampi(lane, 0, Geo.LANE_COUNT - 1)
	local_z = z_offset
	cars = clampi(int(extras.get("cars", 2)), 1, Geo.MAX_CARS)
	has_ramp = bool(extras.get("ramp", false))
	length_z = Geo.train_length(cars)
	position = Vector3(Geo.LANE_X[lane_index], 0.0, local_z)
	rotation = Vector3.ZERO
	_apply_layout()


func _apply_layout() -> void:
	var theme := "castle" if BiomeManager != null and str(BiomeManager.current_biome) == "haunted_castle" else "graveyard"
	if theme != _theme:
		_theme = theme
		for i in _car_meshes.size():
			_car_meshes[i].mesh = _car_visual(theme, i == 0)
		_tail_mesh.mesh = _tail_visual(theme)
	for i in _car_meshes.size():
		var mi := _car_meshes[i]
		mi.visible = i < cars
		mi.position = Vector3(0.0, 0.0, -float(i) * (Geo.CAR_LEN + Geo.CAR_GAP))
	_tail_mesh.position = Vector3(0.0, 0.0, -length_z)

	_body_shape.size = Vector3(Geo.TRAIN_WIDTH, Geo.TRAIN_ROOF, length_z)
	(_body.get_child(0) as CollisionShape3D).position = Vector3(0.0, Geo.TRAIN_ROOF * 0.5, -length_z * 0.5)
	var hz_bottom: float = 0.1
	_hazard_shape.size = Vector3(Geo.TRAIN_WIDTH - 0.1, Geo.TRAIN_HAZARD_TOP - hz_bottom, length_z)
	(_hazard.get_child(0) as CollisionShape3D).position = Vector3(0.0, (Geo.TRAIN_HAZARD_TOP + hz_bottom) * 0.5, -length_z * 0.5)

	_ramp_mesh.visible = has_ramp
	_ramp_col.disabled = not has_ramp


func on_spawned() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_dodge_counted = false
	_hazard.set_deferred("monitoring", true)
	set_physics_process(true)


func on_recycled() -> void:
	_try_count_dodge()
	set_physics_process(false)
	_hazard.set_deferred("monitoring", false)
	visible = false
	position = Vector3.ZERO
	_dodge_counted = false


func _physics_process(_delta: float) -> void:
	_try_count_dodge()


func _on_hazard_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	if not body.is_in_group("player") and not body.has_method("die"):
		return
	if not GameManager.is_playing():
		return
	if body.has_method("is_ghost_form") and body.call("is_ghost_form"):
		return
	if bool(body.get("is_escaping")):
		return
	if body.global_position.y >= Geo.TRAIN_ROOF - 0.25:
		return
	if body.has_method("die"):
		body.call("die")


func _try_count_dodge() -> void:
	if _dodge_counted or not GameManager or not GameManager.is_playing():
		return
	var player := GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		return
	if player.get("is_alive") != null and not bool(player.get("is_alive")):
		return
	if player.global_position.z >= global_position.z - length_z - 1.0:
		return
	_dodge_counted = true
	if MissionManager:
		MissionManager.report_dodge()


## Lanes this train occupies (fairness helpers / tests).
func occupied_lanes() -> Array[int]:
	return [lane_index]


# --- Visuals -------------------------------------------------------------------

static func _palette(theme: String) -> Array[String]:
	if theme == "castle":
		return ["lacquer_oxblood", "trim_gold"]
	return ["lacquer_black", "trim_silver"]


static func _car_visual(theme: String, front: bool) -> ArrayMesh:
	var key := "train_car_%s_%s" % [theme, "front" if front else "mid"]
	var hit: ArrayMesh = Kit.cached(key)
	if hit:
		return hit
	var pal := _palette(theme)
	var body_mat: String = pal[0]
	var trim: String = pal[1]
	var k := Kit.new()
	var l: float = Geo.CAR_LEN
	var roof: float = Geo.TRAIN_ROOF
	var hw: float = Geo.TRAIN_WIDTH * 0.5
	k.box(Vector3(Geo.TRAIN_WIDTH - 0.1, 1.5, l - 0.1), Vector3(0.0, 1.37, -l * 0.5), body_mat)
	k.box(Vector3(Geo.TRAIN_WIDTH, 0.18, l), Vector3(0.0, roof - 0.09, -l * 0.5), body_mat)
	k.box(Vector3(1.3, 0.02, l - 0.5), Vector3(0.0, roof - 0.005, -l * 0.5), "wood_planks")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.06, 0.1, l), Vector3(sx * (hw - 0.03), roof - 0.08, -l * 0.5), trim)
		k.box(Vector3(0.05, 0.07, l - 0.3), Vector3(sx * (hw - 0.04), 0.66, -l * 0.5), trim)
		## Three glowing windows framed by trim pillars.
		for wz in [-1.6, -4.5, -7.4]:
			k.box(Vector3(0.04, 0.8, 2.0), Vector3(sx * (hw - 0.05), 1.45, wz), "window_violet")
		for pz in [-0.35, -3.05, -5.95, -8.65]:
			k.box(Vector3(0.06, 1.05, 0.12), Vector3(sx * (hw - 0.04), 1.45, pz), trim)
		## Wheels.
		for wz2 in [-1.5, -l + 1.5]:
			k.cyl(0.55, 0.55, 0.12, Vector3(sx * (hw - 0.09), 0.55, wz2), "wood_coffin", Vector3(0.0, 0.0, 90.0), 12)
			k.cyl(0.57, 0.57, 0.05, Vector3(sx * (hw - 0.04), 0.55, wz2), "iron_black", Vector3(0.0, 0.0, 90.0), 12)
			k.cyl(0.12, 0.12, 0.16, Vector3(sx * (hw - 0.06), 0.55, wz2), trim, Vector3(0.0, 0.0, 90.0), 6)
	k.box(Vector3(1.8, 0.22, l - 0.8), Vector3(0.0, 0.52, -l * 0.5), "iron_black")
	if front:
		## Lanterns, silver cross and black plumes on the leading carriage.
		k.box(Vector3(0.14, 0.95, 0.04), Vector3(0.0, 1.42, 0.01), trim)
		k.box(Vector3(0.62, 0.14, 0.04), Vector3(0.0, 1.62, 0.01), trim)
		k.box(Vector3(Geo.TRAIN_WIDTH - 0.3, 0.06, 0.04), Vector3(0.0, 0.8, 0.01), trim)
		for sx2 in [-1.0, 1.0]:
			k.box(Vector3(0.22, 0.34, 0.22), Vector3(sx2 * 0.78, 1.95, 0.1), "iron_black")
			k.box(Vector3(0.15, 0.24, 0.24), Vector3(sx2 * 0.78, 1.95, 0.1), "lantern_flame")
			k.cyl(0.0, 0.11, 0.6, Vector3(sx2 * 0.9, roof + 0.3, -0.3), "lacquer_black", Vector3.ZERO, 6)
	else:
		## Bellows coupler filling the gap to the carriage ahead; roof plate is walkable.
		k.box(Vector3(1.7, 1.4, Geo.CAR_GAP + 0.1), Vector3(0.0, 1.4, Geo.CAR_GAP * 0.5), "lacquer_black")
		k.box(Vector3(1.5, 0.08, Geo.CAR_GAP + 0.1), Vector3(0.0, roof - 0.04, Geo.CAR_GAP * 0.5), "iron_black")
		k.box(Vector3(1.9, 0.18, Geo.CAR_GAP + 0.1), Vector3(0.0, roof - 0.2, Geo.CAR_GAP * 0.5), body_mat)
	return Kit.store(key, k.commit())


static func _tail_visual(theme: String) -> ArrayMesh:
	var key := "train_tail_%s" % theme
	var hit: ArrayMesh = Kit.cached(key)
	if hit:
		return hit
	var trim: String = _palette(theme)[1]
	var k := Kit.new()
	k.box(Vector3(1.0, 1.35, 0.05), Vector3(0.0, 1.35, 0.02), "iron_black")
	k.box(Vector3(0.06, 0.06, 0.06), Vector3(0.36, 1.35, -0.02), trim)
	for sx in [-1.0, 1.0]:
		k.cyl(0.0, 0.1, 0.55, Vector3(sx * 0.9, Geo.TRAIN_ROOF + 0.27, 0.35), "lacquer_black", Vector3.ZERO, 6)
	return Kit.store(key, k.commit())


static func _ramp_visual() -> ArrayMesh:
	var hit: ArrayMesh = Kit.cached("train_ramp")
	if hit:
		return hit
	var k := Kit.new()
	k.wedge(1.95, Geo.TRAIN_ROOF, Geo.RAMP_LEN, Vector3.ZERO, "wood_planks")
	var slope_deg: float = rad_to_deg(atan2(Geo.TRAIN_ROOF, Geo.RAMP_LEN))
	var slope_len: float = sqrt(Geo.TRAIN_ROOF * Geo.TRAIN_ROOF + Geo.RAMP_LEN * Geo.RAMP_LEN)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.08, 0.12, slope_len), Vector3(sx * 1.0, Geo.TRAIN_ROOF * 0.5 + 0.04, Geo.RAMP_LEN * 0.5),
			"iron_black", Vector3(slope_deg, 0.0, 0.0))
	for i in 5:
		var z: float = Geo.RAMP_LEN * (float(i) + 0.5) / 5.0
		var y: float = Geo.TRAIN_ROOF * (1.0 - z / Geo.RAMP_LEN)
		k.box(Vector3(1.9, 0.03, 0.08), Vector3(0.0, y + 0.01, z), "iron_black", Vector3(slope_deg, 0.0, 0.0))
	return Kit.store("train_ramp", k.commit())
