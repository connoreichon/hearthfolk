extends SceneTree
## Sonda: el ciclo del huerto del test Q2 con el paquete S2 puesto.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", 2222)
	game_state.call("add_resource", &"food", 30)
	game_state.call("add_resource", &"wood", 24)
	var cfg: Resource = load("res://data/config/sim_config.tres")
	cfg.set("crop_stage_seconds", 6.0)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("reset", 1, 0.3)
	sim_clock.call("set_speed", 4)
	for _f: int in 20:
		await process_frame
	var nav_region: Node3D = main.get_node("World/NavigationRegion3D") as Node3D
	var field_script: GDScript = load("res://scripts/construction/farm_field.gd")
	var field: Node = field_script.call("place", nav_region, Rect2(6.0, 6.0, 4.0, 4.0))
	await process_frame
	var board: Node = root.get_node("/root/TaskBoard")
	# FASE 1 — como el test: esperar a que la comida supere la inicial
	var food_start: int = int(game_state.call("get_resource", &"food"))
	var first_loop_frames: int = 0
	for _f: int in 6400:
		await process_frame
		first_loop_frames += 1
		if int(game_state.call("get_resource", &"food")) > food_start:
			break
	print(
		(
			"PROBE fase1 fin: f=%d sim=%.0fs hora=%.2f comida=%s"
			% [
				first_loop_frames,
				float(sim_clock.get("elapsed_sim_seconds")),
				float(sim_clock.get("time_of_day")),
				str(game_state.call("get_resource", &"food")),
			]
		)
	)
	# FASE 2 — reloj a media tarde y vigilar la replantación
	sim_clock.set("time_of_day", minf(float(sim_clock.get("time_of_day")), 0.45))
	for block: int in 9:
		for _f: int in 300:
			await process_frame
		var states: Dictionary = {}
		for node: Node in get_nodes_in_group(&"citizens"):
			var s: String = str((node.get("state_machine") as Object).call("current_name"))
			states[s] = int(states.get(s, 0)) + 1
		var kinds: Dictionary = {}
		var tasks: Dictionary = board.get("_tasks")
		for task_id: int in tasks:
			var task: RefCounted = tasks[task_id]
			var key: String = (
				"%s%s" % [str(task.get("kind")), "*" if int(task.get("claimed_by")) != -1 else ""]
			)
			kinds[key] = int(kinds.get(key, 0)) + 1
		print(
			(
				"PROBE fase2 f%d hora=%.2f noche=%s yermas=%s plantadas=%s tablon=%s estados=%s"
				% [
					(block + 1) * 300,
					float(sim_clock.get("time_of_day")),
					str(sim_clock.call("is_night")),
					str(field.call("count_by_state", 0)),
					str(field.call("count_by_state", 1)),
					str(kinds),
					str(states),
				]
			)
		)
		if int(field.call("count_by_state", 0)) < 9:
			print("PROBE REPLANTADO en el bloque %d" % (block + 1))
			break
	cfg.set("crop_stage_seconds", 60.0)
	quit(0)
