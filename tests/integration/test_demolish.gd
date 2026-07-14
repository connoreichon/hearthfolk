extends HFTestCase
## Regresión del bug del QA humano: demoler dejaba tareas huérfanas en el
## tablón y el hueco no volvía a admitir construcción; las cabañas
## terminadas y los huertos ni siquiera se podían demoler.

const GAME_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _tree_scene: SceneTree
var _game: Node3D
var _tools: ToolManager
var _last_reason: String = ""


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	SimClock.set_speed(0)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()
	GameState.pending_new_seed = 4321
	_game = GAME_SCENE.instantiate() as Node3D
	_tree_scene.root.add_child(_game)
	for _f: int in 10:
		await _tree_scene.process_frame
	SimClock.set_speed(0)
	_tools = _game.get_node("ToolManager") as ToolManager


func after_each() -> void:
	_game.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.pending_new_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


## Despeja los árboles de un candidato (como haría el jugador talando)
## y devuelve el primer hueco que la validación oficial acepte.
func _find_valid_rect() -> Rect2:
	var world3d: World3D = _game.get_world_3d()
	var candidates: Array[Rect2] = [
		Rect2(4.0, 4.0, 7.0, 7.0),
		Rect2(-14.0, 4.0, 7.0, 7.0),
		Rect2(4.0, -14.0, 7.0, 7.0),
		Rect2(-14.0, -14.0, 7.0, 7.0),
		Rect2(10.0, 10.0, 7.0, 7.0),
		Rect2(-24.0, 0.0, 7.0, 7.0),
	]
	for candidate: Rect2 in candidates:
		var grown: Rect2 = candidate.grow(1.0)
		for node: Node in _tree_scene.get_nodes_in_group(&"trees"):
			var pos: Vector3 = (node as Node3D).global_position
			if grown.has_point(Vector2(pos.x, pos.z)):
				node.free()
		var verdict: Dictionary = _tools.validate_zone(candidate, world3d)
		if bool(verdict["valid"]):
			return candidate
		_last_reason = "%s -> %s" % [candidate, verdict["reason"]]
	return Rect2()


func _place_house(rect: Rect2) -> ConstructionSite:
	var world_root: Node3D = _game.get_node("World/NavigationRegion3D") as Node3D
	var zone: ZoneEntity = ZoneEntity.create(rect)
	world_root.add_child(zone)
	var center: Vector2 = rect.get_center()
	var at: Vector3 = Vector3(center.x, GameState.terrain.get_height(center.x, center.y), center.y)
	return ConstructionSite.place(world_root, at, 0.0, 24601)


func test_demolish_site_frees_spot_and_board() -> void:
	var rect: Rect2 = _find_valid_rect()
	assert_true(rect.size.x > 0.0, "hay un hueco válido en el mapa de prueba: " + _last_reason)
	var world3d: World3D = _game.get_world_3d()
	var site: ConstructionSite = _place_house(rect)
	var site_id: int = site.entity_id
	site._on_sim_tick(0.05)
	assert_true(
		TaskBoard.first_task_for_target(site_id) != null, "la obra publica tareas de suministro"
	)
	assert_false(bool(_tools.validate_zone(rect, world3d)["valid"]), "el hueco está ocupado")

	_tools.demolish_site(site)
	for _f: int in 3:
		await _tree_scene.process_frame
	assert_true(
		TaskBoard.first_task_for_target(site_id) == null,
		"cero tareas huérfanas tras demoler (el bug del probador)"
	)
	assert_true(
		bool(_tools.validate_zone(rect, world3d)["valid"]),
		"el mismo hueco vuelve a admitir construcción"
	)
	var again: ConstructionSite = _place_house(rect)
	assert_true(is_instance_valid(again), "se puede reconstruir en el mismo sitio")


func test_demolish_completed_house_refunds_half() -> void:
	var rect: Rect2 = _find_valid_rect()
	assert_true(rect.size.x > 0.0, "hay un hueco válido en el mapa de prueba: " + _last_reason)
	var site: ConstructionSite = _place_house(rect)
	site.debug_complete()
	assert_eq(_tree_scene.get_nodes_in_group(&"buildings").size(), 1, "cabaña terminada")
	var expected_refund: int = int(floor(site.recipe.total_wood_cost() * 0.5))
	var wood_before: int = GameState.get_resource(&"wood")

	_tools.demolish_site(site)
	for _f: int in 3:
		await _tree_scene.process_frame
	assert_eq(
		GameState.get_resource(&"wood"),
		wood_before + expected_refund,
		"la demolición devuelve la mitad de la madera"
	)
	assert_eq(_tree_scene.get_nodes_in_group(&"buildings").size(), 0, "la cabaña desaparece")
	assert_eq(_tree_scene.get_nodes_in_group(&"zones").size(), 0, "su zona se libera")
	assert_true(
		bool(_tools.validate_zone(rect, _game.get_world_3d())["valid"]),
		"el hueco de la cabaña demolida vuelve a ser válido"
	)


func test_demolish_farm_clears_tasks() -> void:
	var world_root: Node3D = _game.get_node("World/NavigationRegion3D") as Node3D
	var rect: Rect2 = _find_valid_rect()
	assert_true(rect.size.x > 0.0, "hay un hueco válido en el mapa de prueba: " + _last_reason)
	var farm: FarmField = FarmField.place(world_root, rect)
	var farm_id: int = farm.entity_id
	farm._on_sim_tick(0.05)
	assert_true(
		TaskBoard.first_task_for_target(farm_id) != null, "el huerto publica tareas de siembra"
	)

	_tools.demolish_farm(farm)
	for _f: int in 3:
		await _tree_scene.process_frame
	assert_true(
		TaskBoard.first_task_for_target(farm_id) == null, "cero tareas huérfanas del huerto"
	)
	assert_eq(_tree_scene.get_nodes_in_group(&"farms").size(), 0, "el huerto desaparece")
