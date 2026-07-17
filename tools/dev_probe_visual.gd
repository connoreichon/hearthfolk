extends SceneTree
## Sonda del SALTO VISUAL: 6 vistas fijas (amanecer, hora dorada, mediodía,
## noche, águila, primer plano) con la MISMA semilla y encuadres, para
## comparar antes/después al píxel.
##   godot --path . --resolution 1920x1080 -s tools/dev_probe_visual.gd -- --tag antes

const SEED: int = 4242
## Vistas: nombre → [time_of_day, tipo de encuadre, nieve 0-1]
const VIEWS: Array = [
	["amanecer", 0.09, "aldea", 0.0],
	["dorada", 0.62, "aldea", 0.0],
	["mediodia", 0.37, "aldea", 0.0],
	["noche", 0.85, "aldea", 0.0],
	["aguila", 0.55, "aguila", 0.0],
	["retrato", 0.60, "retrato", 0.0],
	# Invierno forzado: prueba de la NIEVE dinámica en copas/props/suelo
	["invierno", 0.40, "aldea", 1.0],
	["invierno_retrato", 0.55, "retrato", 1.0],
	# Biomas nuevos: la sonda los localiza escaneando el world_gen
	["playa", 0.38, "bioma:7", 0.0],
	["desierto", 0.40, "bioma:8", 0.0],
	["cordillera", 0.42, "bioma:5", 0.0],
]


## Corazón del bioma pedido: rejilla densa y puntuación por vecinos del
## mismo bioma (evita apuntar a un borde fino o a un falso positivo).
func _find_biome_spot(world_gen: WorldGen, target: int) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_score: int = -1
	var step: float = 12.0
	var half: float = world_gen.map_half - 10.0
	var x: float = -half
	while x < half:
		var z: float = -half
		while z < half:
			if world_gen.biome(x, z) == target:
				var h: float = world_gen.height(x, z)
				if h > WorldGen.WATER_LEVEL + 0.1:
					var score: int = 0
					for off: Vector2 in [
						Vector2(step, 0), Vector2(-step, 0),
						Vector2(0, step), Vector2(0, -step), Vector2(step, step),
					]:
						if world_gen.biome(x + off.x, z + off.y) == target:
							score += 1
					if score > best_score:
						best_score = score
						best = Vector3(x, h, z)
			z += step
		x += step
	return best


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
		var snow: float = float(view[3]) if view.size() > 3 else 0.0
		RenderingServer.global_shader_parameter_set(&"snow_amount", snow)
		var encuadre: String = String(view[2])
		if encuadre.begins_with("bioma:"):
			var target: int = int(encuadre.get_slice(":", 1))
			var world_gen: WorldGen = game_state.get("world_gen")
			print("PROBE bioma target=%d world_gen=%s" % [target, str(world_gen)])
			var spot: Vector3 = _find_biome_spot(world_gen, target)
			print("PROBE bioma spot=%s" % str(spot))
			# Activar los chunks de DETALLE alrededor del punto (palmeras,
			# cactus, abetos... solo brotan en chunks activos)
			var chunk_mgr: Node = root.find_child("ChunkManager", true, false)
			if chunk_mgr != null:
				chunk_mgr.call("ensure_active_around", spot)
			cam.global_position = spot + Vector3(14.0, 11.0, 20.0)
			cam.look_at(spot + Vector3(0.0, 1.5, 0.0))
			for _f: int in 90:
				await process_frame
		else:
			match encuadre:
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
