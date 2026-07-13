extends Node3D
## Punto de entrada. Registra el mapa de entrada, gestiona la velocidad de
## simulación (Espacio/1/2/3) y soporta capturas automatizadas:
## godot --path . -- --screenshot ruta.png [segundos]

var _resume_speed: int = SimClock.Speed.NORMAL


func _ready() -> void:
	InputSetup.setup()
	var tool_manager: ToolManager = ToolManager.new()
	tool_manager.name = "ToolManager"
	tool_manager.camera = ($CameraRig as CameraRig).camera
	add_child(tool_manager)
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
		elif args[i] == "--mark-tree":
			_debug_mark_nearest_tree.call_deferred()
		elif args[i] == "--build-house":
			_debug_place_house.call_deferred()
		elif args[i] == "--speed" and i + 1 < args.size():
			SimClock.set_speed(int(args[i + 1]))


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


func _unhandled_input(event: InputEvent) -> void:
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


func _capture(path: String, wait_s: float) -> void:
	await get_tree().create_timer(wait_s).timeout
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print(
		"screenshot %s -> %s (FPS=%d)" % [path, error_string(err), Engine.get_frames_per_second()]
	)
	get_tree().quit(0 if err == OK else 1)
