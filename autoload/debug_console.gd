extends Node
## Overlay de depuración (F3): métricas, cheats y volúmenes (§15).

var _layer: CanvasLayer
var _label: Label
var _errors: Array[String] = []
var _stuck_total: int = 0
var _failed_paths: int = 0
var _tick_times: Array[float] = []
var _nav_debug: bool = false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.visible = false
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.17, 0.9)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override(&"panel", style)
	_layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", Color("#F3EEE4"))
	_label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(_label)
	box.add_child(_build_cheats())
	box.add_child(_build_volumes())
	add_child(_layer)
	SimClock.sim_tick.connect(_on_tick)
	EventBus.citizen_stuck.connect(func(_id: int, _pos: Vector3) -> void: _stuck_total += 1)
	EventBus.task_released.connect(_on_task_released)
	EventBus.construction_stalled.connect(
		func(_id: int, missing: Dictionary) -> void:
			log_error("Obra parada, falta: %s" % str(missing))
	)


func _build_cheats() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	var cheats: Array = [
		["+10 madera", func() -> void: GameState.add_resource(&"wood", 10)],
		["Completar obra", _cheat_complete_sites],
		["Vaciar necesidades", _cheat_needs.bind(6.0)],
		["Restaurar necesidades", _cheat_needs.bind(100.0)],
		["Avanzar 6 h", func() -> void: SimClock.advance_hours(6.0)],
		["Ver navegación", _cheat_toggle_nav],
		["Reiniciar IA", _cheat_reset_ai],
		["Forzar bloqueo", _cheat_force_stuck],
	]
	for cheat: Array in cheats:
		var button: Button = Button.new()
		button.text = cheat[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(cheat[1])
		grid.add_child(button)
	return grid


func _build_volumes() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	for bus_name: String in ["Master", "Ambience", "SFX", "UI"]:
		var label: Label = Label.new()
		label.text = bus_name
		label.add_theme_font_size_override(&"font_size", 12)
		grid.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = AudioDirector.get_bus_volume_linear(bus_name)
		slider.custom_minimum_size = Vector2(140.0, 16.0)
		slider.value_changed.connect(
			func(value: float) -> void: AudioDirector.set_bus_volume_linear(bus_name, value)
		)
		grid.add_child(slider)
	return grid


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return
	if key_event.keycode == KEY_F3 and key_event.pressed and not key_event.echo:
		_layer.visible = not _layer.visible


func log_error(message: String) -> void:
	_errors.append(message)
	if _errors.size() > 10:
		_errors.pop_front()


func _on_tick(_dt: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_tick_times.append(now)
	while not _tick_times.is_empty() and _tick_times[0] < now - 1.0:
		_tick_times.pop_front()


func _on_task_released(_task_id: int, reason: StringName) -> void:
	if reason == &"unreachable":
		_failed_paths += 1


func _process(_delta: float) -> void:
	if not _layer.visible:
		return
	var lines: Array[String] = []
	var fps: float = maxf(1.0, Engine.get_frames_per_second())
	lines.append("FPS %d (%.2f ms) | ticks/s: %d" % [int(fps), 1000.0 / fps, _tick_times.size()])
	(
		lines
		. append(
			(
				"Sim x%d | Día %d %s | t=%.0f s | ejecución %.0f s"
				% [
					SimClock.speed,
					SimClock.day,
					SimClock.get_clock_text(),
					SimClock.elapsed_sim_seconds,
					float(Time.get_ticks_msec()) / 1000.0,
				]
			)
		)
	)
	var states: Array[String] = []
	var trades: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		states.append("%s:%s" % [citizen.data.display_name, citizen.state_machine.current_name()])
		var trade: StringName = citizen.data.profession
		trades[trade] = int(trades.get(trade, 0)) + 1
	lines.append("Habitantes: " + " | ".join(states))
	var trade_parts: Array[String] = []
	for trade: StringName in trades:
		trade_parts.append("%s×%d" % [Professions.display_name(trade), int(trades[trade])])
	lines.append("Oficios: " + (" | ".join(trade_parts) if not trade_parts.is_empty() else "—"))
	var stats: Dictionary = TaskBoard.stats()
	(
		lines
		. append(
			(
				"Tareas: %d libres / %d reservadas / %d fallos | rutas fallidas %d | atascos %d"
				% [
					int(stats["free"]),
					int(stats["claimed"]),
					int(stats["failed_total"]),
					_failed_paths,
					_stuck_total,
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"Entidades %d | nodos %d | cuerpos físicos activos %d"
				% [
					EntityRegistry.count(),
					int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
					int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
				]
			)
		)
	)
	lines.append(
		"Madera %d | Comida %d" % [GameState.get_resource(&"wood"), GameState.get_resource(&"food")]
	)
	if not _errors.is_empty():
		lines.append("--- Últimos avisos ---")
		lines.append_array(_errors)
	_label.text = "\n".join(lines)


func _cheat_complete_sites() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"construction_sites"):
		var site: ConstructionSite = node as ConstructionSite
		if site != null and not site.completed:
			site.debug_complete()


func _cheat_needs(value: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		citizen.hunger = value
		citizen.energy = value


func _cheat_toggle_nav() -> void:
	_nav_debug = not _nav_debug
	NavigationServer3D.set_debug_enabled(_nav_debug)


func _cheat_reset_ai() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		citizen.drop_carry(true)
		citizen.abandon_task(&"yield")
		citizen.stop_moving()
		citizen.state_machine.change(&"Idle")


func _cheat_force_stuck() -> void:
	var citizens: Array[Node] = get_tree().get_nodes_in_group(&"citizens")
	if citizens.is_empty():
		return
	var citizen: Citizen = citizens[0] as Citizen
	EventBus.citizen_stuck.emit(citizen.entity_id, citizen.global_position)
	citizen.state_machine.change(&"RecoverFromStuck")
