class_name ToolManager
extends Node
## Herramientas del jugador. P4: "Marcar tala" (T) con clic, caja de
## arrastre, hover con contorno y validación de alcanzabilidad.

const DRAG_THRESHOLD: float = 7.0

var camera: Camera3D
var current_tool: StringName = &"none"

var _hovered: TreeEntity
var _pressing: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _box: Panel
var _axe_cursor: ImageTexture

var _zone_dragging: bool = false
var _zone_start: Vector3 = Vector3.ZERO
var _zone_rect: Rect2 = Rect2()
var _zone_valid: bool = false
var _zone_reason: String = ""
var _ghost: MeshInstance3D
var _zone_label: Label


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_box = Panel.new()
	_box.visible = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette: PaletteData = PaletteData.get_default()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette.accent, 0.12)
	style.border_color = palette.accent
	style.set_border_width_all(2)
	_box.add_theme_stylebox_override(&"panel", style)
	layer.add_child(_box)
	_zone_label = Label.new()
	_zone_label.visible = false
	_zone_label.add_theme_color_override(&"font_color", palette.ui_text)
	_zone_label.add_theme_color_override(&"font_shadow_color", palette.ui_panel)
	_zone_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_zone_label.add_theme_constant_override(&"shadow_offset_y", 1)
	layer.add_child(_zone_label)
	_axe_cursor = _make_axe_cursor()


func set_tool(tool: StringName) -> void:
	if current_tool == tool:
		tool = &"none"
	current_tool = tool
	_set_hover(null)
	_cancel_drag()
	_cancel_zone()
	if tool == &"chop":
		Input.set_custom_mouse_cursor(_axe_cursor, Input.CURSOR_ARROW, Vector2(4.0, 4.0))
	else:
		Input.set_custom_mouse_cursor(null)
	Input.set_default_cursor_shape(
		Input.CURSOR_CROSS if tool == &"zone" or tool == &"farm" else Input.CURSOR_ARROW
	)
	EventBus.tool_changed.emit(current_tool)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tool_chop"):
		set_tool(&"chop")
		return
	if event.is_action_pressed(&"tool_zone"):
		set_tool(&"zone")
		return
	if event.is_action_pressed(&"tool_farm"):
		set_tool(&"farm")
		return
	if event.is_action_pressed(&"tool_demolish"):
		set_tool(&"demolish")
		return
	if event.is_action_pressed(&"tool_info"):
		set_tool(&"info")
		return
	if event.is_action_pressed(&"tool_cancel") and current_tool != &"none":
		set_tool(&"none")
		get_viewport().set_input_as_handled()
		return
	if current_tool == &"zone" or current_tool == &"farm":
		_zone_input(event)
	elif current_tool == &"chop":
		_chop_input(event)
	elif current_tool == &"demolish":
		_demolish_input(event)
	else:
		_select_input(event)


## Selección (herramienta por defecto e Información): clic → panel lateral.
func _select_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.double_click:
		return
	var collider: Node = _selectable_at(mouse_button.position)
	var entity_id: int = -1
	if collider != null and collider.get(&"entity_id") != null:
		entity_id = int(collider.get(&"entity_id"))
	EventBus.selection_changed.emit(entity_id)


## Demoler/Cancelar (C): obras y zonas; también desmarca árboles.
func _demolish_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed:
		return
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		set_tool(&"none")
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	var collider: Node = _selectable_at(mouse_button.position)
	if collider is TreeEntity:
		_unmark(collider as TreeEntity)
		return
	var site: ConstructionSite = collider as ConstructionSite
	if site == null:
		return
	if site.completed:
		EventBus.toast.emit("La cabaña terminada no se puede demoler en esta build", &"warn")
		return
	GameState.add_resource(&"wood", site.delivered_total)
	EventBus.toast.emit(
		"Obra cancelada: %d de madera devuelta al carro" % site.delivered_total, &"info"
	)
	var site_pos: Vector2 = Vector2(site.global_position.x, site.global_position.z)
	for node: Node in get_tree().get_nodes_in_group(&"zones"):
		var zone: ZoneEntity = node as ZoneEntity
		if zone != null and zone.rect.grow(1.0).has_point(site_pos):
			zone.queue_free()
	site.queue_free()


