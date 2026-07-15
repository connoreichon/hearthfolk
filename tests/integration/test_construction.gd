extends HFTestCase
## Integración P6: obra completa de principio a fin sin intervención.

var _main: Node
var _tree_scene: SceneTree
var _phases_seen: Array[int] = []
var _completed_id: int = -1


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	# Comida holgada: el hambre ralentiza el trabajo un 35 % y colaba la
	# recta final de la obra fuera de la ventana del test
	GameState.add_resource(&"food", 30)
	# 36 = despensa llena INCLUSO tras consumir la obra sus 12 (si baja de
	# 24 a mitad de test, la auto-tala despierta y roba obreros)
	GameState.add_resource(&"wood", 36)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.2)
	SimClock.set_speed(4)
	_phases_seen = []
	_completed_id = -1
	EventBus.construction_phase_advanced.connect(_on_phase)
	EventBus.construction_completed.connect(_on_completed)


func after_each() -> void:
	EventBus.construction_phase_advanced.disconnect(_on_phase)
	EventBus.construction_completed.disconnect(_on_completed)
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func _on_phase(_id: int, phase: int) -> void:
	_phases_seen.append(phase)


func _on_completed(building_id: int) -> void:
	_completed_id = building_id


func test_cottage_builds_through_all_phases() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	var world_root: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	# La obra se planta en un hueco VÁLIDO cerca del campamento (el mundo
	# gigante ya no gira alrededor del origen).
	var tool_manager: ToolManager = _main.get_node("ToolManager") as ToolManager
	var fire_pos: Vector3 = (
		(_tree_scene.get_nodes_in_group(&"campfire")[0] as Node3D).global_position
	)
	var at: Vector3 = Vector3.INF
	for gx: int in range(-20, 21, 4):
		for gz: int in range(-20, 21, 4):
			var rect: Rect2 = Rect2(
				fire_pos.x + float(gx) - 4.0, fire_pos.z + float(gz) - 4.0, 8.0, 8.0
			)
			if bool(tool_manager.validate_zone(rect, (_main as Node3D).get_world_3d())["valid"]):
				var center: Vector2 = rect.get_center()
				at = Vector3(center.x, GameState.terrain.get_height(center.x, center.y), center.y)
				break
		if at != Vector3.INF:
			break
	assert_true(at != Vector3.INF, "hay hueco válido para la obra cerca del campamento")
	var site: ConstructionSite = ConstructionSite.place(world_root, at, 0.0, 777)
	assert_eq(site.recipe.total_wood_cost(), 12, "la cabaña cuesta 12 de madera")

	# Ventana con margen: el test más largo de la suite roza el límite bajo
	# carga (mismo remedio que test_haul_flow); el DBG de abajo hace la
	# autopsia si aun así se agota.
	for _f: int in 9500:
		await _tree_scene.process_frame
		if _completed_id != -1:
			break
	if _completed_id == -1:
		var states: Array[String] = []
		for node: Node in _tree_scene.get_nodes_in_group(&"citizens"):
			var c: Citizen = node as Citizen
			(
				states
				. append(
					(
						"%s:%s@%.1f,%.1f"
						% [
							c.data.display_name,
							c.state_machine.current_name(),
							c.global_position.x,
							c.global_position.z,
						]
					)
				)
			)
		print(
			(
				"DBG-CONSTR fase=%d entregado=%d parada=%s tareas=%s madera=%d colonos=%s"
				% [
					site.phase_index,
					site.delivered_total,
					str(site.stalled),
					str(TaskBoard.stats()),
					GameState.get_resource(&"wood"),
					" | ".join(states),
				]
			)
		)
	assert_eq(_completed_id, site.entity_id, "la cabaña se completa sola")
	assert_true(site.completed)
	for phase: int in [1, 2, 3, 4]:
		assert_true(phase in _phases_seen, "pasó por la fase %d" % phase)
	# Espera de asentamiento: un porteador puede ir aún de camino con 2
	# maderas cuando suena la señal de obra terminada; al llegar, el carro
	# rechaza el excedente y lo devuelve al inventario (conservación S2)
	for _f: int in 1200:
		await _tree_scene.process_frame
		if GameState.get_resource(&"wood") == 24:
			break
	assert_eq(GameState.get_resource(&"wood"), 24, "las 12 maderas de la obra se consumieron")
	assert_true(site.is_in_group(&"buildings"), "la obra terminada es un edificio")
	var visible_pieces: int = 0
	var cottage: Node3D = site.get_node("Cottage") as Node3D
	for child: Node in cottage.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			visible_pieces += 1
	assert_true(visible_pieces >= 30, "todas las piezas visibles (%d)" % visible_pieces)


func test_zone_validation_rules() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	var tool_manager: ToolManager = _main.get_node("ToolManager") as ToolManager
	var world: World3D = (_main as Node3D).get_world_3d()

	var too_small: Dictionary = tool_manager.validate_zone(Rect2(6.0, 6.0, 4.0, 4.0), world)
	assert_false(too_small["valid"])
	assert_true("pequeña" in String(too_small["reason"]))

	var outside: Dictionary = tool_manager.validate_zone(Rect2(600.0, 600.0, 8.0, 8.0), world)
	assert_false(outside["valid"], "fuera del mapa inválida")

	# Buscar un tramo de río real del mundo gigante para el caso «agua»
	var river_spot: Vector2 = Vector2.INF
	for gx: int in range(-256, 257, 16):
		for gz: int in range(-256, 257, 16):
			if GameState.world_gen.river_mask(float(gx), float(gz)) > 0.6:
				river_spot = Vector2(float(gx), float(gz))
				break
		if river_spot != Vector2.INF:
			break
	if river_spot != Vector2.INF:
		var on_water: Dictionary = tool_manager.validate_zone(
			Rect2(river_spot.x - 4.0, river_spot.y - 4.0, 8.0, 8.0), world
		)
		assert_false(on_water["valid"], "sobre el río inválida")

	var fire_pos: Vector3 = (
		(_tree_scene.get_nodes_in_group(&"campfire")[0] as Node3D).global_position
	)
	var over_fire: Dictionary = tool_manager.validate_zone(
		Rect2(fire_pos.x - 4.0, fire_pos.z - 4.0, 8.0, 8.0), world
	)
	assert_false(over_fire["valid"], "sobre la fogata inválida")
	assert_true(
		"obstáculos" in String(over_fire["reason"]) or "agua" in String(over_fire["reason"]),
		"la razón es obstáculo o agua vecina (fue: %s)" % over_fire["reason"]
	)

	# Zona limpia: buscar un hueco real cerca del campamento (mapa gigante:
	# la posición fija de antes puede caer en río o bosque según semilla)
	var good_rect: Rect2 = Rect2()
	for gx: int in range(-24, 25, 4):
		for gz: int in range(-24, 25, 4):
			var candidate: Rect2 = Rect2(float(gx), float(gz), 8.0, 8.0)
			var verdict: Dictionary = tool_manager.validate_zone(candidate, world)
			if bool(verdict["valid"]):
				good_rect = candidate
				break
		if good_rect.size.x > 0.0:
			break
	assert_true(good_rect.size.x > 0.0, "existe una zona limpia válida cerca del campamento")
