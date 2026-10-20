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


func _make_silhouette_mat(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	## Let fog dissolve distant silhouettes.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mat.distance_fade_min_distance = 55.0
	mat.distance_fade_max_distance = 110.0
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
		## Sparse canopy blob.
		if i % 2 == 0:
			var canopy: MeshInstance3D = MeshInstance3D.new()
			var blob: SphereMesh = SphereMesh.new()
			blob.radius = 1.4 + float(i % 3) * 0.35
			blob.height = blob.radius * 1.6
			blob.radial_segments = 8
			blob.rings = 4
			canopy.mesh = blob
			canopy.material_override = sil_mat
			canopy.position = Vector3(x + side * 0.4, trunk.height + 0.4, z)
			canopy.scale = Vector3(1.0, 0.55, 1.2)
			bank.add_child(canopy)
	## Grave markers as thin dark slabs.
	for i in 10:
		var grave: MeshInstance3D = MeshInstance3D.new()
		var slab: BoxMesh = BoxMesh.new()
		slab.size = Vector3(0.55, 1.1 + float(i % 3) * 0.25, 0.18)
		grave.mesh = slab
		grave.material_override = sil_mat
		grave.position = Vector3(
			side * (16.5 + float(i % 3) * 1.8),
			slab.size.y * 0.5,
			-48.0 + float(i) * 11.0
		)
		grave.rotation_degrees.y = float((i * 23) % 40) - 20.0
		bank.add_child(grave)
