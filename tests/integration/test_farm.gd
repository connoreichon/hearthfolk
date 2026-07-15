extends HFTestCase
## Q2: el huerto produce comida sola y el invierno lo detiene.

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	GameState.add_resource(&"food", 30)
	# Despensa de leña llena: la auto-tala del campamento no interfiere
	GameState.add_resource(&"wood", 24)
	# Cultivo acelerado para la ventana del test (se restaura después)
	SimConfig.get_default().crop_stage_seconds = 6.0
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.3)
	SimClock.set_speed(4)


func after_each() -> void:
	SimConfig.get_default().crop_stage_seconds = 60.0
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_farm_cycle_produces_food() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	var nav_region: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	var field: FarmField = FarmField.place(nav_region, Rect2(6.0, 6.0, 4.0, 4.0))
	await _tree_scene.process_frame
	assert_eq(field.plot_count(), 9, "4×4 m → 9 parcelas de 1.25")
	assert_eq(field.count_by_state(FarmField.Plot.BARREN), 9)

	var food_start: int = GameState.get_resource(&"food")
	var harvested: bool = false
	# Ventana holgada: con los rasgos de S2 hay cuadrillas torpes con la
	# azada (work_factor <1) y la primera cosecha puede tardar más
	for _f: int in 6400:
		await _tree_scene.process_frame
		if GameState.get_resource(&"food") > food_start:
			harvested = true
			break
	assert_true(
		harvested, "una cosecha llegó al carro (comida %d)" % GameState.get_resource(&"food")
	)
	# El ciclo continúa: tras cosechar se replanta solo. OJO doble: (1) la
	# primera fase puede comerse la tarde y DE NOCHE nadie reclama tareas —
	# reloj a media tarde; (2) el acarreo de la cosecha (prioridad 4) ocupa
	# a la cuadrilla ANTES que plantar (5) — la ventana debe absorberlo.
	SimClock.time_of_day = minf(SimClock.time_of_day, 0.45)
	var replanted: bool = false
	for _f: int in 5000:
		await _tree_scene.process_frame
		if field.count_by_state(FarmField.Plot.BARREN) < 9:
			replanted = true
			break
	assert_true(replanted, "el huerto se replanta solo tras la cosecha")


func test_winter_freezes_growth() -> void:
	for _f: int in 10:
		await _tree_scene.process_frame
	var nav_region: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	var field: FarmField = FarmField.place(nav_region, Rect2(-10.0, 6.0, 4.0, 4.0))
	await _tree_scene.process_frame
	while SimClock.get_season() != SimClock.Season.WINTER:
		SimClock.advance_hours(24.0)
	# Plantar a mano una parcela y comprobar que no crece en invierno
	field.plots[0] = FarmField.Plot.PLANTED
	field.timers[0] = 0.0
	for _f: int in 240:
		await _tree_scene.process_frame
	assert_eq(int(field.plots[0]), int(FarmField.Plot.PLANTED), "en invierno nada crece")
	assert_almost_eq(field.timers[0], 0.0, 0.01, "el temporizador queda congelado")
