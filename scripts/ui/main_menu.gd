extends Node3D
## Menú principal: el asentamiento vive de fondo al atardecer mientras
## eliges partida. Nueva partida (slot + semilla), cargar, opciones, salir.

const MENU_SEED: int = 31415
const GAME_SCENE: String = "res://scenes/main/main.tscn"

var _palette: PaletteData
var _camera: Camera3D
var _orbit_angle: float = 0.6
var _bg_world: Node
var _root_box: VBoxContainer
var _new_box: VBoxContainer
var _load_box: VBoxContainer
var _options: OptionsPanel
var _seed_edit: LineEdit
var _fav_pick: OptionButton
var _settlers_slider: HSlider
var _settlers_value: Label
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
	_bg_world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	add_child(_bg_world)
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
		elif args[i] == "--newgame":
			# Repro automatizada del clic real del jugador: slot + Empezar.
			_seed_edit.text = "1234"
			_show_new_game()
			_start_new_game.call_deferred()


func _capture(path: String) -> void:
	# Conexión de señal en vez de await: si el menú se libera antes de los
	# 3 s (p. ej. --newgame), la conexión muere con el nodo sin reanudar
	# una corrutina sobre un objeto liberado.
	get_tree().create_timer(3.0).timeout.connect(_do_capture.bind(path))


func _do_capture(path: String) -> void:
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
	version.text = "Build 003 · Las Culturas del Fuego"
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
	UiCraft.style_button(dice)
	seed_row.add_child(dice)
	# Favoritos de semilla (orden del dueño): cada mapa es distinto, pero el
	# que te enamore se guarda con estrella y vuelves a él cuando quieras.
	var fav_row: HBoxContainer = HBoxContainer.new()
	fav_row.add_theme_constant_override(&"separation", 8)
	_new_box.add_child(fav_row)
	var star: Button = Button.new()
	star.text = "★ Guardar mapa"
	star.tooltip_text = "Guarda esta semilla en favoritos"
	star.pressed.connect(_save_favorite)
	UiCraft.style_button(star)
	fav_row.add_child(star)
	_fav_pick = OptionButton.new()
	_fav_pick.custom_minimum_size = Vector2(170.0, 0.0)
	_fav_pick.item_selected.connect(_on_favorite_picked)
	fav_row.add_child(_fav_pick)
	_refresh_favorites()
	var settlers_row: HBoxContainer = HBoxContainer.new()
	settlers_row.add_theme_constant_override(&"separation", 8)
	_new_box.add_child(settlers_row)
	var settlers_label: Label = Label.new()
	settlers_label.text = "Colonos:"
	settlers_label.add_theme_color_override(&"font_color", _palette.ui_text)
	settlers_row.add_child(settlers_label)
	_settlers_slider = HSlider.new()
	_settlers_slider.min_value = 6
	_settlers_slider.max_value = 16
	_settlers_slider.step = 1
	_settlers_slider.value = 10
	_settlers_slider.custom_minimum_size = Vector2(150.0, 0.0)
	_settlers_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_settlers_slider.value_changed.connect(_on_settlers_changed)
	settlers_row.add_child(_settlers_slider)
	_settlers_value = Label.new()
	_settlers_value.text = "10"
	_settlers_value.add_theme_color_override(&"font_color", _palette.accent)
	settlers_row.add_child(_settlers_value)
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
	panel.add_theme_stylebox_override(&"panel", UiCraft.panel())
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
	UiCraft.style_button(button)
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


func _on_settlers_changed(value: float) -> void:
	_settlers_value.text = str(int(value))


## --- Favoritos de semilla (user://seed_favorites.json) ---


func _favorites() -> Array:
	if not FileAccess.file_exists("user://seed_favorites.json"):
		return []
	var file: FileAccess = FileAccess.open("user://seed_favorites.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []


func _save_favorite() -> void:
	var seed_text: String = _seed_edit.text.strip_edges()
	if seed_text.is_empty():
		return
	var favs: Array = _favorites()
	if seed_text in favs:
		return
	favs.append(seed_text)
	# Como mucho 12 favoritos: los más nuevos desplazan a los más viejos
	while favs.size() > 12:
		favs.pop_front()
	var file: FileAccess = FileAccess.open("user://seed_favorites.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(favs))
	_refresh_favorites()
	AudioDirector.play_ui(&"ui_confirm")


func _refresh_favorites() -> void:
	_fav_pick.clear()
	_fav_pick.add_item("★ Favoritos…")
	_fav_pick.set_item_disabled(0, true)
	for fav: Variant in _favorites():
		_fav_pick.add_item("Mapa %s" % str(fav))
	_fav_pick.visible = _fav_pick.item_count > 1


func _on_favorite_picked(index: int) -> void:
	if index <= 0:
		return
	var favs: Array = _favorites()
	if index - 1 < favs.size():
		_seed_edit.text = str(favs[index - 1])


func _prepare_new_game_state() -> void:
	var seed_value: int = (
		int(_seed_edit.text) if _seed_edit.text.is_valid_int() else hash(_seed_edit.text)
	)
	if seed_value == 0:
		seed_value = 1
	SaveManager.active_slot = _slot_pick
	GameState.pending_new_seed = seed_value
	GameState.pending_settlers = int(_settlers_slider.value)
	GameState.placement_pending = true


func _start_new_game() -> void:
	_prepare_new_game_state()
	_change_to_game()


func _load_slot(slot: int) -> void:
	# Cargar jamás hereda una siembra pendiente de otra partida abandonada
	GameState.placement_pending = false
	GameState.pending_load_slot = slot
	_change_to_game()


## Liberar un mundo simulado vivo en mitad de change_scene corrompe el heap
## con el template release (0xc0000005 en ntdll; en debug la validación de
## instancias lo enmascara como errores benignos). Orden seguro: parar los
## ticks, liberar el mundo de fondo, esperar dos frames a que muera del
## todo y solo entonces cambiar de escena.
func _change_to_game() -> void:
	SimClock.set_speed(SimClock.Speed.PAUSED)
	set_process(false)
	if _bg_world != null:
		_bg_world.queue_free()
		_bg_world = null
	TaskBoard.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	EntityRegistry.clear()
	get_tree().change_scene_to_file(GAME_SCENE)
