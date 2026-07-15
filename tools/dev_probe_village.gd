extends SceneTree
## Sonda S7: captura una aldea con casas de VARIOS NIVELES (choza/cabaña/
## piedra) autoconstruidas. godot --path . --resolution 1600x900 -s tools/dev_probe_village.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.set("pending_new_seed", 2024)
	game_state.set("pending_settlers", 8)
	game_state.set("placement_pending", true)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 10:
		await process_frame
	var placer: Node = main.get_node("BandPlacer")
	var spot: Vector3 = placer.call("_find_valid_near", Vector3(0.0, 0.0, 0.0), 12.0, 20)
	placer.call("drop_band", spot, 8)
	for _f: int in 10:
		await process_frame
	game_state.call("add_resource", &"food", 200)
	game_state.call("add_resource", &"wood", 40)
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 9000:
		await process_frame
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var tiers: Dictionary = {}
	for node: Node in get_nodes_in_group(&"buildings"):
		var recipe: Resource = node.get("recipe") as Resource
		if recipe != null and int(recipe.get("sleep_slots")) > 0:
			var tname: String = str(recipe.get("display_name"))
			tiers[tname] = int(tiers.get(tname, 0)) + 1
	print("PROBE aldea: casas=%s" % str(tiers))
	var cam: Camera3D = Camera3D.new()
	main.add_child(cam)
	cam.global_position = camp.global_position + Vector3(14.0, 20.0, 20.0)
	cam.look_at(camp.global_position + Vector3(4.0, 0.5, 4.0))
	cam.current = true
	for _f: int in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/s7_aldea.png")
	print("PROBE aldea: captura guardada")
	quit(0)
