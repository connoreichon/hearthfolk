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
	_axe_cursor = _make_axe_cursor()


func set_tool(tool: StringName) -> void:
	if current_tool == tool:
		tool = &"none"
	current_tool = tool
	_set_hover(null)
	_cancel_drag()
	if tool == &"chop":
		Input.set_custom_mouse_cursor(_axe_cursor, Input.CURSOR_ARROW, Vector2(4.0, 4.0))
	else:
		Input.set_custom_mouse_cursor(null)
	EventBus.tool_changed.emit(current_tool)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tool_chop"):
		set_tool(&"chop")
		return
	if event.is_action_pressed(&"tool_cancel") and current_tool != &"none":
		set_tool(&"none")
		return
	if current_tool != &"chop":
		return

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
