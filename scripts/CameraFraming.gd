class_name CameraFraming
extends Node
## Aspect-aware framing for the parent Camera3D. Scenes are composed for 16:9 with a vertical FOV:
## - narrower than 16:9 (portrait, 4:3, 16:10 windows) keeps the 16:9 horizontal view,
##   so the hero / lanes never slide off the side edge;
## - wider than 16:9 keeps the vertical FOV (keep_height, more world at the sides) until the
##   horizontal view would pass MAX_HFOV_DEG; beyond that (32:9 with the 70° gameplay camera)
##   the horizontal view is capped instead of stretching into fish-eye distortion.

const MIN_ASPECT: float = 16.0 / 9.0
const MAX_HFOV_DEG: float = 120.0

var base_vfov: float = 70.0
var _camera: Camera3D


static func attach(camera: Camera3D) -> CameraFraming:
	var framing := CameraFraming.new()
	framing.name = "CameraFraming"
	framing.base_vfov = camera.fov
	camera.add_child(framing)
	return framing


func _ready() -> void:
	_camera = get_parent() as Camera3D
	get_viewport().size_changed.connect(apply)
	apply()


func apply() -> void:
	if _camera == null:
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	var half_v: float = tan(deg_to_rad(base_vfov) * 0.5)
	if aspect < MIN_ASPECT:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = rad_to_deg(2.0 * atan(half_v * MIN_ASPECT))
	elif rad_to_deg(2.0 * atan(half_v * aspect)) > MAX_HFOV_DEG:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = MAX_HFOV_DEG
	else:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		_camera.fov = base_vfov
