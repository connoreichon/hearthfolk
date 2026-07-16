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
	&"Farm": "Trabajando el huerto",
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
var _milestones_panel: PanelContainer
var _milestones_label: Label
var _settlements_panel: PanelContainer


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
	# Método con nombre, no lambda: las lambdas conectadas a señales de un
	# autoload NO se desconectan al morir el nodo (use-after-free en release).
	SimClock.speed_changed.connect(_on_speed_changed_signal)
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
	# Paneles con oficio (pulido UI): borde de brasa, esquinas amables y
	# sombra suave — dejan de ser cajas negras planas.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_palette.ui_panel, bg_alpha)
	style.set_corner_radius_all(9)
	style.border_color = Color(_palette.accent, 0.4)
	style.set_border_width_all(1)
	style.border_blend = true
	style.shadow_color = Color(0.05, 0.05, 0.06, 0.35)
	style.shadow_size = 6
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
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
	var milestones_button: Button = Button.new()
	milestones_button.text = "Hitos"
	milestones_button.focus_mode = Control.FOCUS_NONE
	milestones_button.pressed.connect(_toggle_milestones)
	row.add_child(milestones_button)
	var settlements_button: Button = Button.new()
	settlements_button.text = "Aldeas"
	settlements_button.focus_mode = Control.FOCUS_NONE
	settlements_button.pressed.connect(_toggle_settlements)
	row.add_child(settlements_button)
	var overview_button: Button = Button.new()
	overview_button.text = "Águila"
	overview_button.tooltip_text = "Vista de águila: el valle entero (M)"
	overview_button.focus_mode = Control.FOCUS_NONE
	overview_button.pressed.connect(_toggle_overview)
	row.add_child(overview_button)


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
		[&"farm", "Huerto", "Dibuja un huerto para cultivar comida (H)"],
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


## Panel de hitos (Q5): lista con casillas, se refresca al abrir.
func _toggle_milestones() -> void:
	if _milestones_panel == null:
		_milestones_panel = PanelContainer.new()
		_milestones_panel.add_theme_stylebox_override(&"panel", _panel_style())
		_milestones_panel.position = Vector2(10.0, 60.0)
		add_child(_milestones_panel)
		var box: VBoxContainer = VBoxContainer.new()
		_milestones_panel.add_child(box)
		var title: Label = Label.new()
		title.text = "Hitos del asentamiento"
		title.add_theme_color_override(&"font_color", _palette.accent)
		title.add_theme_font_size_override(&"font_size", 18)
		box.add_child(title)
		_milestones_label = Label.new()
		_milestones_label.add_theme_color_override(&"font_color", _palette.ui_text)
		box.add_child(_milestones_label)
	else:
		_milestones_panel.visible = not _milestones_panel.visible
	if _milestones_panel.visible:
		var nodes: Array[Node] = get_tree().get_nodes_in_group(&"milestones")
		if not nodes.is_empty():
			_milestones_label.text = String(nodes[0].call(&"summary"))


## Panel de aldeas (orden del dueño): cada asentamiento con su emblema,
## nombre, rango y población — y un botón para volar la cámara hasta él.
func _toggle_settlements() -> void:
	if _settlements_panel == null:
		_settlements_panel = PanelContainer.new()
		_settlements_panel.add_theme_stylebox_override(&"panel", _panel_style())
		_settlements_panel.position = Vector2(10.0, 60.0)
		add_child(_settlements_panel)
	else:
		_settlements_panel.visible = not _settlements_panel.visible
	if not _settlements_panel.visible:
		return
	for child: Node in _settlements_panel.get_children():
		child.free()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	_settlements_panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Aldeas del valle"
	title.add_theme_color_override(&"font_color", _palette.accent)
	title.add_theme_font_size_override(&"font_size", 18)
	box.add_child(title)
	var camps: Array[Node] = get_tree().get_nodes_in_group(&"camps")
	camps.sort_custom(
		func(a: Node, b: Node) -> bool: return (a as CampEntity).band_id < (b as CampEntity).band_id
	)
	for node: Node in camps:
		var camp: CampEntity = node as CampEntity
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		box.add_child(row)
		row.add_child(SettlementEmblem.new(camp.home_biome, camp.camp_seed))
		var info: VBoxContainer = VBoxContainer.new()
		row.add_child(info)
		var name_label: Label = Label.new()
		name_label.text = camp.settlement_name
		name_label.add_theme_color_override(&"font_color", _palette.ui_text)
		name_label.add_theme_font_size_override(&"font_size", 16)
		info.add_child(name_label)
		var detail: Label = Label.new()
		detail.text = "%s · %d habitantes" % [camp.rank_name(), camp.population()]
		detail.add_theme_color_override(&"font_color", Color(_palette.ui_text, 0.65))
		detail.add_theme_font_size_override(&"font_size", 13)
		info.add_child(detail)
		var trades: Label = Label.new()
		trades.text = _profession_summary(camp.band_id)
		trades.add_theme_color_override(&"font_color", Color(_palette.ui_text, 0.55))
		trades.add_theme_font_size_override(&"font_size", 12)
		info.add_child(trades)
		var go: Button = Button.new()
		go.text = "Ir"
		go.focus_mode = Control.FOCUS_NONE
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(_focus_camp.bind(camp.global_position))
		row.add_child(go)


