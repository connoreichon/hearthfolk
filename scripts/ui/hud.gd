class_name Hud
extends CanvasLayer
## HUD (§12): barra superior (día·hora·población·recursos·velocidad),
## barra inferior de herramientas, panel lateral de selección y toasts.

const STATE_TEXT: Dictionary = {
	&"Idle": "Tomando un respiro",
	&"Wander": "Paseando",
	&"FindTask": "Buscando qué hacer",
	&"MoveToResource": "Yendo al objetivo",
	&"Harvest": "Talando un árbol",
	&"CarryResource": "Recogiendo madera",
	&"DeliverResource": "Transportando madera",
	&"Supply": "Acarreando material a la obra",
	&"Build": "Construyendo",
	&"Eat": "Comiendo",
	&"Rest": "Descansando",
	&"ReturnToSettlement": "Volviendo al asentamiento",
	&"RecoverFromStuck": "Desatascándose",
}

var tool_manager: ToolManager

var _palette: PaletteData
var _top_label: Label
var _speed_buttons: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: Label
var _panel_progress: ProgressBar
var _toast_box: VBoxContainer
var _selected_id: int = -1
var _dest_line: MeshInstance3D


func _ready() -> void:
	layer = 40
	_palette = PaletteData.get_default()
	_build_top_bar()
	_build_bottom_bar()
	_build_side_panel()
	_build_toast_box()
	EventBus.toast.connect(_on_toast)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.tool_changed.connect(_on_tool_changed)
	SimClock.speed_changed.connect(func(_s: int) -> void: _refresh_speed_buttons())
	_refresh_speed_buttons()
	_dest_line = MeshInstance3D.new()
	_dest_line.name = "DestLine"
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(_palette.accent, 0.5)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dest_line.material_override = line_mat
	_dest_line.visible = false
	get_parent().add_child.call_deferred(_dest_line)


func _panel_style(bg_alpha: float = 0.92) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_palette.ui_panel, bg_alpha)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "TopBar"
	bar.add_theme_stylebox_override(&"panel", _panel_style())
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_top = 8.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	bar.add_child(row)
	_top_label = Label.new()
	_top_label.add_theme_color_override(&"font_color", _palette.ui_text)
	row.add_child(_top_label)
	for entry: Array in [["⏸", 0], ["×1", 1], ["×2", 2], ["×4", 4]]:
		var button: Button = Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(SimClock.set_speed.bind(int(entry[1])))
		row.add_child(button)
		_speed_buttons[int(entry[1])] = button


func _build_bottom_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "BottomBar"
	bar.add_theme_stylebox_override(&"panel", _panel_style())
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -52.0
	bar.offset_bottom = -10.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	bar.add_child(row)
	var tools: Array = [
		[&"none", "Selección", "Clic: seleccionar (Esc)"],
		[&"chop", "Marcar tala", "Marca árboles para talar (T)"],
		[&"zone", "Zona residencial", "Dibuja una zona para una cabaña (R)"],
		[&"demolish", "Demoler", "Cancela obras y zonas (C)"],
		[&"info", "Información", "Clic: inspeccionar (I)"],
	]
	for entry: Array in tools:
		var button: Button = Button.new()
		button.text = entry[1]
		button.tooltip_text = entry[2]
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		var tool: StringName = entry[0]
		button.pressed.connect(func() -> void: tool_manager.set_tool(tool))
		row.add_child(button)
		_tool_buttons[tool] = button
	_on_tool_changed(&"none")


func _build_side_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "SidePanel"
	_panel.add_theme_stylebox_override(&"panel", _panel_style())
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -280.0
	_panel.offset_right = -10.0
	_panel.offset_top = 60.0
	_panel.visible = false
	add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)
	_panel_title = Label.new()
	_panel_title.add_theme_color_override(&"font_color", _palette.accent)
	_panel_title.add_theme_font_size_override(&"font_size", 18)
	box.add_child(_panel_title)
	_panel_body = Label.new()
	_panel_body.add_theme_color_override(&"font_color", _palette.ui_text)
	box.add_child(_panel_body)
	_panel_progress = ProgressBar.new()
	_panel_progress.min_value = 0.0
	_panel_progress.max_value = 1.0
	_panel_progress.custom_minimum_size = Vector2(0.0, 14.0)
	_panel_progress.show_percentage = false
	box.add_child(_panel_progress)


func _build_toast_box() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.name = "Toasts"
	_toast_box.anchor_left = 1.0
	_toast_box.anchor_right = 1.0
	_toast_box.anchor_top = 1.0
	_toast_box.anchor_bottom = 1.0
	_toast_box.offset_left = -420.0
	_toast_box.offset_right = -10.0
	_toast_box.offset_top = -260.0
	_toast_box.offset_bottom = -60.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override(&"separation", 6)
	add_child(_toast_box)


