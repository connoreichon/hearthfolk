extends SceneTree
## Sonda del SALTO VISUAL: 6 vistas fijas (amanecer, hora dorada, mediodía,
## noche, águila, primer plano) con la MISMA semilla y encuadres, para
## comparar antes/después al píxel.
##   godot --path . --resolution 1920x1080 -s tools/dev_probe_visual.gd -- --tag antes

const SEED: int = 4242
## Vistas: nombre → [time_of_day, tipo de encuadre]
const VIEWS: Array = [
	["amanecer", 0.09, "aldea"],
	["dorada", 0.62, "aldea"],
	["mediodia", 0.37, "aldea"],
	["noche", 0.85, "aldea"],
	["aguila", 0.55, "aguila"],
	["retrato", 0.60, "retrato"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tag: String = "despues"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--tag" and i + 1 < args.size():
			tag = args[i + 1]
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", SEED)
	game_state.call("add_resource", &"wood", 12)
	game_state.call("add_resource", &"food", 40)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 30:
		await process_frame
	# Dejar vivir un poco (colonos en marcha, sendas, fuego)
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 500:
		await process_frame
	sim_clock.call("set_speed", 0)
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var rig: Node3D = get_nodes_in_group(&"camera_rig")[0] as Node3D
	rig.set_process(false)
	var cam: Camera3D = Camera3D.new()
	main.add_child(cam)
	cam.current = true
	for view: Array in VIEWS:
		var view_name: String = view[0]
		sim_clock.set("time_of_day", float(view[1]))
		match String(view[2]):
			"aguila":
				cam.global_position = Vector3(0.0, 640.0, 260.0)
				cam.look_at(Vector3(0.0, 0.0, -40.0))
			"retrato":
				var citizens: Array[Node] = get_nodes_in_group(&"citizens")
				var subject: Node3D = citizens[0] as Node3D
				cam.global_position = subject.global_position + Vector3(1.6, 1.5, 2.4)
				cam.look_at(subject.global_position + Vector3(0.0, 1.0, 0.0))
			_:
				cam.global_position = camp.global_position + Vector3(10.0, 9.0, 16.0)
				cam.look_at(camp.global_position + Vector3(0.0, 1.0, 0.0))
		# Un segundo real: DayNight interpola la luz a la nueva hora
		for _f: int in 65:
			await process_frame
		var image: Image = root.get_viewport().get_texture().get_image()
		image.save_png("res://docs/screenshots/visual/%s_%s.png" % [view_name, tag])
		print("PROBE visual: %s_%s guardada" % [view_name, tag])
	quit(0)
