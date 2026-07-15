extends SceneTree
## Sonda visual: colonos con su herramienta de oficio a la espalda.
## godot --path . --resolution 1280x720 -s tools/dev_probe_professions.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", 4242)
	game_state.call("add_resource", &"wood", 6)
	game_state.call("add_resource", &"food", 40)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 20:
		await process_frame
	# Dejar que el planificador reparta oficios y que trabajen un poco
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 900:
		await process_frame
	sim_clock.call("set_speed", 1)
	var trades: Dictionary = {}
	for node: Node in get_nodes_in_group(&"citizens"):
		var p: String = str((node.get("data") as Resource).get("profession"))
		trades[p] = int(trades.get(p, 0)) + 1
	print("PROBE oficios repartidos por la demanda: %s" % str(trades))
	# Escaparate: forzar los 4 oficios distintos, en fila y de espaldas a
	# la cámara para que se lea cada herramienta.
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var showcase: Array[StringName] = [&"lenador", &"agricultor", &"constructor", &"recolector"]
	var citizens: Array[Node] = get_nodes_in_group(&"citizens")
	for i: int in mini(citizens.size(), showcase.size()):
		var citizen: Node3D = citizens[i] as Node3D
		(citizen.get("data") as Resource).set("profession", showcase[i])
		(citizen.get("visual") as Object).call("set_profession", showcase[i])
		citizen.global_position = (camp.global_position + Vector3(-2.4 + float(i) * 1.6, 0.0, 2.2))
		citizen.call("stop_moving")
		var visual: Node3D = citizen.get("visual") as Node3D
		visual.rotation.y = PI  # de espaldas a la cámara del sur
		(citizen.get("state_machine") as Object).call("change", &"Idle")
	# Cámara de escaparate independiente (el SpringArm del rig recoloca su
	# cámara cada frame): baja y casi horizontal para leer las herramientas.
	var cam: Camera3D = Camera3D.new()
	main.add_child(cam)
	cam.global_position = camp.global_position + Vector3(0.2, 1.4, 6.4)
	cam.look_at(camp.global_position + Vector3(-0.4, 1.05, 2.2))
	cam.current = true
	for _f: int in 60:
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png("res://docs/screenshots/s2_oficios.png")
	print("PROBE captura de oficios guardada")
	quit(0)
