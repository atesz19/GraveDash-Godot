extends Node3D
## Distant fog-fading silhouettes (hills / trees / graves) — stays off the 3-lane playfield.

@export var player_path: NodePath = ^"../Player"
@export var follow_ahead: float = 20.0

@onready var left_bank: Node3D = $LeftBank
@onready var right_bank: Node3D = $RightBank

var _player: Node3D
var _active: bool = true
var _built: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_build_if_needed()
	_set_active(BiomeManager.current_biome == "graveyard")
	if not BiomeManager.biome_changed.is_connected(_on_biome_changed):
		BiomeManager.biome_changed.connect(_on_biome_changed)
	if not BiomeManager.biome_applied.is_connected(_on_biome_applied):
		BiomeManager.biome_applied.connect(_on_biome_applied)


func _on_biome_changed(biome_id: String) -> void:
	_set_active(biome_id == "graveyard")


func _on_biome_applied(biome_id: String) -> void:
	_set_active(biome_id == "graveyard")


func _set_active(active: bool) -> void:
	_active = active
	visible = active


func _process(_delta: float) -> void:
	if not _active:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return
	## Slide with the runner; banks stay far on X so lanes stay clear.
	global_position = Vector3(0.0, 0.0, _player.global_position.z - follow_ahead)


func _build_if_needed() -> void:
	if _built:
		return
	_built = true
	var sil_mat: StandardMaterial3D = _make_silhouette_mat(Color(0.04, 0.045, 0.07, 1))
	var hill_mat: StandardMaterial3D = _make_silhouette_mat(Color(0.05, 0.055, 0.08, 1))
	_populate_bank(left_bank, -1.0, sil_mat, hill_mat)
	_populate_bank(right_bank, 1.0, sil_mat, hill_mat)
	_add_church(right_bank, hill_mat, sil_mat)
	_add_moon()
	_disable_shadows(self)


func _disable_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_shadows(c)


func _add_church(bank: Node3D, body_mat: Material, roof_mat: Material) -> void:
	if bank == null:
		return
	var root := Node3D.new()
	root.position = Vector3(34.0, 0.0, -62.0)
	root.rotation_degrees.y = -18.0
	bank.add_child(root)
	var nave := MeshInstance3D.new()
	var nave_mesh := BoxMesh.new()
	nave_mesh.size = Vector3(7.0, 6.0, 14.0)
	nave.mesh = nave_mesh
	nave.material_override = body_mat
	nave.position.y = 3.0
	root.add_child(nave)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(7.6, 3.2, 14.4)
	roof.mesh = roof_mesh
	roof.material_override = roof_mat
	roof.position.y = 7.6
	root.add_child(roof)
	var tower := MeshInstance3D.new()
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3(3.2, 12.0, 3.2)
	tower.mesh = tower_mesh
	tower.material_override = body_mat
	tower.position = Vector3(0.0, 6.0, 8.0)
	root.add_child(tower)
	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.0
	spire_mesh.bottom_radius = 2.2
	spire_mesh.height = 7.0
	spire_mesh.radial_segments = 4
	spire.mesh = spire_mesh
	spire.material_override = roof_mat
	spire.position = Vector3(0.0, 15.5, 8.0)
	spire.rotation_degrees.y = 45.0
	root.add_child(spire)
	## Faint lit window so the silhouette reads through fog.
	var win := MeshInstance3D.new()
	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(0.2, 1.6, 0.8)
	win.mesh = win_mesh
	var win_mat := StandardMaterial3D.new()
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_mat.albedo_color = Color(1.0, 0.62, 0.25)
	win.material_override = win_mat
	win.position = Vector3(-3.55, 3.2, -2.0)
	root.add_child(win)


func _add_moon() -> void:
	## Sky-locked moon: rides with the backdrop, ignores fog so it stays crisp.
	var moon := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 5.5
	disc.height = 11.0
	disc.radial_segments = 24
	disc.rings = 12
	moon.mesh = disc
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color(1.6, 1.55, 1.38)
	moon_mat.disable_fog = true
	moon.material_override = moon_mat
	moon.position = Vector3(-26.0, 27.0, -165.0)
	add_child(moon)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(52.0, 52.0)
	halo.mesh = quad
	var halo_mat := (load("res://resources/fx/halo_cold.tres") as StandardMaterial3D).duplicate() as StandardMaterial3D
	halo_mat.disable_fog = true
	halo_mat.albedo_color = Color(0.55, 0.62, 1.0, 0.55)
	halo.material_override = halo_mat
	halo.position = moon.position + Vector3(0.0, 0.0, 8.0)
	add_child(halo)


