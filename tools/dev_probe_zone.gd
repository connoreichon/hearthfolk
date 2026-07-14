extends SceneTree
## Sonda: por qué la validación de zonas rechaza cada candidato.
## godot --headless --path . -s tools/dev_probe_zone.gd
## (duck-typing: los scripts -s no pueden referenciar clases del juego)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.set("pending_new_seed", 4321)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tools: Node = main.get_node("ToolManager")
	var world3d: World3D = (main as Node3D).get_world_3d()
	var candidate: Rect2 = Rect2(4.0, 4.0, 7.0, 7.0)
	for frame: int in 120:
		await process_frame
		if frame % 4 != 0:
			continue
		var grown: Rect2 = candidate.grow(1.0)
		for node: Node in get_nodes_in_group(&"trees"):
			var pos: Vector3 = (node as Node3D).global_position
			if grown.has_point(Vector2(pos.x, pos.z)):
				node.free()
		var verdict: Dictionary = tools.call("validate_zone", candidate, world3d)
		var map: RID = world3d.navigation_map
		var fire_pos: Vector3 = Vector3.ZERO
		var fires: Array[Node] = get_nodes_in_group(&"campfire")
		if not fires.is_empty():
			fire_pos = (fires[0] as Node3D).global_position
		var start: Vector3 = NavigationServer3D.map_get_closest_point(map, fire_pos)
		var terrain: RefCounted = root.get_node("/root/GameState").get("terrain")
		var center: Vector2 = candidate.get_center()
		var to: Vector3 = Vector3(
			center.x, float(terrain.call("get_height", center.x, center.y)), center.y
		)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, to, true)
		var end_str: String = "VACIO"
		if not path.is_empty():
			var end: Vector3 = path[path.size() - 1]
			end_str = "%s (dist %.2f)" % [end, Vector2(end.x, end.z).distance_to(center)]
		print(
			(
				"frame %d -> valido=%s | %s || fuego=%s snap=%s destino=%s camino[%d] fin=%s"
				% [
					frame,
					verdict["valid"],
					verdict["reason"],
					fire_pos,
					start,
					to,
					path.size(),
					end_str,
				]
			)
		)
		if bool(verdict["valid"]):
			break
	quit(0)