func _selectable_at(screen_pos: Vector2) -> Node:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 400.0, 1 << 7
	)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["collider"]


func _chop_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			set_tool(&"none")
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_pressing = true
				_drag_start = mouse_button.position
			else:
				if _dragging:
					_finish_box_selection(mouse_button.position)
				elif _hovered != null:
					_toggle_mark(_hovered)
				_pressing = false
				_cancel_drag()
		return

	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _pressing and not _dragging:
			if motion.position.distance_to(_drag_start) > DRAG_THRESHOLD:
				_dragging = true
				_box.visible = true
		if _dragging:
			_update_box(motion.position)
		else:
			_update_hover(motion.position)


func _update_hover(mouse_pos: Vector2) -> void:
	if camera == null:
		return
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var direction: Vector3 = camera.project_ray_normal(mouse_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 400.0, 1 << 7
	)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	var tree: TreeEntity = null
	if not hit.is_empty():
		tree = hit["collider"] as TreeEntity
	_set_hover(tree)


func _set_hover(tree: TreeEntity) -> void:
	if _hovered == tree:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.set_hovered(false)
	_hovered = tree
	if _hovered != null:
		_hovered.set_hovered(true, _hovered.choppable())


func _toggle_mark(tree: TreeEntity) -> void:
	if not tree.choppable():
		return
	if tree.marked:
		_unmark(tree)
	else:
		_mark(tree)


func _mark(tree: TreeEntity) -> void:
	if tree.marked or not tree.choppable():
		return
	var fire_pos: Vector3 = Vector3.ZERO
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		fire_pos = (fires[0] as Node3D).global_position
	if not NavUtil.is_reachable(camera.get_world_3d(), fire_pos, tree.global_position, 2.5):
		EventBus.toast.emit("Sin acceso: no hay camino hasta ese árbol", &"warn")
		return
	tree.set_marked(true)
	TaskBoard.publish(&"chop", tree.entity_id, {}, 5)


func _unmark(tree: TreeEntity) -> void:
	if not tree.marked:
		return
	tree.set_marked(false)
	var task: TaskBoard.Task = TaskBoard.first_task_for_target(tree.entity_id, &"chop")
	if task != null:
		TaskBoard.cancel(task.id, &"unmarked")


func _update_box(mouse_pos: Vector2) -> void:
	var rect: Rect2 = Rect2(_drag_start, mouse_pos - _drag_start).abs()
	_box.position = rect.position
	_box.size = rect.size


func _finish_box_selection(mouse_pos: Vector2) -> void:
	var rect: Rect2 = Rect2(_drag_start, mouse_pos - _drag_start).abs()
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree == null or not tree.choppable() or tree.marked:
			continue
		var world_pos: Vector3 = tree.global_position + Vector3(0.0, 1.2, 0.0)
		if camera.is_position_behind(world_pos):
			continue
		if rect.has_point(camera.unproject_position(world_pos)):
			_mark(tree)


func _cancel_drag() -> void:
	_pressing = false
	_dragging = false
	_box.visible = false


## --- Zona residencial (R): dibujar rectángulo con validación en vivo ---
func _zone_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			set_tool(&"none")
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				var hit: Vector3 = _terrain_point(mouse_button.position)
				if hit != Vector3.INF:
					_zone_dragging = true
					_zone_start = hit
					_update_zone_rect(hit)
			elif _zone_dragging:
				if _zone_valid:
					_confirm_zone()
				else:
					EventBus.toast.emit("Zona inválida: %s" % _zone_reason, &"warn")
				_cancel_zone()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _zone_dragging:
		var hit: Vector3 = _terrain_point(motion.position)
		if hit != Vector3.INF:
			_update_zone_rect(hit)
		_zone_label.position = motion.position + Vector2(18.0, 12.0)


