class_name TutorialGuide
extends Node
## Minitutorial orgánico (petición del probador): pistas contextuales de una
## línea que se completan HACIENDO la acción, no leyéndola. Si el jugador ya
## hizo una acción por su cuenta, esa pista se salta sola. Solo aparece en la
## primera partida (persistido en settings.cfg) y se puede cerrar con ✕.

const STEPS: Array[Array] = [
	["camera", "Muévete con WASD · gira con Q y E · acércate con la rueda"],
	["chop", "Pulsa T y haz clic en un árbol: alguien irá a talarlo"],
	["zone", "Pulsa R y arrastra un rectángulo en el suelo: ahí crecerá una casa"],
	["farm", "Pulsa H y dibuja un huerto: la despensa no se llena sola"],
	["speed", "Espacio pausa · 1, 2 y 3 cambian la velocidad. Ahora… mira cómo viven"],
]

## Los tests lo activan aunque el settings.cfg del usuario ya tenga el flag.
var force_run: bool = false
## Los tests lo apagan para no marcar el tutorial como visto en user://.
var persist: bool = true

var _step: int = -1
var _done: Dictionary = {}
var _panel: PanelContainer
var _label: Label
var _camera_timer: float = 0.0


func _ready() -> void:
	if not force_run and Settings.is_tutorial_done():
		queue_free()
		return
	_build_ui()
	EventBus.tree_marked.connect(_on_tree_marked)
	EventBus.zone_confirmed.connect(_on_zone_confirmed)
	SimClock.speed_changed.connect(_on_speed_changed)
	_advance()


func _process(delta: float) -> void:
	if _step < 0 or _step >= STEPS.size():
		return
	var key: String = STEPS[_step][0]
	if key == "camera":
		if _camera_moving():
			_camera_timer += delta
			if _camera_timer > 0.7:
				_complete("camera")
	elif key == "farm":
		if not get_tree().get_nodes_in_group(&"farms").is_empty():
			_complete("farm")


func current_step_key() -> String:
	if _step < 0 or _step >= STEPS.size():
		return ""
	return STEPS[_step][0]


func _build_ui() -> void:
	var palette: PaletteData = PaletteData.get_default()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette.ui_panel, 0.92)
	style.border_color = palette.accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_top = 52.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_panel.add_child(row)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", palette.ui_text)
	row.add_child(_label)
	var skip: Button = Button.new()
	skip.text = "✕"
	skip.tooltip_text = "Saltar el tutorial"
	skip.focus_mode = Control.FOCUS_NONE
	skip.flat = true
	skip.pressed.connect(_finish)
	row.add_child(skip)


func _camera_moving() -> bool:
	return (
		Input.is_action_pressed(&"camera_forward")
		or Input.is_action_pressed(&"camera_back")
		or Input.is_action_pressed(&"camera_left")
		or Input.is_action_pressed(&"camera_right")
		or Input.is_action_pressed(&"camera_rotate_left")
		or Input.is_action_pressed(&"camera_rotate_right")
	)


func _on_tree_marked(_tree_id: int) -> void:
	_complete("chop")


func _on_zone_confirmed(_zone_id: int, _rect: Rect2, _kind: StringName) -> void:
	_complete("zone")


## La velocidad solo cuenta cuando es la pista activa: el arranque de la
## partida emite speed_changed y no debe quemar el último paso.
func _on_speed_changed(_speed: int) -> void:
	if current_step_key() == "speed":
		_complete("speed")


func _complete(key: String) -> void:
	if _done.has(key):
		return
	_done[key] = true
	if current_step_key() == key:
		AudioDirector.play_ui(&"ui_confirm")
		_advance()


func _advance() -> void:
	_step += 1
	while _step < STEPS.size() and _done.has(STEPS[_step][0]):
		_step += 1
	if _step >= STEPS.size():
		_finish()
		return
	_label.text = "%s      %d/%d" % [STEPS[_step][1], _step + 1, STEPS.size()]
	_panel.modulate.a = 0.0
	var fade: Tween = create_tween()
	fade.tween_property(_panel, "modulate:a", 1.0, 0.5)


func _finish() -> void:
	if persist:
		Settings.set_tutorial_done()
	set_process(false)
	_step = STEPS.size()
	if _panel != null and is_inside_tree():
		var fade: Tween = create_tween()
		fade.tween_property(_panel, "modulate:a", 0.0, 0.6)
		fade.tween_callback(queue_free)
	else:
		queue_free()
