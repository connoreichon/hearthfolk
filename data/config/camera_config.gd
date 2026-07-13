class_name CameraConfig
extends Resource
## Parámetros de la cámara (§6).

static var _instance: CameraConfig

@export var zoom_min: float = 12.0
@export var zoom_max: float = 80.0
@export var zoom_step: float = 0.12
@export var tilt_near_deg: float = 48.0
@export var tilt_far_deg: float = 55.0
@export var pan_speed: float = 22.0
@export var rotate_speed_deg: float = 110.0
@export var smoothing: float = 9.0
@export var map_half_size: float = 60.0
@export var map_margin: float = 10.0
@export var focus_tween_seconds: float = 0.4


static func get_default() -> CameraConfig:
	if _instance == null:
		_instance = load("res://data/config/camera_config.tres") as CameraConfig
	return _instance
