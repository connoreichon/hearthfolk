class_name BandPlacer
extends Node
## Siembra de bandas (S0, Build 003): al empezar partida desde el menú, el
## jugador reparte a sus colonos en grupos por el mapa. Validación mínima —
## tierra dentro del mapa, sin agua, pendiente razonable, lejos de otros
## campamentos — y CERO chequeos de acceso: cada banda se las apaña donde
## su gente decida plantar la hoguera.

const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")
const MIN_CAMP_DISTANCE: float = 12.0
const MAX_SLOPE_DEG: float = 22.0

var remaining: int = 10
var group_size: int = 4

var _band_counter: int = 0
var _world: WorldRoot
var _tools: ToolManager
var _hud: CanvasLayer
var _camera: Camera3D
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _label: Label
var _valid: bool = false
var _point: Vector3 = Vector3.INF


func setup(world: WorldRoot, tools: ToolManager, hud: CanvasLayer) -> void:
	_world = world
	_tools = tools
	_hud = hud


func _ready() -> void:
	remaining = maxi(1, GameState.pending_settlers)
	group_size = clampi(4, 1, remaining)
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty():
		var rig: CameraRig = rigs[0] as CameraRig
		_camera = rig.camera
		# Arrancar la vista sobre tierra firme (el origen puede ser lago)
		var start: Vector3 = _find_valid_near(Vector3.ZERO, 10.0, 20)
		if start != Vector3.INF:
			rig.position = Vector3(start.x, rig.position.y, start.z)
	# Mientras se siembra, las herramientas y el HUD esperan su turno.
	if _tools != null:
		_tools.set_process_input(false)
		_tools.set_process_unhandled_input(false)
	if _hud != null:
		_hud.visible = false
	_build_ghost()
	_build_ui()
	_refresh_label()


func _build_ghost() -> void:
	var palette: PaletteData = PaletteData.get_default()
	_ghost = MeshInstance3D.new()
	_ghost.name = "BandGhost"
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(palette.grass_light, 0.4)
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	add_child(_ghost)


func _build_ui() -> void:
	var palette: PaletteData = PaletteData.get_default()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette.ui_panel, 0.92)
	style.border_color = palette.accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = 40.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", palette.ui_text)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_label)


func _refresh_label() -> void:
	_label.text = (
		"Reparte a tu gente: quedan %d · grupo de %d (rueda ±) · Mayús+clic: todos juntos"
		% [remaining, group_size]
	)


func _process(_delta: float) -> void:
	if _camera == null:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = _camera.project_ray_origin(mouse)
	var direction: Vector3 = _camera.project_ray_normal(mouse)
	# Intersección ANALÍTICA con WorldGen: durante la siembra el suelo
	# físico aún no existe (los chunks nacen con los campamentos).
	var hit: Vector3 = _terrain_ray_point(origin, direction)
	if hit == Vector3.INF:
		_ghost.visible = false
		_point = Vector3.INF
		_valid = false
		return
	_point = hit
	_valid = _is_valid(_point)
	var palette: PaletteData = PaletteData.get_default()
	var disc: CylinderMesh = CylinderMesh.new()
	var radius: float = 1.2 + 0.35 * float(group_size)
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.06
	disc.radial_segments = 24
	_ghost.mesh = disc
	_ghost.position = _point + Vector3(0.0, 0.15, 0.0)
	_ghost_mat.albedo_color = (
		Color(palette.grass_light, 0.4) if _valid else Color(palette.roof, 0.45)
	)
	_ghost.visible = true


## Marcha del rayo de cámara contra la altura de WorldGen (paso 4 m +
## bisección): el punto del terreno bajo el cursor sin necesidad de física.
func _terrain_ray_point(origin: Vector3, direction: Vector3) -> Vector3:
	var world_gen: WorldGen = GameState.world_gen
	var prev_t: float = 0.0
	var t: float = 0.0
	for _i: int in 240:
		t += 4.0
		var p: Vector3 = origin + direction * t
		if p.y <= world_gen.height(p.x, p.z):
			var lo: float = prev_t
			var hi: float = t
			for _j: int in 14:
				var mid: float = (lo + hi) * 0.5
				var m: Vector3 = origin + direction * mid
				if m.y <= world_gen.height(m.x, m.z):
					hi = mid
				else:
					lo = mid
			var point: Vector3 = origin + direction * hi
			point.y = world_gen.height(point.x, point.z)
			return point
		prev_t = t
	return Vector3.INF


