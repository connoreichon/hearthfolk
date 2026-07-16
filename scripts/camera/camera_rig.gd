class_name CameraRig
extends Node3D
## Cámara de maqueta (§6): pivot → SpringArm3D → Camera3D.
## Usa delta real (sigue viva en pausa). Zoom exponencial 12–80 m.

## Altura mínima de la cámara sobre el terreno que tenga debajo.
const CAMERA_CLEARANCE: float = 3.0
## Zoom máximo en vista de águila (siembra): se ve el mapa entero.
const OVERVIEW_ZOOM_MAX: float = 720.0

## Vista de águila (siembra de bandas): zoom ampliado y picado más vertical.
var overview: bool = false

var _cfg: CameraConfig
var _target_zoom: float = 40.0
var _panning: bool = false  # arrastre con botón central
var _pan_left: bool = false  # arrastre con botón IZQUIERDO (modo Selección)
var _rotating: bool = false  # arrastre con botón DERECHO = rotar
var _tilt_offset: float = 0.0  # picado manual añadido (rueda + arrastre der.)
var _focus_tween: Tween
## Micro-shake (M1): amplitud actual, decae exponencialmente en ~0.25 s.
var _shake: float = 0.0
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var arm: SpringArm3D = $Arm
@onready var camera: Camera3D = $Arm/Camera


func _ready() -> void:
	add_to_group(&"camera_rig")
	_cfg = CameraConfig.get_default()
	# Game feel (M1): golpes del mundo que se SIENTEN en la cámara
	EventBus.tree_felled.connect(_on_tree_felled)
	EventBus.construction_completed.connect(_on_building_done)
	arm.spring_length = _target_zoom
	# Sin colisión: si una colina se cruza entre pivot y cámara, el brazo se
	# encogía y estampaba la cámara contra la ladera (pantalla marrón). La
	# altura segura la garantiza CAMERA_CLEARANCE en _process.
	arm.collision_mask = 0
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
	# Límites del mapa, más estrictos cuanto más lejos está la cámara: con
	# zoom alto la cámara cuelga decenas de metros por detrás del pivot y
	# sin este término acababas mirando el vacío de detrás del borde.
	var map_half: float = (
		GameState.world_gen.map_half if GameState.world_gen != null else _cfg.map_half_size
	)
	var limit: float = maxf(12.0, map_half - _cfg.map_margin - arm.spring_length * 0.35)
	position.x = clampf(position.x, -limit, limit)
	position.z = clampf(position.z, -limit, limit)
	# Altura del pivot pegada al terreno — pero si el suelo bajo la CÁMARA
	# queda a menos de CAMERA_CLEARANCE, el pivot sube lo que falte (nunca
	# meter la cámara dentro de una colina).
	if GameState.terrain != null:
		var target_y: float = GameState.terrain.get_height(position.x, position.z)
		var cam_pos: Vector3 = camera.global_position
		var cam_ground: float = GameState.terrain.get_height(cam_pos.x, cam_pos.z)
		var deficit: float = cam_ground + CAMERA_CLEARANCE - cam_pos.y
		if deficit > 0.0:
			target_y = maxf(target_y, position.y + deficit)
		position.y = lerpf(position.y, target_y, k)
	# Zoom exponencial suavizado + inclinación 48°→55° (68° en vista águila)
	arm.spring_length = lerpf(arm.spring_length, _target_zoom, k)
	var far_zoom: float = OVERVIEW_ZOOM_MAX if overview else _cfg.zoom_max
	var far_tilt: float = 68.0 if overview else _cfg.tilt_far_deg
	var zoom_f: float = clampf(inverse_lerp(_cfg.zoom_min, far_zoom, arm.spring_length), 0.0, 1.0)
	var base_tilt: float = lerpf(_cfg.tilt_near_deg, far_tilt, zoom_f)
	arm.rotation_degrees.x = -clampf(base_tilt + _tilt_offset, 20.0, 89.0)
	# Micro-shake (M1): tiembla la CÁMARA (no el pivot) y decae en ~0.25 s
	if _shake > 0.001:
		camera.position = Vector3(
			_shake_rng.randf_range(-_shake, _shake), _shake_rng.randf_range(-_shake, _shake), 0.0
		)
		_shake *= exp(-14.0 * delta)
	elif camera.position != Vector3.ZERO:
		camera.position = Vector3.ZERO


