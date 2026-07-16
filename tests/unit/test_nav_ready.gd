extends HFTestCase
## M0 (Build 004): las queries de navegación NUNCA se lanzan antes de la
## primera sincronización del mapa — rest_spot y compañía devuelven un
## fallback seguro sin escupir «query failed» en consola (el log limpio
## del runner es la otra mitad de esta verificación).

const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")

var _citizen: Citizen
var _fire_stub: Node3D


func before_each() -> void:
	GameState.setup_new_game(777)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	_fire_stub = Node3D.new()
	_fire_stub.add_to_group(&"campfire")
	tree.root.add_child(_fire_stub)
	_fire_stub.global_position = Vector3(4.0, 0.0, 4.0)
	_citizen = CITIZEN_SCENE.instantiate()
	_citizen.data = load("res://data/citizens/elian.tres")
	tree.root.add_child(_citizen)
	# SIN esperar frames: el mapa de navegación no ha sincronizado nunca


func after_each() -> void:
	_citizen.free()
	_fire_stub.free()
	GameState.world_seed = 0
	EntityRegistry.clear()
	TaskBoard.clear()


func test_rest_spot_in_frame_zero_returns_fallback() -> void:
	var map: RID = _citizen.get_world_3d().navigation_map
	# Premisa del test: en el frame 0 el mapa NO está sincronizado
	if NavUtil.map_ready(map):
		return  # otro test ya horneó este mapa: la premisa no aplica
	var spot: Vector3 = _citizen.rest_spot()
	assert_almost_eq(
		spot.distance_to(_fire_stub.global_position),
		2.3,
		0.01,
		"fallback seguro junto al fuego, sin query"
	)


func test_reachability_reports_false_before_sync() -> void:
	var map: RID = _citizen.get_world_3d().navigation_map
	if NavUtil.map_ready(map):
		return
	assert_false(
		NavUtil.is_reachable(_citizen.get_world_3d(), Vector3.ZERO, Vector3(5, 0, 5)),
		"sin mapa sincronizado no hay alcanzabilidad que afirmar"
	)
	assert_false(
		NavUtil.is_practical(_citizen.get_world_3d(), Vector3.ZERO, Vector3(5, 0, 5)),
		"ni practicidad"
	)


func test_move_to_near_falls_back_to_direct_target() -> void:
	var map: RID = _citizen.get_world_3d().navigation_map
	if NavUtil.map_ready(map):
		return
	_citizen.move_to_near(Vector3(10.0, 0.0, 10.0), 2.0)
	assert_true(_citizen.is_moving(), "se mueve hacia el objetivo directo sin query")