func _focus_camp(point: Vector3) -> void:
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty():
		var rig: CameraRig = rigs[0] as CameraRig
		# Ir a una aldea también baja del águila al suelo
		rig.set_overview(false)
		rig.focus_on(point)


func _toggle_overview() -> void:
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty():
		var rig: CameraRig = rigs[0] as CameraRig
		rig.set_overview(not rig.overview)


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


func _on_speed_changed_signal(_speed: int) -> void:
	_refresh_speed_buttons()


func _refresh_speed_buttons() -> void:
	for key: int in _speed_buttons:
		(_speed_buttons[key] as Button).disabled = SimClock.speed == key


func _process(_delta: float) -> void:
	var population: int = get_tree().get_nodes_in_group(&"citizens").size()
	_top_label.text = (
		"Año %d · %s · Día %d   %s   Población %d/%d   Madera %d   Comida %d"
		% [
			SimClock.get_year(),
			SimClock.season_name(),
			SimClock.day,
			SimClock.get_clock_text(),
			population,
			SettlerArrivals.total_beds(get_tree()),
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
	elif node is FarmField:
		var farm: FarmField = node as FarmField
		_panel_title.text = "Huerto"
		_panel_body.text = (
			"Maduras: %d   Creciendo: %d\nPor plantar: %d%s"
			% [
				farm.count_by_state(FarmField.Plot.MATURE),
				(
					farm.count_by_state(FarmField.Plot.PLANTED)
					+ farm.count_by_state(FarmField.Plot.SPROUT)
				),
				farm.count_by_state(FarmField.Plot.BARREN),
				(
					"\nEl huerto duerme en invierno"
					if SimClock.get_season() == SimClock.Season.WINTER
					else ""
				),
			]
		)
		_panel_progress.visible = false
		_hide_dest_line()
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
		"%s · %s\nÁnimo: %s (%d %%)\nHambre: %d   Energía: %d\nTarea: %s%s"
		% [
			Professions.display_name(citizen.data.profession),
			String(STATE_TEXT.get(state, String(state))),
			citizen.mood_text(),
			int(citizen.morale() * 100.0),
			int(citizen.hunger),
			int(citizen.energy),
			task_text,
			_traits_text(citizen),
		]
	)
	_panel_progress.visible = false
	_update_dest_line(citizen)


## Rasgos con voz de crónica, nada de números pelados (§S2).
func _traits_text(citizen: Citizen) -> String:
	var lines: String = ""
	for id: StringName in citizen.data.traits:
		var entry: Dictionary = TraitCatalog.entry(id)
		if entry.is_empty():
			continue
		lines += "\n· %s — %s" % [String(entry["nombre"]), String(entry["detalle"])]
	return lines


## «2 leñadores · 1 agricultor» — resumen de oficios de una banda.
func _profession_summary(band: int) -> String:
	var counts: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		if citizen == null or citizen.band_id != band:
			continue
		var profession: StringName = citizen.data.profession
		counts[profession] = int(counts.get(profession, 0)) + 1
	var parts: Array[String] = []
	for profession: StringName in Professions.LIST:
		var n: int = int(counts.get(profession, 0))
		if n == 0:
			continue
		var trade_name: String = Professions.display_name(profession).to_lower()
		parts.append("%d %s%s" % [n, trade_name, "es" if n > 1 else ""])
	if parts.is_empty():
		return "Aún sin oficios"
	return " · ".join(parts)


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