func _on_toast(message: String, kind: StringName) -> void:
	while _toast_box.get_child_count() >= 4:
		_toast_box.get_child(0).free()
	var toast: PanelContainer = PanelContainer.new()
	toast.add_theme_stylebox_override(&"panel", _panel_style(0.85))
	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var color: Color = _palette.ui_text
	match kind:
		&"warn":
			color = _palette.accent
		&"error":
			color = _palette.roof
		&"success":
			color = _palette.grass_light
	label.add_theme_color_override(&"font_color", color)
	toast.add_child(label)
	_toast_box.add_child(toast)
	var tween: Tween = toast.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(toast, "modulate:a", 0.0, 0.8)
	tween.tween_callback(toast.queue_free)


func _on_selection_changed(entity_id: int) -> void:
	_selected_id = entity_id


func _on_tool_changed(tool: StringName) -> void:
	for key: StringName in _tool_buttons:
		(_tool_buttons[key] as Button).set_pressed_no_signal(key == tool)


func _refresh_speed_buttons() -> void:
	for key: int in _speed_buttons:
		(_speed_buttons[key] as Button).disabled = SimClock.speed == key


func _process(_delta: float) -> void:
	var population: int = get_tree().get_nodes_in_group(&"citizens").size()
	_top_label.text = (
		"Año %d · %s · Día %d   %s   Población %d   Madera %d   Comida %d"
		% [
			SimClock.get_year(),
			SimClock.season_name(),
			SimClock.day,
			SimClock.get_clock_text(),
			population,
			GameState.get_resource(&"wood"),
			GameState.get_resource(&"food"),
		]
	)
	_update_side_panel()


func _update_side_panel() -> void:
	var node: Node = EntityRegistry.get_node_by_id(_selected_id)
	if node == null:
		_panel.visible = false
		_hide_dest_line()
		return
	_panel.visible = true
	if node is Citizen:
		_show_citizen(node as Citizen)
	elif node is ConstructionSite:
		_show_site(node as ConstructionSite)
	elif node is TreeEntity:
		var tree: TreeEntity = node as TreeEntity
		_panel_title.text = "Árbol joven" if tree.young else "Árbol"
		_panel_body.text = ("Marcado para talar" if tree.marked else "Sin marcar")
		_panel_progress.visible = false
		_hide_dest_line()
	else:
		_panel_title.text = String(node.name)
		_panel_body.text = ""
		_panel_progress.visible = false
		_hide_dest_line()


func _show_citizen(citizen: Citizen) -> void:
	_panel_title.text = citizen.data.display_name
	var task: TaskBoard.Task = citizen.current_task()
	var task_text: String = "—"
	if task != null:
		task_text = "%s #%d" % [String(task.kind), task.id]
	var state: StringName = citizen.state_machine.current_name()
	_panel_body.text = (
		"%s\nHambre: %d   Energía: %d\nTarea: %s"
		% [
			String(STATE_TEXT.get(state, String(state))),
			int(citizen.hunger),
			int(citizen.energy),
			task_text,
		]
	)
	_panel_progress.visible = false
	_update_dest_line(citizen)


func _show_site(site: ConstructionSite) -> void:
	_panel_title.text = "Cabaña" if site.completed else "Obra: cabaña"
	var workers: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		var task: TaskBoard.Task = citizen.current_task()
		if task != null and task.target_id == site.entity_id:
			workers.append(citizen.data.display_name)
	_panel_body.text = (
		"Fase: %s\nMadera: %d / %d\nTrabajando: %s"
		% [
			site.current_phase_name(),
			site.delivered_total,
			site.recipe.total_wood_cost(),
			", ".join(workers) if not workers.is_empty() else "nadie",
		]
	)
	_panel_progress.visible = true
	_panel_progress.value = site.progress_fraction()
	_hide_dest_line()


## Línea sutil del habitante seleccionado hacia su destino (§12).
func _update_dest_line(citizen: Citizen) -> void:
	if not is_instance_valid(_dest_line):
		return
	if not citizen.is_moving():
		_hide_dest_line()
		return
	var from: Vector3 = citizen.global_position + Vector3(0.0, 0.25, 0.0)
	var to: Vector3 = citizen.nav_agent.target_position + Vector3(0.0, 0.25, 0.0)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	_dest_line.mesh = mesh
	_dest_line.visible = true


func _hide_dest_line() -> void:
	if is_instance_valid(_dest_line):
		_dest_line.visible = false
