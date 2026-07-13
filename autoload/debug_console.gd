extends Node
## Overlay de depuración (F3): métricas en pantalla. Cheats se añaden en P7.

var _layer: CanvasLayer
var _label: Label
var _errors: Array[String] = []


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.visible = false
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	_label.add_theme_color_override(&"font_color", Color("#F3EEE4"))
	_label.add_theme_color_override(&"font_shadow_color", Color("#292B2C"))
	_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_label.add_theme_constant_override(&"shadow_offset_y", 1)
	_layer.add_child(_label)
	add_child(_layer)


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


func _process(_delta: float) -> void:
	if not _layer.visible:
		return
	var lines: Array[String] = []
	lines.append(
		(
			"FPS: %d  (%.2f ms)"
			% [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())]
		)
	)
	lines.append(
		(
			"Velocidad sim: x%d   Día %d  %s"
			% [SimClock.speed, SimClock.day, SimClock.get_clock_text()]
		)
	)
	lines.append("Tiempo sim: %.1f s" % SimClock.elapsed_sim_seconds)
	lines.append("Entidades registradas: %d" % EntityRegistry.count())
	var task_stats: Dictionary = TaskBoard.stats()
	lines.append(
		(
			"Tareas: %d libres / %d reservadas / %d fallos"
			% [int(task_stats["free"]), int(task_stats["claimed"]), int(task_stats["failed_total"])]
		)
	)
	lines.append(
		(
			"Madera: %d  Comida: %d"
			% [GameState.get_resource(&"wood"), GameState.get_resource(&"food")]
		)
	)
	if not _errors.is_empty():
		lines.append("--- Últimos errores ---")
		lines.append_array(_errors)
	_label.text = "\n".join(lines)