func _make_silhouette_mat(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _populate_bank(bank: Node3D, side: float, sil_mat: Material, hill_mat: Material) -> void:
	if bank == null:
		return
	## Rolling hill masses far off the track.
	for i in 5:
		var hill: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 9.0 + float(i % 3) * 2.5
		mesh.height = 7.0 + float(i % 2) * 3.0
		mesh.radial_segments = 10
		mesh.rings = 6
		hill.mesh = mesh
		hill.material_override = hill_mat
		hill.position = Vector3(
			side * (28.0 + float(i) * 4.5),
			-1.5,
			-40.0 + float(i) * 22.0
		)
		hill.scale = Vector3(1.6 + float(i % 3) * 0.25, 0.55 + float(i % 2) * 0.15, 1.8)
		bank.add_child(hill)
	## Dead-tree spikes.
	for i in 14:
		var tree: MeshInstance3D = MeshInstance3D.new()
		var trunk: CylinderMesh = CylinderMesh.new()
		trunk.top_radius = 0.12
		trunk.bottom_radius = 0.28
		trunk.height = 5.5 + float(i % 5) * 1.1
		trunk.radial_segments = 5
		tree.mesh = trunk
		tree.material_override = sil_mat
		var z: float = -55.0 + float(i) * 9.5 + float(i % 3) * 1.7
		var x: float = side * (18.0 + float(i % 4) * 3.2 + 2.0)
		tree.position = Vector3(x, trunk.height * 0.5 - 0.2, z)
		tree.rotation_degrees = Vector3(0.0, float(i * 37 % 180), side * (4.0 + float(i % 3)))
		bank.add_child(tree)
	## Mid-band PBR gravestones (01–04 mix) — far enough to clear the 3 lanes.
	var grave_scenes: Array[String] = [
		"res://scenes/levels/props/DecorGravestone_01.tscn",
		"res://scenes/levels/props/DecorGravestone_02.tscn",
		"res://scenes/levels/props/DecorGravestone_03.tscn",
		"res://scenes/levels/props/DecorGravestone_04.tscn",
	]
	for i in 10:
		var path: String = grave_scenes[i % grave_scenes.size()]
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var stone: Node3D = packed.instantiate() as Node3D
		if stone == null:
			continue
		bank.add_child(stone)
		stone.position = Vector3(
			side * (14.5 + float(i % 3) * 1.6),
			0.0,
			-48.0 + float(i) * 11.0
		)
		stone.rotation_degrees.y = float((i * 23) % 40) - 20.0
		stone.scale = Vector3.ONE * (0.85 + float(i % 3) * 0.08)
	## Mid-ground fence posts — closer than hills, still off the 3 lanes.
	for i in 12:
		var post: MeshInstance3D = MeshInstance3D.new()
		var post_mesh: BoxMesh = BoxMesh.new()
		post_mesh.size = Vector3(0.14, 1.15 + float(i % 2) * 0.2, 0.14)
		post.mesh = post_mesh
		post.material_override = sil_mat
		var pz: float = -50.0 + float(i) * 9.0
		var px: float = side * (11.5 + float(i % 3) * 0.6)
		post.position = Vector3(px, post_mesh.size.y * 0.5, pz)
		bank.add_child(post)
		if i % 2 == 0:
			var rail: MeshInstance3D = MeshInstance3D.new()
			var rail_mesh: BoxMesh = BoxMesh.new()
			rail_mesh.size = Vector3(0.1, 0.1, 2.4)
			rail.mesh = rail_mesh
			rail.material_override = sil_mat
			rail.position = Vector3(px, 0.75, pz + side * 1.1)
			bank.add_child(rail)
	## Fallen crosses in the mid band.
	for i in 8:
		var cross_post: MeshInstance3D = MeshInstance3D.new()
		var cp: BoxMesh = BoxMesh.new()
		cp.size = Vector3(0.12, 1.4, 0.1)
		cross_post.mesh = cp
		cross_post.material_override = sil_mat
		var cx: float = side * (13.0 + float(i % 4) * 1.4)
		var cz: float = -45.0 + float(i) * 12.5
		cross_post.position = Vector3(cx, 0.55, cz)
		cross_post.rotation_degrees = Vector3(0.0, float(i * 17 % 50) - 25.0, side * 18.0)
		bank.add_child(cross_post)
		var cross_beam: MeshInstance3D = MeshInstance3D.new()
		var cb: BoxMesh = BoxMesh.new()
		cb.size = Vector3(0.85, 0.12, 0.1)
		cross_beam.mesh = cb
		cross_beam.material_override = sil_mat
		cross_beam.position = Vector3(cx, 0.95, cz)
		cross_beam.rotation_degrees = cross_post.rotation_degrees
		bank.add_child(cross_beam)
	## Distant chapel / ruin blocks.
	for i in 2:
		var ruin: MeshInstance3D = MeshInstance3D.new()
		var block: BoxMesh = BoxMesh.new()
		block.size = Vector3(3.2 + float(i), 2.4 + float(i) * 0.6, 2.2)
		ruin.mesh = block
		ruin.material_override = hill_mat
		ruin.position = Vector3(
			side * (24.0 + float(i) * 5.0),
			block.size.y * 0.45,
			-30.0 + float(i) * 38.0
		)
		ruin.rotation_degrees.y = side * (12.0 + float(i) * 8.0)
		bank.add_child(ruin)
		var spire: MeshInstance3D = MeshInstance3D.new()
		var spire_mesh: BoxMesh = BoxMesh.new()
		spire_mesh.size = Vector3(0.55, 2.6, 0.55)
		spire.mesh = spire_mesh
		spire.material_override = sil_mat
		spire.position = ruin.position + Vector3(side * 0.8, 1.8, 0.0)
		bank.add_child(spire)
