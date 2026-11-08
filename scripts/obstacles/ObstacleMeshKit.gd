extends RefCounted
## Merges primitive pieces into one ArrayMesh with one surface per material, so each
## obstacle renders in a handful of draw calls. Built meshes are cached by key and shared
## by every pooled instance.

const MAT_DIR := "res://resources/materials/obstacles/"

static var _cache: Dictionary = {}

var _tools: Dictionary = {}
var _mats: Dictionary = {}


static func mat(mat_name: String) -> Material:
	return load(MAT_DIR + mat_name + ".tres") as Material


static func cached(key: String) -> ArrayMesh:
	return _cache.get(key) as ArrayMesh


static func store(key: String, mesh: ArrayMesh) -> ArrayMesh:
	_cache[key] = mesh
	return mesh


func _tool(mat_name: String) -> SurfaceTool:
	if not _tools.has(mat_name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat_name] = st
		_mats[mat_name] = mat(mat_name)
	return _tools[mat_name] as SurfaceTool


func add(mesh: PrimitiveMesh, mat_name: String, xform: Transform3D) -> void:
	_tool(mat_name).append_from(mesh, 0, xform)


func box(size: Vector3, pos: Vector3, mat_name: String, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = size
	add(m, mat_name, _xf(pos, rot_deg))


func cyl(radius_top: float, radius_bottom: float, height: float, pos: Vector3, mat_name: String,
		rot_deg: Vector3 = Vector3.ZERO, segments: int = 10, scale: Vector3 = Vector3.ONE) -> void:
	var m := CylinderMesh.new()
	m.top_radius = radius_top
	m.bottom_radius = radius_bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	add(m, mat_name, _xf(pos, rot_deg, scale))


func sphere(radius: float, pos: Vector3, mat_name: String, scale: Vector3 = Vector3.ONE) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	add(m, mat_name, _xf(pos, Vector3.ZERO, scale))


## Right-triangle wedge (ramp): rises from z=+length (ground) to z=0 (height), width along X.
func wedge(width: float, height: float, length: float, pos: Vector3, mat_name: String) -> void:
	var m := PrismMesh.new()
	m.left_to_right = 1.0
	m.size = Vector3(length, height, width)
	add(m, mat_name, _xf(pos + Vector3(0.0, height * 0.5, length * 0.5), Vector3(0.0, 90.0, 0.0)))


## Flat hexagon "coffin" plate facing +Z, pointy top and bottom.
func coffin_plate(width: float, height: float, depth: float, pos: Vector3, mat_name: String) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.5
	m.bottom_radius = 0.5
	m.height = depth
	m.radial_segments = 6
	m.rings = 1
	## Cylinder axis Y -> Z; a hexagon vertex then points along +Y.
	var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0)) * Basis(Vector3.UP, deg_to_rad(30.0))
	basis = Basis.from_scale(Vector3(width / 0.866, height, 1.0)) * basis
	add(m, mat_name, Transform3D(basis, pos))


func commit() -> ArrayMesh:
	var out := ArrayMesh.new()
	for mat_name in _tools.keys():
		var st := _tools[mat_name] as SurfaceTool
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _mats[mat_name] as Material)
	return out


static func _xf(pos: Vector3, rot_deg: Vector3, scale: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	b = b * Basis.from_scale(scale)
	return Transform3D(b, pos)
