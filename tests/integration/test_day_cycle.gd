extends HFTestCase
## Integración P3: comer, descanso nocturno y fogata encendida.

var _main: Node
var _tree: SceneTree


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(1111)
	GameState.add_resource(&"food", 12)
	GameState.add_resource(&"tools", 4)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree.root.add_child(_main)
	SimClock.reset(1, 0.3)
	SimClock.set_speed(4)


func after_each() -> void:
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_hungry_citizen_eats_from_cart() -> void:
	for _f: int in 10:
		await _tree.process_frame
	var citizens: Array[Node] = _tree.get_nodes_in_group(&"citizens")
	assert_eq(citizens.size(), 4)
	var hungry: Citizen = citizens[0] as Citizen
	hungry.hunger = 20.0
	var food_before: int = GameState.get_resource(&"food")
	var ate: bool = false
	for _f: int in 700:
		await _tree.process_frame
		if hungry.hunger > 99.0:
			ate = true
			break
	assert_true(ate, "el habitante hambriento debe comer (hambre=%f)" % hungry.hunger)
	assert_eq(GameState.get_resource(&"food"), food_before - 1, "consumió 1 comida")


func test_night_sends_everyone_to_rest_and_fire_lights() -> void:
	for _f: int in 10:
		await _tree.process_frame
	SimClock.time_of_day = 0.76
	var resting: int = 0
	# 1400 (antes 900): desde el arranque «a puños» nadie pierde 7 s
	# tallando al inicio — al caer la noche del test alguno anda más lejos.
	for _f: int in 1400:
		await _tree.process_frame
		resting = 0
		for citizen: Node in _tree.get_nodes_in_group(&"citizens"):
			if (citizen as Citizen).state_machine.current_name() == &"Rest":
				resting += 1
		if resting == 4:
			break
	assert_eq(resting, 4, "de noche, los 4 habitantes acaban descansando")
	var fire: Node3D = _tree.get_nodes_in_group(&"campfire")[0] as Node3D
	var light: OmniLight3D = fire.get_node("Campfire/FireLight") as OmniLight3D
	assert_true(light.light_energy > 0.5, "la fogata se enciende de noche")


func test_pause_freezes_simulation_in_scene() -> void:
	for _f: int in 10:
		await _tree.process_frame
	SimClock.set_speed(0)
	var elapsed_before: float = SimClock.elapsed_sim_seconds
	var citizens: Array[Node] = _tree.get_nodes_in_group(&"citizens")
	var pos_before: Vector3 = (citizens[0] as Node3D).global_position
	for _f: int in 120:
		await _tree.process_frame
	assert_almost_eq(SimClock.elapsed_sim_seconds, elapsed_before, 0.001, "pausa congela el reloj")
	var pos_after: Vector3 = (citizens[0] as Node3D).global_position
	assert_true(pos_before.is_equal_approx(pos_after), "pausa congela el movimiento")
