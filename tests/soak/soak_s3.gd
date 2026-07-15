extends SceneTree
## Soak de puerta S3 (RENDERIZADO para capturar):
##   godot --path . --resolution 1280x720 -s tests/soak/soak_s3.gd
## Medio año con 1 banda; verifica que TrafficGrid no mete atascos ni fuga
## de memoria, y CAPTURA las sendas orgánicas del campamento al final
## (docs/S3_DESIGN.md: rutas diarias visibles como tierra pisada).

const HALF_YEAR_SIM: float = 4.0 * 480.0
const SAMPLE_MS: int = 5000

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	game_state.set("pending_new_seed", 4242)
	game_state.set("pending_settlers", 6)
	game_state.set("placement_pending", true)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 10:
		await process_frame
	var placer: Node = main.get_node("BandPlacer")
	var spot: Vector3 = placer.call("_find_valid_near", Vector3(0.0, 0.0, 0.0), 12.0, 20)
	placer.call("drop_band", spot, 6)
	for _f: int in 10:
		await process_frame
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	print("soakS3: banda en %s, medio año a ×4…" % camp.global_position)
	sim_clock.call("set_speed", 4)

	var last_pos: Dictionary = {}
	var stuck_streak: Dictionary = {}
	var mem_start: float = 0.0
	var next_ms: int = Time.get_ticks_msec()
	while float(sim_clock.get("elapsed_sim_seconds")) < HALF_YEAR_SIM:
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now < next_ms:
			continue
		next_ms = now + SAMPLE_MS
		if mem_start == 0.0:
			mem_start = Performance.get_monitor(Performance.MEMORY_STATIC)
		for node: Node in get_nodes_in_group(&"citizens"):
			var c: Node3D = node as Node3D
			var cid: int = int(c.get("entity_id"))
			if bool(c.call("is_moving")) and last_pos.has(cid):
				if c.global_position.distance_to(last_pos[cid]) < 0.08:
					stuck_streak[cid] = int(stuck_streak.get(cid, 0)) + 1
					if int(stuck_streak[cid]) >= 3:
						_failures.append("habitante %d atascado" % cid)
						stuck_streak[cid] = 0
				else:
					stuck_streak[cid] = 0
			else:
				stuck_streak[cid] = 0
			last_pos[cid] = c.global_position
	var mem_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	if mem_start > 0.0 and absf(mem_end - mem_start) / mem_start > 0.10:
		_failures.append(
			"memoria inestable %.1f%%" % (absf(mem_end - mem_start) / mem_start * 100.0)
		)

	# Captura cenital de las sendas emergentes del campamento
	var cam: Camera3D = Camera3D.new()
	main.add_child(cam)
	cam.global_position = (camp as Node3D).global_position + Vector3(4.0, 40.0, 4.0)
	cam.look_at((camp as Node3D).global_position)
	cam.current = true
	for _f: int in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/s3_sendas.png")

	print(
		(
			"soakS3 FINAL: día %s | pob %d | mem %.1f→%.1f MB"
			% [
				str(sim_clock.get("day")),
				get_nodes_in_group(&"citizens").size(),
				mem_start / 1048576.0,
				mem_end / 1048576.0,
			]
		)
	)
	for failure: String in _failures:
		printerr("SOAKS3 FALLO: " + failure)
	print("SOAKS3 RESULTADO: %s" % ("OK" if _failures.is_empty() else "FALLOS"))
	quit(0 if _failures.is_empty() else 1)