func _is_valid(point: Vector3) -> bool:
	var terrain: TerrainData = GameState.terrain
	if terrain == null or not terrain.is_inside(point.x, point.z, 3.0):
		return false
	if GameState.world_gen.river_mask(point.x, point.z) > 0.2:
		return false
	if terrain.get_slope_deg(point.x, point.z) > MAX_SLOPE_DEG:
		return false
	for node: Node in get_tree().get_nodes_in_group(&"camps"):
		var d: float = (node as Node3D).global_position.distance_to(point)
		if d < MIN_CAMP_DISTANCE:
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed:
		return
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		group_size = clampi(group_size + 1, 1, remaining)
		_refresh_label()
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		group_size = clampi(group_size - 1, 1, remaining)
		_refresh_label()
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_LEFT and _valid:
		var count: int = remaining if mouse_button.shift_pressed else group_size
		drop_band(_point, count)
		get_viewport().set_input_as_handled()


## Suelta una banda de `count` colonos alrededor de un punto válido.
func drop_band(point: Vector3, count: int) -> void:
	_band_counter += 1
	var camp: CampEntity = _world.found_camp(point, _band_counter)
	EventBus.band_placed.emit(_band_counter, camp.global_position)
	var terrain: TerrainData = GameState.terrain
	for i: int in count:
		var citizen: Citizen = CITIZEN_SCENE.instantiate()
		citizen.data = SettlerGen.generate(GameState.rng)
		citizen.band_id = _band_counter
		_world.add_child(citizen)
		var ang: float = TAU * float(i) / float(count) + 0.6
		var radius: float = 2.6 + 0.5 * float(i % 2)
		var pos: Vector3 = point + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		pos.y = terrain.get_height(pos.x, pos.z) + 0.05
		citizen.global_position = pos
		citizen.visual.rotation.y = ang + PI * 0.5
	remaining -= count
	if remaining <= 0:
		_finish()
	else:
		group_size = clampi(group_size, 1, remaining)
		_refresh_label()


## Reparto automático 4+4+2 para tests y repros (--autoplace / --newgame):
## tres rincones separados del mapa gigante, con búsqueda en espiral.
func autoplace_default() -> void:
	var anchors: Array[Vector3] = [
		Vector3(0.0, 0.0, 6.0), Vector3(-230.0, 0.0, -170.0), Vector3(210.0, 0.0, 190.0)
	]
	var splits: Array[int] = [4, 4, 2]
	for i: int in anchors.size():
		if remaining <= 0:
			break
		var target: Vector3 = _find_valid_near(anchors[i])
		if target == Vector3.INF:
			continue
		drop_band(target, mini(splits[i], remaining))
	# Si quedó gente sin sitio (mapa hostil), al centro con los primeros.
	while remaining > 0:
		var fallback: Vector3 = _find_valid_near(Vector3(6.0, 0.0, -6.0))
		if fallback == Vector3.INF:
			push_error("BandPlacer: sin punto válido para el resto de colonos")
			_finish()
			return
		drop_band(fallback, remaining)


func _find_valid_near(anchor: Vector3, ring_step: float = 3.0, rings: int = 8) -> Vector3:
	var terrain: TerrainData = GameState.terrain
	for ring: int in rings:
		for step: int in 8:
			var ang: float = TAU * float(step) / 8.0
			var candidate: Vector3 = (
				anchor
				+ Vector3(
					cos(ang) * float(ring) * ring_step, 0.0, sin(ang) * float(ring) * ring_step
				)
			)
			candidate.y = terrain.get_height(candidate.x, candidate.z)
			if _is_valid(candidate):
				return candidate
	return Vector3.INF


func _finish() -> void:
	GameState.placement_pending = false
	_world._bake_navmesh()
	SimClock.set_speed(SimClock.Speed.NORMAL)
	if _tools != null:
		_tools.set_process_input(true)
		_tools.set_process_unhandled_input(true)
	if _hud != null:
		_hud.visible = true
	EventBus.placement_finished.emit()
	EventBus.toast.emit("Tu gente está en camino: enciende sus historias", &"success")
	queue_free()
