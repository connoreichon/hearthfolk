extends HFTestCase
## Q4: la moral responde a compañía, fuego, techo e invierno, y escala
## la velocidad de trabajo entre 0.6 y 1.15.

const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")

var _citizen: Citizen
var _companion: Citizen
var _fire_stub: Node3D


func before_each() -> void:
	SimClock.set_speed(0)
	SimClock.reset(2, 0.4)
	GameState.setup_new_game(999)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	_fire_stub = Node3D.new()
	_fire_stub.add_to_group(&"campfire")
	tree.root.add_child(_fire_stub)
	_fire_stub.global_position = Vector3.ZERO
	_citizen = CITIZEN_SCENE.instantiate()
	_citizen.data = load("res://data/citizens/elian.tres")
	tree.root.add_child(_citizen)
	_companion = CITIZEN_SCENE.instantiate()
	_companion.data = load("res://data/citizens/mara.tres")
	tree.root.add_child(_companion)


func after_each() -> void:
	_citizen.free()
	_companion.free()
	_fire_stub.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	EntityRegistry.clear()
	TaskBoard.clear()


func test_company_raises_bond_and_solitude_lowers_it() -> void:
	_citizen.global_position = Vector3.ZERO
	_companion.global_position = Vector3(3.0, 0.0, 0.0)
	_citizen.bond = 50.0
	_citizen._update_morale_needs(60.0)
	assert_almost_eq(_citizen.bond, 52.5, 0.01, "compañía sube el vínculo")
	_companion.global_position = Vector3(50.0, 0.0, 0.0)
	_citizen._update_morale_needs(60.0)
	assert_almost_eq(_citizen.bond, 50.9, 0.01, "la soledad lo baja")


func test_night_far_from_fire_erodes_safety() -> void:
	SimClock.time_of_day = 0.85
	_citizen.global_position = Vector3(30.0, 0.0, 0.0)
	_citizen.safety = 50.0
	_citizen._update_morale_needs(60.0)
	assert_almost_eq(_citizen.safety, 46.0, 0.01, "noche a la intemperie: −4/min")
	SimClock.day = 7
	_citizen._update_morale_needs(60.0)
	assert_almost_eq(_citizen.safety, 38.0, 0.01, "en invierno el doble")
	_citizen.global_position = Vector3(2.0, 0.0, 0.0)
	_citizen._update_morale_needs(60.0)
	assert_almost_eq(_citizen.safety, 41.0, 0.01, "junto al fuego se recupera")


func test_sleeping_indoors_recovers_fast() -> void:
	SimClock.time_of_day = 0.85
	_citizen.sleeping_indoors = true
	_citizen.safety = 40.0
	_citizen._update_morale_needs(60.0)
	assert_almost_eq(_citizen.safety, 48.0, 0.01, "bajo techo: +8/min")


func test_morale_scales_work_speed() -> void:
	_citizen.safety = 100.0
	_citizen.bond = 100.0
	_citizen.hunger = 100.0
	_citizen.energy = 100.0
	assert_almost_eq(_citizen.morale(), 1.0, 0.001)
	assert_almost_eq(_citizen.effective_work_speed(), 1.15, 0.001, "moral alta: +15 %")
	_citizen.safety = 0.0
	_citizen.bond = 0.0
	_citizen.hunger = 10.0
	_citizen.energy = 10.0
	assert_almost_eq(_citizen.morale(), 0.0, 0.001)
	assert_almost_eq(_citizen.effective_work_speed(), 0.6, 0.001, "moral hundida: −40 %")
	assert_eq(_citizen.mood_text(), "Desanimado")
