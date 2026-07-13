extends HFTestCase
## §17.1 Necesidades: decaimiento correcto y umbrales que disparan estados.

var _citizen: Citizen
var _storage_stub: Node3D


func before_each() -> void:
	SimClock.set_speed(0)
	GameState.setup_new_game(555)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	_storage_stub = Node3D.new()
	_storage_stub.add_to_group(&"storage")
	tree.root.add_child(_storage_stub)
	_citizen = (load("res://scenes/citizens/citizen.tscn") as PackedScene).instantiate()
	_citizen.data = load("res://data/citizens/elian.tres")
	tree.root.add_child(_citizen)


func after_each() -> void:
	_citizen.free()
	_storage_stub.free()
	SimClock.set_speed(1)
	GameState.world_seed = 0
	EntityRegistry.clear()
	TaskBoard.clear()


func test_decay_rates_match_sim_config() -> void:
	var cfg: SimConfig = SimConfig.get_default()
	_citizen._decay_needs(60.0)
	assert_almost_eq(
		_citizen.hunger, 100.0 - cfg.hunger_per_sim_minute, 0.001, "hambre 1.4/min sim"
	)
	assert_almost_eq(
		_citizen.energy, 100.0 - cfg.energy_per_sim_minute_idle, 0.001, "energía idle 0.6/min"
	)


func test_rest_recovers_energy_and_freezes_decay() -> void:
	var cfg: SimConfig = SimConfig.get_default()
	_citizen.energy = 50.0
	_citizen.state_machine.change(&"Rest")
	_citizen._decay_needs(60.0)
	assert_almost_eq(_citizen.energy, 50.0, 0.001, "descansando la energía no decae")
	# La recuperación la aplica el propio estado Rest cuando ya duerme
	assert_almost_eq(cfg.energy_recovered_per_sim_minute_resting, 8.0, 0.001)


func test_hunger_threshold_triggers_eat() -> void:
	GameState.add_resource(&"food", 3)
	_citizen.hunger = SimConfig.get_default().hunger_threshold_eat - 1.0
	_citizen._check_interrupts()
	assert_eq(_citizen.state_machine.current_name(), &"Eat", "hambre < 25 interrumpe a Eat")


func test_energy_threshold_triggers_rest() -> void:
	_citizen.hunger = 100.0
	_citizen.energy = SimConfig.get_default().energy_threshold_rest - 1.0
	_citizen._check_interrupts()
	assert_eq(_citizen.state_machine.current_name(), &"Rest", "energía < 20 interrumpe a Rest")


func test_starving_slows_down_35_percent() -> void:
	_citizen.hunger = 9.0
	_citizen._decay_needs(0.05)
	assert_almost_eq(_citizen.speed_modifier, 0.65, 0.001, "famélico: −35 % de velocidad")
	_citizen.hunger = 50.0
	_citizen._decay_needs(0.05)
	assert_almost_eq(_citizen.speed_modifier, 1.0, 0.001)
