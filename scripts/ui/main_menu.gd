extends Node3D
## Menú principal: el asentamiento vive de fondo al atardecer mientras
## eliges partida. Nueva partida (slot + semilla), cargar, opciones, salir.

const MENU_SEED: int = 31415
const GAME_SCENE: String = "res://scenes/main/main.tscn"

var _palette: PaletteData
var _camera: Camera3D
var _orbit_angle: float = 0.6
var _root_box: VBoxContainer
var _new_box: VBoxContainer
var _load_box: VBoxContainer
var _options: OptionsPanel
var _seed_edit: LineEdit
var _slot_pick: int = 1
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	_palette = PaletteData.get_default()
	Settings.load_and_apply()
	Settings.apply_window_icon()
	# Mundo de fondo con semilla fija de escaparate, al atardecer
	TaskBoard.clear()
	EntityRegistry.clear()
	GameState.setup_new_game(MENU_SEED)
	GameState.add_resource(&"food", 12)
	var world: Node = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	add_child(world)
	SimClock.reset(1, 0.60)
	SimClock.set_speed(1)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	_build_ui()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			_capture(args[i + 1])


func _capture(path: String) -> void:
	await get_tree().create_timer(3.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	print("screenshot %s -> %s" % [path, error_string(image.save_png(path))])
	get_tree().quit()


func _process(delta: float) -> void:
	_orbit_angle += delta * 0.045
	_camera.position = Vector3(cos(_orbit_angle) * 20.0, 11.0, sin(_orbit_angle) * 20.0)
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)

	var title: Label = Label.new()
	title.text = "HEARTHFOLK"
	title.add_theme_font_size_override(&"font_size", 84)
	title.add_theme_color_override(&"font_color", _palette.ui_text)
	title.add_theme_color_override(&"font_shadow_color", _palette.ui_panel)
	title.add_theme_constant_override(&"shadow_offset_x", 3)
	title.add_theme_constant_override(&"shadow_offset_y", 3)
	title.position = Vector2(70.0, 60.0)
	layer.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "un asentamiento que vive solo"
	subtitle.add_theme_font_size_override(&"font_size", 22)
	subtitle.add_theme_color_override(&"font_color", _palette.accent)
	subtitle.position = Vector2(76.0, 150.0)
	layer.add_child(subtitle)

	var version: Label = Label.new()
	version.text = "Build 002"
	version.add_theme_color_override(&"font_color", Color(_palette.ui_text, 0.55))
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -140.0
	version.offset_top = -34.0
	layer.add_child(version)

	_root_box = _menu_box(layer)
	_add_button(_root_box, "Nueva partida", _show_new_game)
	_add_button(_root_box, "Cargar partida", _show_load)
	_add_button(_root_box, "Opciones", _show_options)
	_add_button(_root_box, "Salir", func() -> void: get_tree().quit())

	_new_box = _menu_box(layer)
	_panel_of(_new_box).visible = false
	var slot_label: Label = Label.new()
	slot_label.text = "Elige hueco de guardado:"
	slot_label.add_theme_color_override(&"font_color", _palette.ui_text)
	_new_box.add_child(slot_label)
	for slot: int in range(1, SaveManager.SLOTS + 1):
		var button: Button = _add_button(
			_new_box, SaveManager.slot_summary(slot), _pick_slot.bind(slot)
		)
		button.toggle_mode = true
		_slot_buttons.append(button)
	_pick_slot(1)
	var seed_row: HBoxContainer = HBoxContainer.new()
	seed_row.add_theme_constant_override(&"separation", 8)
	_new_box.add_child(seed_row)
	var seed_label: Label = Label.new()
	seed_label.text = "Semilla:"
	seed_label.add_theme_color_override(&"font_color", _palette.ui_text)
	seed_row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(140.0, 0.0)
	_seed_edit.text = str(randi() % 100000)
	seed_row.add_child(_seed_edit)
	var dice: Button = Button.new()
	dice.text = "Azar"
	dice.pressed.connect(func() -> void: _seed_edit.text = str(randi() % 100000))
	seed_row.add_child(dice)
	_add_button(_new_box, "Empezar", _start_new_game)
	_add_button(_new_box, "Volver", _show_root)

	_load_box = _menu_box(layer)
	_panel_of(_load_box).visible = false
	for slot: int in range(1, SaveManager.SLOTS + 1):
		var summary: String = SaveManager.slot_summary(slot)
		var button: Button = _add_button(_load_box, summary, _load_slot.bind(slot))
		button.disabled = not SaveManager.has_save(slot)
	_add_button(_load_box, "Volver", _show_root)

	_options = OptionsPanel.new()
	_options.visible = false
	_options.anchor_left = 0.5
	_options.anchor_top = 0.5
	_options.anchor_right = 0.5
	_options.anchor_bottom = 0.5
	_options.offset_left = -220.0
	_options.offset_top = -200.0
	_options.closed.connect(_show_root)
	layer.add_child(_options)


func _menu_box(layer: CanvasLayer) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_palette.ui_panel, 0.88)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = Vector2(70.0, 230.0)
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)
	box.set_meta(&"panel", panel)
	return box


func _add_button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	box.add_child(button)
	return button


func _panel_of(box: VBoxContainer) -> PanelContainer:
	return box.get_meta(&"panel")


func _show_root() -> void:
	_panel_of(_root_box).visible = true
	_panel_of(_new_box).visible = false
	_panel_of(_load_box).visible = false
	_options.visible = false


func _show_new_game() -> void:
	_panel_of(_root_box).visible = false
	_panel_of(_new_box).visible = true


func _show_load() -> void:
	_panel_of(_root_box).visible = false
	_panel_of(_load_box).visible = true


func _show_options() -> void:
	_panel_of(_root_box).visible = false
	_options.visible = true


func _pick_slot(slot: int) -> void:
	_slot_pick = slot
	for i: int in _slot_buttons.size():
		_slot_buttons[i].set_pressed_no_signal(i + 1 == slot)


func _prepare_new_game_state() -> void:
	var seed_value: int = (
		int(_seed_edit.text) if _seed_edit.text.is_valid_int() else hash(_seed_edit.text)
	)
	if seed_value == 0:
		seed_value = 1
	SaveManager.active_slot = _slot_pick
	GameState.pending_new_seed = seed_value


func _start_new_game() -> void:
	_prepare_new_game_state()
	get_tree().change_scene_to_file(GAME_SCENE)


func _load_slot(slot: int) -> void:
	GameState.pending_load_slot = slot
	get_tree().change_scene_to_file(GAME_SCENE)
