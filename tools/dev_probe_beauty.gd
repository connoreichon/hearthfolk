extends SceneTree
## Sonda visual: capturas del aspecto del juego (luz, ríos, aldea, águila).
## godot --path . --resolution 1600x900 -s tools/dev_probe_beauty.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", 4242)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 30:
		await process_frame
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var rig: Node3D = get_nodes_in_group(&"camera_rig")[0] as Node3D
	# Dejar vivir un poco la aldea para que haya movimiento
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 600:
		await process_frame
	sim_clock.call("set_speed", 1)
	# 1) Vista a pie de aldea
	rig.position = Vector3(
		camp.global_position.x + 6.0, rig.position.y, camp.global_position.z + 10.0
	)
	rig.call("set_zoom", 30.0)
	for _f: int in 30:
		await process_frame
	_shot("build003_aldea")
	await process_frame
	# 2) Vista media con el río
	rig.call("set_zoom", 90.0)
	for _f: int in 20:
		await process_frame
	_shot("build003_rio")
	await process_frame
	# 3) Vista de águila
	rig.call("set_overview", true)
	for _f: int in 40:
		await process_frame
	_shot("build003_aguila")
	await process_frame
	print("PROBE belleza: 3 capturas guardadas")
	quit(0)


func _shot(nombre: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png("res://docs/screenshots/%s.png" % nombre)
