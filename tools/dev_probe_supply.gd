extends SceneTree
## Sonda: por qué falla el suministro de la obra (semilla 2222).
## godot --headless --path . -s tools/dev_probe_supply.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", 2222)
	game_state.call("add_resource", &"food", 12)
	game_state.call("add_resource", &"wood", 24)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 20:
		await process_frame
	var world_gen: RefCounted = game_state.get("world_gen")
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var pile: Node3D = get_nodes_in_group(&"storage")[0] as Node3D
	var fire: Node3D = get_nodes_in_group(&"campfire")[0] as Node3D
	var world_3d: World3D = (main as Node3D).get_world_3d()
	print("PROBE camp=%s" % camp.global_position)
	print(
		(
			"PROBE pile=%s river_mask=%.3f"
			% [
				pile.global_position,
				float(world_gen.call("river_mask", pile.global_position.x, pile.global_position.z))
			]
		)
	)
	print(
		(
			"PROBE fire→pile alcanzable=%s"
			% NavUtil.is_reachable(world_3d, fire.global_position, pile.global_position, 3.5)
		)
	)
	var terrain: RefCounted = game_state.get("terrain")
	print(
		(
			"PROBE pile terreno h=%.2f slope=%.1f"
			% [
				float(terrain.call("get_height", pile.global_position.x, pile.global_position.z)),
				float(
					terrain.call("get_slope_deg", pile.global_position.x, pile.global_position.z)
				),
			]
		)
	)
	# ¿Y la obra? Colocarla como el test y comprobar acceso pile→site
	var tools: Node = main.get_node("ToolManager")
	var at: Vector3 = Vector3.INF
	for gx: int in range(-20, 21, 4):
		for gz: int in range(-20, 21, 4):
			var rect: Rect2 = Rect2(
				fire.global_position.x + float(gx) - 4.0,
				fire.global_position.z + float(gz) - 4.0,
				8.0,
				8.0
			)
			if bool(tools.call("validate_zone", rect, world_3d)["valid"]):
				var center: Vector2 = rect.get_center()
				at = Vector3(
					center.x, float(terrain.call("get_height", center.x, center.y)), center.y
				)
				break
		if at != Vector3.INF:
			break
	print("PROBE site=%s" % at)
	print(
		(
			"PROBE pile→site alcanzable=%s"
			% NavUtil.is_reachable(world_3d, pile.global_position, at, 4.5)
		)
	)
	# Colocar la obra de verdad y dejar vivir el escenario un rato
	var site_script: GDScript = load("res://scripts/construction/construction_site.gd")
	var world_root: Node3D = main.get_node("World/NavigationRegion3D") as Node3D
	var site: Node = site_script.call("place", world_root, at, 0.0, 777)
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 2000:
		await process_frame
	print(
		(
			"PROBE tras 2000 frames: fase=%s entregado=%s"
			% [site.get("phase_index"), site.get("delivered_total")]
		)
	)
	var board: Node = root.get_node("/root/TaskBoard")
	print("PROBE tablon=%s" % str(board.call("stats")))
	var marked: int = 0
	for node: Node in get_nodes_in_group(&"trees"):
		if bool(node.get("marked")):
			marked += 1
	print("PROBE leña=%s marcados=%d" % [str(game_state.call("get_resource", &"wood")), marked])
	for node: Node in get_nodes_in_group(&"citizens"):
		var citizen: Node3D = node as Node3D
		var agent: NavigationAgent3D = citizen.get("nav_agent")
		var task: RefCounted = citizen.call("current_task")
		var task_desc: String = "sin tarea"
		if task != null:
			var target: Node = root.get_node("/root/EntityRegistry").call(
				"get_node_by_id", int(task.get("target_id"))
			)
			task_desc = (
				"%s→%s" % [str(task.get("kind")), str(target.name) if target != null else "MUERTO"]
			)
		print(
			(
				"PROBE %s estado=%s tarea=%s pos=(%.1f,%.1f) destino=(%.1f,%.1f) alcanzable=%s"
				% [
					str((citizen.get("data") as Resource).get("display_name")),
					str((citizen.get("state_machine") as Object).call("current_name")),
					task_desc,
					citizen.global_position.x,
					citizen.global_position.z,
					agent.target_position.x,
					agent.target_position.z,
					str(agent.is_target_reachable()),
				]
			)
		)
	# ¿SE PUEDE CRUZAR EL RÍO? Buscar el cauce cerca del campamento, un
	# punto en la orilla opuesta, y preguntar a la navegación.
	var center_river: Vector3 = Vector3.INF
	for radius: float in [20.0, 30.0, 45.0, 60.0, 80.0]:
		for step: int in 16:
			var ang: float = TAU * float(step) / 16.0
			var cx: float = camp.global_position.x + cos(ang) * radius
			var cz: float = camp.global_position.z + sin(ang) * radius
			if float(world_gen.call("river_mask", cx, cz)) > 0.9:
				center_river = Vector3(cx, 0.0, cz)
				break
		if center_river != Vector3.INF:
			break
	if center_river != Vector3.INF:
		var dir: Vector3 = (center_river - camp.global_position).normalized()
		var far_bank: Vector3 = center_river + dir * 30.0
		far_bank.y = float(terrain.call("get_height", far_bank.x, far_bank.z))
		print(
			(
				"PROBE cruce: cauce=%s orillaOpuesta=%s mask_opuesta=%.2f CRUZABLE=%s"
				% [
					center_river,
					far_bank,
					float(world_gen.call("river_mask", far_bank.x, far_bank.z)),
					str(NavUtil.is_reachable(world_3d, camp.global_position, far_bank, 4.0)),
				]
			)
		)
		var chunk_mgr: Node = main.get_node("World/ChunkManager")
		var chunk: Node = chunk_mgr.call("chunk_at", chunk_mgr.call("coord_of", center_river))
		if chunk != null:
			var blockers: Node = chunk.get_node_or_null("WaterBlockers")
			print(
				(
					"PROBE bloqueadores en chunk del cauce: %s"
					% (str(blockers.get_child_count()) if blockers != null else "NINGUNO")
				)
			)
	# Cámara encima del claro para ver el navmesh (con --debug-navigation)
	var rigs: Array[Node] = get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty():
		var rig: Node3D = rigs[0] as Node3D
		rig.position = Vector3(at.x, rig.position.y, at.z)
		rig.call("set_zoom", 26.0)
	for _f: int in 40:
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png("res://docs/screenshots/probe_supply.png")
	print("PROBE captura guardada")
	quit(0)