func _terrain_point(screen_pos: Vector2) -> Vector3:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 500.0, 1
	)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	return hit["position"]


func _update_zone_rect(current: Vector3) -> void:
	var max_side: float = 8.0 if current_tool == &"farm" else 14.0
	var min_x: float = snappedf(minf(_zone_start.x, current.x), 0.5)
	var min_z: float = snappedf(minf(_zone_start.z, current.z), 0.5)
	var max_x: float = snappedf(maxf(_zone_start.x, current.x), 0.5)
	var max_z: float = snappedf(maxf(_zone_start.z, current.z), 0.5)
	var size_x: float = minf(max_x - min_x, max_side)
	var size_z: float = minf(max_z - min_z, max_side)
	_zone_rect = Rect2(min_x, min_z, size_x, size_z)
	var verdict: Dictionary = validate_zone(_zone_rect, camera.get_world_3d(), current_tool)
	_zone_valid = verdict["valid"]
	_zone_reason = verdict["reason"]
	_refresh_ghost()


func _refresh_ghost() -> void:
	var palette: PaletteData = PaletteData.get_default()
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.name = "ZoneGhost"
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.material_override = mat
		get_parent().add_child(_ghost)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(maxf(_zone_rect.size.x, 0.5), maxf(_zone_rect.size.y, 0.5))
	_ghost.mesh = plane
	var center: Vector2 = _zone_rect.get_center()
	var y: float = 0.1
	if GameState.terrain != null:
		y = GameState.terrain.get_height(center.x, center.y) + 0.12
	_ghost.position = Vector3(center.x, y, center.y)
	var mat: StandardMaterial3D = _ghost.material_override
	mat.albedo_color = (
		Color(palette.grass_light, 0.35) if _zone_valid else Color(palette.roof, 0.4)
	)
	_ghost.visible = true
	_zone_label.visible = true
	_zone_label.text = ("Zona válida — suelta para confirmar" if _zone_valid else _zone_reason)


## Validación §9. Siempre explica POR QUÉ no es válida.
func validate_zone(rect: Rect2, world: World3D, kind: StringName = &"zone") -> Dictionary:
	var reason: String = _zone_geometry_error(rect, kind)
	if reason.is_empty():
		reason = _zone_overlap_error(rect)
	if reason.is_empty():
		reason = _zone_access_error(rect, world)
	return {"valid": reason.is_empty(), "reason": reason}


func _zone_geometry_error(rect: Rect2, kind: StringName = &"zone") -> String:
	var min_side: float = 3.0 if kind == &"farm" else 6.0
	if rect.size.x < min_side or rect.size.y < min_side:
		return "Demasiado pequeña (mínimo %d×%d m)" % [int(min_side), int(min_side)]
	var terrain: TerrainData = GameState.terrain
	if terrain == null:
		return "Sin terreno"
	var corners: Array[Vector2] = [
		rect.position,
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.position.y),
	]
	for corner: Vector2 in corners:
		if not terrain.is_inside(corner.x, corner.y, 2.0):
			return "Fuera del mapa"
	if rect.position.x < -44.0:
		return "Sobre el agua"
	var slope_total: float = 0.0
	for ix: int in 5:
		for iz: int in 5:
			var sx: float = rect.position.x + rect.size.x * float(ix) / 4.0
			var sz: float = rect.position.y + rect.size.y * float(iz) / 4.0
			slope_total += terrain.get_slope_deg(sx, sz)
	if slope_total / 25.0 > 8.0:
		return "Terreno demasiado inclinado"
	return ""


