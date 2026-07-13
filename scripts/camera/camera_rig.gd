class_name CameraRig
extends Node3D
## Cámara de maqueta (§6): pivot → SpringArm3D → Camera3D.
## Usa delta real (sigue viva en pausa). Zoom exponencial 12–80 m.

var _cfg: CameraConfig
var _target_zoom: float = 40.0
var _panning: bool = false
var _focus_tween: Tween

@onready var arm: SpringArm3D = $Arm
@onready var camera: Camera3D = $Arm/Camera


func _ready() -> void:
	_cfg = CameraConfig.get_default()
	arm.spring_length = _target_zoom
	arm.collision_mask = 1
	arm.margin = 0.5
	arm.rotation_degrees.x = -_cfg.tilt_near_deg
	camera.current = true
	position = Vector3(0.0, 0.0, 6.0)


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-_cfg.smoothing * delta)
	# Desplazamiento WASD relativo a la rotación actual
	var input_2d: Vector2 = Input.get_vector(
		&"camera_left", &"camera_right", &"camera_forward", &"camera_back"
	)
	if input_2d.length_squared() > 0.0:
		_kill_focus_tween()
		var flat: Basis = Basis(Vector3.UP, rotation.y)
		var move: Vector3 = flat * Vector3(input_2d.x, 0.0, input_2d.y)
		var zoom_scale: float = 0.4 + arm.spring_length / 40.0
		position += move * _cfg.pan_speed * zoom_scale * delta
	# Rotación Q/E
	var rot_dir: float = Input.get_axis(&"camera_rotate_left", &"camera_rotate_right")
	rotation.y -= deg_to_rad(_cfg.rotate_speed_deg) * rot_dir * delta
	# Límites del mapa
	var limit: float = _cfg.map_half_size - _cfg.map_margin
	position.x = clampf(position.x, -limit, limit)
	position.z = clampf(position.z, -limit, limit)
	# Altura del pivot pegada al terreno
	if GameState.terrain != null:
		position.y = lerpf(position.y, GameState.terrain.get_height(position.x, position.z), k)
	# Zoom exponencial suavizado + inclinación 48°→55°
	arm.spring_length = lerpf(arm.spring_length, _target_zoom, k)
	var zoom_f: float = clampf(
		inverse_lerp(_cfg.zoom_min, _cfg.zoom_max, arm.spring_length), 0.0, 1.0
	)
	arm.rotation_degrees.x = -lerpf(_cfg.tilt_near_deg, _cfg.tilt_far_deg, zoom_f)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_target_zoom = clampf(
				_target_zoom * (1.0 - _cfg.zoom_step), _cfg.zoom_min, _cfg.zoom_max
			)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_target_zoom = clampf(
				_target_zoom * (1.0 + _cfg.zoom_step), _cfg.zoom_min, _cfg.zoom_max
			)
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse_button.pressed
		elif (
			mouse_button.button_index == MOUSE_BUTTON_LEFT
			and mouse_button.pressed
			and mouse_button.double_click
		):
			_focus_on_clicked_terrain(mouse_button.position)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _panning:
		_kill_focus_tween()
		var flat: Basis = Basis(Vector3.UP, rotation.y)
		var factor: float = arm.spring_length * 0.0016
		position += flat * Vector3(-motion.relative.x, 0.0, -motion.relative.y) * factor
	if event.is_action_pressed(&"camera_focus"):
		focus_settlement()


func set_zoom(zoom: float) -> void:
	_target_zoom = clampf(zoom, _cfg.zoom_min, _cfg.zoom_max)


## Centra suavemente el pivot en un punto (tween 0.4 s, ease out).
func focus_on(point: Vector3) -> void:
	_kill_focus_tween()
	_focus_tween = create_tween()
	_focus_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var target: Vector3 = Vector3(point.x, position.y, point.z)
	_focus_tween.tween_property(self, "position", target, _cfg.focus_tween_seconds)


## F: centroide de habitantes + fogata.
func focus_settlement() -> void:
	var points: Array[Vector3] = []
	for citizen: Node in get_tree().get_nodes_in_group(&"citizens"):
		if citizen is Node3D:
			points.append((citizen as Node3D).global_position)
	for fire: Node in get_tree().get_nodes_in_group(&"campfire"):
		if fire is Node3D:
			points.append((fire as Node3D).global_position)
	if points.is_empty():
		focus_on(Vector3.ZERO)
		return
	var sum: Vector3 = Vector3.ZERO
	for p: Vector3 in points:
		sum += p
	focus_on(sum / float(points.size()))


func _focus_on_clicked_terrain(screen_pos: Vector2) -> void:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 500.0, 1
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		focus_on(hit["position"])


func _kill_focus_tween() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
