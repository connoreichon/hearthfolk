extends SceneTree
## Soak de puerta S7:  godot --headless --path . -s tests/soak/soak_s7.gd
## Un año con una banda de 8; verifica que la AUTOCONSTRUCCIÓN de casas y sus
## mejoras por niveles no meten atascos ni fuga de memoria, y que la aldea
## levanta ≥3 casas SOLA y alguna sube de nivel (docs/S7_DESIGN.md).

const YEAR_SIM: float = 8.0 * 480.0
const SAMPLE_MS: int = 5000

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
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
	game_state.call("add_resource", &"food", 60)
	print("soakS7: banda de 8, un año a ×4…")
	sim_clock.call("set_speed", 4)

	var last_pos: Dictionary = {}
	var stuck_streak: Dictionary = {}
	var mem_start: float = 0.0
	var max_tier: int = 0
	var next_ms: int = Time.get_ticks_msec()
	while float(sim_clock.get("elapsed_sim_seconds")) < YEAR_SIM:
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now < next_ms:
			continue
		next_ms = now + SAMPLE_MS
		if mem_start == 0.0:
			mem_start = Performance.get_monitor(Performance.MEMORY_STATIC)
		for node: Node in get_nodes_in_group(&"buildings"):
			var recipe: Resource = node.get("recipe") as Resource
			if recipe != null:
				max_tier = maxi(max_tier, int(recipe.get("tier")))
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
	if mem_start > 0.0 and absf(mem_end - mem_start) / mem_start > 0.12:
		_failures.append(
			"memoria inestable %.1f%%" % (absf(mem_end - mem_start) / mem_start * 100.0)
		)
	var houses: int = 0
	var tiers: Dictionary = {}
	for node: Node in get_nodes_in_group(&"buildings"):
		var recipe: Resource = node.get("recipe") as Resource
		if recipe != null and int(recipe.get("sleep_slots")) > 0:
			houses += 1
			var tname: String = str(recipe.get("display_name"))
			tiers[tname] = int(tiers.get(tname, 0)) + 1
	if houses < 3:
		_failures.append("solo %d casas autoconstruidas (se esperaban ≥3)" % houses)
	if max_tier < 2:
		_failures.append("ninguna casa subió de nivel (max_tier %d)" % max_tier)

	print("---")
	print(
		(
			"soakS7 FINAL: día %s | pob %d | casas %d %s | nivel máx %d | mem %.1f→%.1f MB"
			% [
				str(sim_clock.get("day")),
				get_nodes_in_group(&"citizens").size(),
				houses,
				str(tiers),
				max_tier,
				mem_start / 1048576.0,
				mem_end / 1048576.0,
			]
		)
	)
	for failure: String in _failures:
		printerr("SOAKS7 FALLO: " + failure)
	print("SOAKS7 RESULTADO: %s" % ("OK" if _failures.is_empty() else "FALLOS"))
	quit(0 if _failures.is_empty() else 1)
