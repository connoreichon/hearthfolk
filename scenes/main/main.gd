extends Node3D
## Punto de entrada. Registra el mapa de entrada, gestiona la velocidad de
## simulación (Espacio/1/2/3) y soporta capturas automatizadas:
## godot --path . -- --screenshot ruta.png [segundos]

var _resume_speed: int = SimClock.Speed.NORMAL
var _pause_layer: CanvasLayer
var _pause_options: OptionsPanel
var _pause_prev_speed: int = SimClock.Speed.NORMAL


func _ready() -> void:
	InputSetup.setup()
	Settings.load_and_apply()
	Settings.apply_window_icon()
	var tool_manager: ToolManager = ToolManager.new()
	tool_manager.name = "ToolManager"
	tool_manager.camera = ($CameraRig as CameraRig).camera
	add_child(tool_manager)
	var hud: Hud = Hud.new()
	hud.name = "Hud"
	hud.tool_manager = tool_manager
	add_child(hud)
	var tutorial: TutorialGuide = TutorialGuide.new()
	tutorial.name = "TutorialGuide"
	add_child(tutorial)
	_build_pause_menu()
	if GameState.pending_load_slot > 0:
		var slot: int = GameState.pending_load_slot
		GameState.pending_load_slot = 0
		SaveManager.load_game.call_deferred(slot)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			var wait_s: float = 2.0
			if i + 2 < args.size() and args[i + 2].is_valid_float():
				wait_s = float(args[i + 2])
			_capture(args[i + 1], wait_s)
		elif args[i] == "--zoom" and i + 1 < args.size():
			var rig: CameraRig = get_node_or_null("CameraRig") as CameraRig
			if rig != null:
				rig.set_zoom(float(args[i + 1]))
		elif args[i] == "--time" and i + 1 < args.size():
			SimClock.time_of_day = clampf(float(args[i + 1]), 0.0, 0.999)
		elif args[i] == "--day" and i + 1 < args.size():
			SimClock.day = maxi(1, int(args[i + 1]))
			SimClock.season_changed.emit(SimClock.get_season())
		elif args[i] == "--mark-tree":
			_debug_mark_nearest_tree.call_deferred()
		elif args[i] == "--build-house":
			_debug_place_house.call_deferred()
		elif args[i] == "--farm-demo":
			_debug_place_farm.call_deferred()
		elif args[i] == "--hungry":
			_debug_make_hungry.call_deferred()
		elif args[i] == "--speed" and i + 1 < args.size():
			SimClock.set_speed(int(args[i + 1]))


## Solo para smoke tests automatizados: huerto con cultivo acelerado.
func _debug_place_farm() -> void:
	SimConfig.get_default().crop_stage_seconds = 8.0
	var world_root: Node3D = get_node("World/NavigationRegion3D") as Node3D
	FarmField.place(world_root, Rect2(5.0, 4.0, 6.0, 5.0))


## Solo para smoke tests automatizados: hambre baja para verlos comer.
func _debug_make_hungry() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		(node as Citizen).hunger = 20.0


## Solo para smoke tests automatizados: coloca una obra con material listo.
func _debug_place_house() -> void:
	GameState.add_resource(&"wood", 12)
	var world_root: Node3D = get_node("World/NavigationRegion3D") as Node3D
	var at: Vector3 = Vector3(9.0, GameState.terrain.get_height(9.0, 9.0), 9.0)
	ConstructionSite.place(world_root, at, PI * 0.75, 777)


## Solo para smoke tests automatizados: marca el árbol adulto más cercano.
func _debug_mark_nearest_tree() -> void:
	var best: TreeEntity = null
	var best_d: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree == null or not tree.choppable():
			continue
		if tree.global_position.length() < best_d:
			best_d = tree.global_position.length()
			best = tree
	if best != null:
		best.set_marked(true)
		TaskBoard.publish(&"chop", best.entity_id, {}, 5)


## Menú de pausa (Esc sin herramienta activa).
func _build_pause_menu() -> void:
	var palette: PaletteData = PaletteData.get_default()
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 90
	_pause_layer.visible = false
	add_child(_pause_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(palette.ui_panel, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette.ui_panel, 0.96)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150.0
	panel.offset_top = -140.0
	_pause_layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override(&"font_size", 28)
	title.add_theme_color_override(&"font_color", palette.accent)
	box.add_child(title)
	for entry: Array in [
		["Continuar", _toggle_pause_menu],
		["Guardar partida", func() -> void: SaveManager.save_game()],
		["Opciones", _toggle_pause_options],
		["Salir al menú", _exit_to_menu],
	]:
		var button: Button = Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(260.0, 42.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		box.add_child(button)
	_pause_options = OptionsPanel.new()
	_pause_options.visible = false
	_pause_options.anchor_left = 0.5
	_pause_options.anchor_top = 0.5
	_pause_options.anchor_right = 0.5
	_pause_options.anchor_bottom = 0.5
	_pause_options.offset_left = -220.0
	_pause_options.offset_top = -200.0
	_pause_options.closed.connect(_toggle_pause_options)
	_pause_layer.add_child(_pause_options)


func _toggle_pause_menu() -> void:
	if _pause_layer.visible:
		_pause_layer.visible = false
		_pause_options.visible = false
		SimClock.set_speed(_pause_prev_speed)
	else:
		_pause_prev_speed = SimClock.speed if SimClock.speed != 0 else SimClock.Speed.NORMAL
		SimClock.set_speed(SimClock.Speed.PAUSED)
		_pause_layer.visible = true


func _toggle_pause_options() -> void:
	_pause_options.visible = not _pause_options.visible


func _exit_to_menu() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tool_cancel"):
		_toggle_pause_menu()
		return
	if event.is_action_pressed(&"sim_pause"):
		if SimClock.speed == SimClock.Speed.PAUSED:
			SimClock.set_speed(_resume_speed)
		else:
			_resume_speed = SimClock.speed
			SimClock.set_speed(SimClock.Speed.PAUSED)
	elif event.is_action_pressed(&"sim_speed_1"):
		SimClock.set_speed(SimClock.Speed.NORMAL)
	elif event.is_action_pressed(&"sim_speed_2"):
		SimClock.set_speed(SimClock.Speed.FAST)
	elif event.is_action_pressed(&"sim_speed_3"):
		SimClock.set_speed(SimClock.Speed.ULTRA)
	elif event.is_action_pressed(&"save_game"):
		SaveManager.save_game()
	elif event.is_action_pressed(&"load_game"):
		SaveManager.load_game()


func _capture(path: String, wait_s: float) -> void:
	await get_tree().create_timer(wait_s).timeout
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print(
		"screenshot %s -> %s (FPS=%d)" % [path, error_string(err), Engine.get_frames_per_second()]
	)
	get_tree().quit(0 if err == OK else 1)