## Sacudida con tope (≤0.15 m por orden de la 004) atenuada por distancia.
func shake_from(world_point: Vector3, base: float) -> void:
	var distance: float = global_position.distance_to(world_point)
	var falloff: float = clampf(1.0 - distance / 90.0, 0.0, 1.0)
	_shake = minf(_shake + base * falloff, 0.15)


func _on_tree_felled(_tree_id: int, position_felled: Vector3, _wood: int) -> void:
	shake_from(position_felled, 0.11)


func _on_building_done(building_id: int) -> void:
	var node: Node = EntityRegistry.get_node_by_id(building_id)
	if node is Node3D:
		shake_from((node as Node3D).global_position, 0.08)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		var wheel_max: float = OVERVIEW_ZOOM_MAX if overview else _cfg.zoom_max
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_target_zoom = clampf(_target_zoom * (1.0 - _cfg.zoom_step), _cfg.zoom_min, wheel_max)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_target_zoom = clampf(_target_zoom * (1.0 + _cfg.zoom_step), _cfg.zoom_min, wheel_max)
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse_button.pressed
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			# Botón derecho arrastrando = ROTAR la cámara (orden del dueño).
			_rotating = mouse_button.pressed
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and mouse_button.double_click:
				_focus_on_clicked_terrain(mouse_button.position)
			else:
				# Arrastre con IZQUIERDO = mover el mapa (solo en Selección: en
				# una herramienta el izquierdo talla/marca). El clic para
				# seleccionar lo maneja ToolManager; arrastrar solo panea.
				_pan_left = mouse_button.pressed and not _tool_active()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _panning or _pan_left:
			_kill_focus_tween()
			var flat: Basis = Basis(Vector3.UP, rotation.y)
			var factor: float = arm.spring_length * 0.0016
			position += flat * Vector3(-motion.relative.x, 0.0, -motion.relative.y) * factor
		elif _rotating:
			_kill_focus_tween()
			rotation.y -= motion.relative.x * 0.006
			_tilt_offset = clampf(_tilt_offset + motion.relative.y * 0.14, -18.0, 32.0)
	if event.is_action_pressed(&"camera_focus"):
		focus_settlement()
	if event.is_action_pressed(&"camera_overview"):
		# Vista de águila a voluntad (M): gestionar el valle desde el cielo
		set_overview(not overview)


## ¿Hay una herramienta activa (tala/zona/huerto/demoler)? Entonces el
## arrastre izquierdo es para ella, no para panear.
func _tool_active() -> bool:
	var tools: Node = get_tree().get_first_node_in_group(&"tool_manager")
	return tools != null and StringName(tools.get(&"current_tool")) != &"none"


func set_zoom(zoom: float) -> void:
	var zoom_max: float = OVERVIEW_ZOOM_MAX if overview else _cfg.zoom_max
	_target_zoom = clampf(zoom, _cfg.zoom_min, zoom_max)


## Vista de águila on/off (la siembra ve el mapa entero; al volver, zoom de juego).
func set_overview(enabled: bool) -> void:
	overview = enabled
	set_zoom(520.0 if enabled else 40.0)


func get_state() -> Dictionary:
	return {
		"pos": [position.x, position.y, position.z],
		"yaw": rotation.y,
		"zoom": _target_zoom,
	}


func set_state(d: Dictionary) -> void:
	var pos: Array = d.get("pos", [0.0, 0.0, 6.0])
	position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(d.get("yaw", 0.0))
	set_zoom(float(d.get("zoom", 40.0)))
	arm.spring_length = _target_zoom


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