func _zone_overlap_error(rect: Rect2) -> String:
	var grown: Rect2 = rect.grow(0.5)
	for group: StringName in [&"trees", &"rocks_big", &"storage", &"campfire"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var pos: Vector3 = (node as Node3D).global_position
			if grown.has_point(Vector2(pos.x, pos.z)):
				return "Hay árboles dentro" if group == &"trees" else "Hay obstáculos dentro"
	for node: Node in get_tree().get_nodes_in_group(&"construction_sites"):
		var pos: Vector3 = (node as Node3D).global_position
		if grown.grow(2.5).has_point(Vector2(pos.x, pos.z)):
			return "Solapa otra construcción"
	for node: Node in get_tree().get_nodes_in_group(&"zones"):
		var zone: ZoneEntity = node as ZoneEntity
		if zone != null and grown.intersects(zone.rect):
			return "Solapa otra zona"
	for node: Node in get_tree().get_nodes_in_group(&"farms"):
		var farm: FarmField = node as FarmField
		if farm != null and grown.intersects(farm.rect):
			return "Solapa un huerto"
	return ""


func _zone_access_error(rect: Rect2, world: World3D) -> String:
	var terrain: TerrainData = GameState.terrain
	var center: Vector2 = rect.get_center()
	var fire_pos: Vector3 = Vector3.ZERO
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		fire_pos = (fires[0] as Node3D).global_position
	var center_3d: Vector3 = Vector3(center.x, terrain.get_height(center.x, center.y), center.y)
	if not NavUtil.is_reachable(world, fire_pos, center_3d, 3.5):
		return "Sin acceso desde el asentamiento"
	return ""


func _confirm_zone() -> void:
	var worlds: Array[Node] = get_tree().get_nodes_in_group(&"world")
	if worlds.is_empty():
		return
	var world_root: Node3D = (worlds[0] as Node).get_node("NavigationRegion3D") as Node3D
	if current_tool == &"farm":
		var field: FarmField = FarmField.place(world_root, _zone_rect)
		EventBus.toast.emit("Huerto marcado: %d parcelas por plantar" % field.plot_count(), &"info")
		set_tool(&"none")
		return
	var zone: ZoneEntity = ZoneEntity.create(_zone_rect)
	world_root.add_child(zone)
	EventBus.zone_confirmed.emit(zone.entity_id, _zone_rect, &"residential")
	var center: Vector2 = _zone_rect.get_center()
	var at: Vector3 = Vector3(center.x, GameState.terrain.get_height(center.x, center.y), center.y)
	# Orientación: la puerta (+X local) hacia la fogata, en pasos de 90°
	var fire_pos: Vector3 = Vector3.ZERO
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		fire_pos = (fires[0] as Node3D).global_position
	var to_fire: Vector3 = fire_pos - at
	var yaw: float = snappedf(atan2(to_fire.x, to_fire.z) - PI * 0.5, PI * 0.5)
	var site_seed: int = GameState.derive_seed(["cottage", zone.entity_id])
	var site: ConstructionSite = ConstructionSite.place(world_root, at, yaw, site_seed)
	EventBus.toast.emit(
		"Zona residencial confirmada: la cabaña pide %d de madera" % site.recipe.total_wood_cost(),
		&"info"
	)
	set_tool(&"none")


func _cancel_zone() -> void:
	_zone_dragging = false
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	if _zone_label != null:
		_zone_label.visible = false


## Cursor de hacha 24×24 dibujado a mano, sin assets externos.
func _make_axe_cursor() -> ImageTexture:
	var palette: PaletteData = PaletteData.get_default()
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	# Mango: diagonal desde (6,6) hasta (20,20)
	for i: int in 15:
		var x: int = 6 + i
		var y: int = 6 + i
		for w: int in 2:
			if x + w < 24:
				img.set_pixel(x + w, y, palette.wood_light)
				img.set_pixel(x, y + w, palette.wood)
	# Cabeza: bloque en el extremo superior izquierdo del mango
	for x: int in range(2, 11):
		for y: int in range(2, 9):
			if x + y < 15:
				img.set_pixel(x, y, palette.stone)
	# Filo
	for y: int in range(2, 9):
		var x: int = 12 - y
		if x >= 0 and x < 24:
			img.set_pixel(x, y, palette.ui_text)
	return ImageTexture.create_from_image(img)
