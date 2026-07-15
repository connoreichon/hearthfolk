extends SceneTree
## Sonda S3: ¿se dibujan las sendas de tráfico? Estampa una ruta a mano
## (verifica el shader) y deja vivir la aldea un rato (verifica el gancho),
## luego captura cenital sobre el campamento.
## godot --path . --resolution 1280x720 -s tools/dev_probe_paths.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", 4242)
	game_state.call("add_resource", &"food", 40)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 30:
		await process_frame
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var traffic: Node = root.get_node("/root/TrafficGrid")
	# Dos rutas pisadas a mano ~100 pasadas (una senda de pocos días, no un
	# claro): verifica que la textura se vuelve una senda FINA de tierra.
	var routes: Array[Vector3] = [
		camp.global_position + Vector3(20.0, 0.0, 6.0),
		camp.global_position + Vector3(-4.0, 0.0, 22.0),
	]
	for dest: Vector3 in routes:
		var steps: int = int(camp.global_position.distance_to(dest))
		for _rep: int in 100:
			for t: int in steps + 1:
				traffic.call("stamp", camp.global_position.lerp(dest, float(t) / float(steps)))
	# Y que vivan: los colonos añaden sus propias huellas
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 1200:
		await process_frame
	# Cámara cenital sobre el campamento
	var cam: Camera3D = Camera3D.new()
	main.add_child(cam)
	cam.global_position = camp.global_position + Vector3(6.0, 34.0, 6.0)
	cam.look_at(camp.global_position + Vector3(6.0, 0.0, 2.0))
	cam.current = true
	for _f: int in 40:
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png("res://docs/screenshots/s3_sendas.png")
	print("PROBE sendas: captura guardada")
	quit(0)
