extends SceneTree
## Sonda: captura de la PANTALLA DE SIEMBRA (la que veía el jugador azul).
## godot --path . --resolution 1152x648 -s tools/dev_probe_placement.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.set("pending_new_seed", 31337)
	game_state.set("pending_settlers", 10)
	game_state.set("placement_pending", true)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 90:
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	var err: int = image.save_png("res://docs/screenshots/s1_pantalla_siembra.png")
	print("PROBE captura siembra -> %s" % error_string(err))
	var placer: Node = main.get_node_or_null("BandPlacer")
	print("PROBE placer=%s chunks_visibles=parches_lejanos" % str(placer != null))
	quit(0)
