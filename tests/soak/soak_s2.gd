extends SceneTree
## Soak de puerta S2:  godot --headless --path . -s tests/soak/soak_s2.gd
## UN AÑO de sim (8 días = 3840 s, ~16 min reales a ×4) con 3 bandas en el
## mapa gigante, manos fuera. Criterios de puerta (docs/S2_DESIGN.md §11):
## (a) flapping de oficios ≤1 cambio/colono/estación (sin contar el
##     estreno del oficio), (b) la madera fluye sin tocar T (nunca una
##     estación entera clavada a cero), (c) si la comida aprieta nace un
##     huerto solo, (d) sin atascos >15 s y tareas/memoria acotadas.

const YEAR_SIM_SECONDS: float = 8.0 * 480.0
const SAMPLE_MS: int = 5000
const STUCK_SAMPLES: int = 3
const ANCHORS: Array[Vector3] = [
	Vector3(-380.0, 0.0, -360.0), Vector3(390.0, 0.0, -340.0), Vector3(0.0, 0.0, 400.0)
]

var _failures: Array[String] = []
var _profession_changes: Dictionary = {}
var _debuts: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _on_profession_changed(citizen_id: int, _profession: StringName) -> void:
	if not _debuts.has(citizen_id):
		_debuts[citizen_id] = true
		return
	_profession_changes[citizen_id] = int(_profession_changes.get(citizen_id, 0)) + 1


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	var task_board: Node = root.get_node("/root/TaskBoard")
	var event_bus: Node = root.get_node("/root/EventBus")
	var soak_seed: int = 24681
	if OS.get_environment("HF_SOAK_SEED") != "":
		soak_seed = int(OS.get_environment("HF_SOAK_SEED"))
	game_state.set("pending_new_seed", soak_seed)
	game_state.set("pending_settlers", 10)
	game_state.set("placement_pending", true)
	event_bus.connect("profession_changed", _on_profession_changed)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 10:
		await process_frame
	var placer: Node = main.get_node_or_null("BandPlacer")
	if placer == null:
		printerr("SOAKS2 FALLO: no hay BandPlacer")
		quit(1)
		return
	var splits: Array[int] = [4, 4, 2]
	for i: int in ANCHORS.size():
		var spot: Vector3 = placer.call("_find_valid_near", ANCHORS[i], 12.0, 20)
		if spot == Vector3.INF:
			printerr("SOAKS2 FALLO: sin sitio válido cerca de %s" % ANCHORS[i])
			quit(1)
			return
		placer.call("drop_band", spot, splits[i])
	for _f: int in 10:
		await process_frame
	print("soakS2: %d aldeas sembradas. Un año de sim a ×4…" % get_nodes_in_group(&"camps").size())
	sim_clock.call("set_speed", 4)

	var next_sample_ms: int = Time.get_ticks_msec()
	var last_positions: Dictionary = {}
	var stuck_streaks: Dictionary = {}
	var memory_at_5min: float = 0.0
	var start_ms: int = Time.get_ticks_msec()
	var wood_seen_by_season: Dictionary = {}
	var food_crisis_seen: bool = false
	var last_season: int = -1

	while float(sim_clock.get("elapsed_sim_seconds")) < YEAR_SIM_SECONDS:
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now < next_sample_ms:
			continue
		next_sample_ms = now + SAMPLE_MS
		var elapsed_min: float = float(now - start_ms) / 60000.0
		var season: int = int(sim_clock.call("get_season"))
		if season != last_season:
			last_season = season
			print(
				(
					"soakS2 estación %d | día %s | pob %d | leña %s | comida %s | huertos %d"
					% [
						season,
						str(sim_clock.get("day")),
						get_nodes_in_group(&"citizens").size(),
						str(game_state.call("get_resource", &"wood")),
						str(game_state.call("get_resource", &"food")),
						get_nodes_in_group(&"farms").size(),
					]
				)
			)
		var wood: int = int(game_state.call("get_resource", &"wood"))
		if wood > 0:
			wood_seen_by_season[season] = true
		elif not wood_seen_by_season.has(season):
			wood_seen_by_season[season] = false
		var food: int = int(game_state.call("get_resource", &"food"))
		var population: int = get_nodes_in_group(&"citizens").size()
		if food < int((10.0 + 4.0 * float(population) / 3.0) * 0.6):
			food_crisis_seen = true
		for node: Node in get_nodes_in_group(&"citizens"):
			var citizen: Node3D = node as Node3D
			var cid: int = int(citizen.get("entity_id"))
			var pos: Vector3 = citizen.global_position
			if bool(citizen.call("is_moving")) and last_positions.has(cid):
				if pos.distance_to(last_positions[cid]) < 0.08:
					stuck_streaks[cid] = int(stuck_streaks.get(cid, 0)) + 1
					if int(stuck_streaks[cid]) >= STUCK_SAMPLES:
						_failures.append(
							(
								"habitante %d atascado >15 s en %s (min %.1f)"
								% [cid, str(pos), elapsed_min]
							)
						)
						stuck_streaks[cid] = 0
				else:
					stuck_streaks[cid] = 0
			else:
				stuck_streaks[cid] = 0
			last_positions[cid] = pos
		if memory_at_5min == 0.0 and elapsed_min >= 5.0:
			memory_at_5min = Performance.get_monitor(Performance.MEMORY_STATIC)
		var stats: Dictionary = task_board.call("stats")
		if int(stats["free"]) + int(stats["claimed"]) > 140:
			_failures.append(
				(
					"tareas desbocadas: %d (min %.1f)"
					% [int(stats["free"]) + int(stats["claimed"]), elapsed_min]
				)
			)

	# (a) Flapping: ≤1 cambio/colono/estación de media (4 estaciones)
	var population_end: int = get_nodes_in_group(&"citizens").size()
	var total_changes: int = 0
	for cid: int in _profession_changes:
		total_changes += int(_profession_changes[cid])
	var per_colonist_season: float = float(total_changes) / maxf(1.0, float(population_end)) / 4.0
	if per_colonist_season > 1.0:
		_failures.append(
			(
				"flapping de oficios: %.2f cambios/colono/estación (%d cambios)"
				% [per_colonist_season, total_changes]
			)
		)
	# (b) Madera sin tocar T: ninguna estación entera clavada a cero
	for season: int in wood_seen_by_season:
		if not bool(wood_seen_by_season[season]):
			_failures.append("estación %d entera con leña a cero" % season)
	# (c) Comida apretada → huerto autoconstruido
	if food_crisis_seen and get_nodes_in_group(&"farms").is_empty():
		_failures.append("hubo crisis de comida y ninguna aldea roturó huerto")
	var memory_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	if memory_at_5min > 0.0:
		var drift: float = absf(memory_end - memory_at_5min) / memory_at_5min
		if drift > 0.10:
			_failures.append("memoria inestable: %.1f%%" % (drift * 100.0))

	var trades: Dictionary = {}
	for node: Node in get_nodes_in_group(&"citizens"):
		var profession: String = str((node.get("data") as Resource).get("profession"))
		trades[profession] = int(trades.get(profession, 0)) + 1
	print("---")
	print(
		(
			"soakS2 FINAL: día %s | pob %d | oficios %s | cambios %d | huertos %d | mem %.1f→%.1f MB"
			% [
				str(sim_clock.get("day")),
				population_end,
				str(trades),
				total_changes,
				get_nodes_in_group(&"farms").size(),
				memory_at_5min / 1048576.0,
				memory_end / 1048576.0,
			]
		)
	)
	for failure: String in _failures:
		printerr("SOAKS2 FALLO: " + failure)
	print("SOAKS2 RESULTADO: %s" % ("OK" if _failures.is_empty() else "FALLOS"))
	quit(0 if _failures.is_empty() else 1)
