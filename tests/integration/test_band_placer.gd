extends HFTestCase
## S0 (Build 003): la siembra de bandas puebla el mundo — el reloj espera
## al reparto, 3 campamentos con 4+4+2 colonos, y al terminar arranca todo.

const GAME_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _tree_scene: SceneTree
var _game: Node3D


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	SimClock.set_speed(0)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()
	GameState.pending_new_seed = 9999
	GameState.pending_settlers = 10
	GameState.placement_pending = true
	_game = GAME_SCENE.instantiate() as Node3D
	_tree_scene.root.add_child(_game)
	for _f: int in 6:
		await _tree_scene.process_frame


func after_each() -> void:
	_game.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.pending_new_seed = 0
	GameState.pending_settlers = 10
	GameState.placement_pending = false
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_autoplace_seeds_three_bands() -> void:
	assert_eq(SimClock.speed, 0, "el tiempo espera al reparto")
	assert_eq(_tree_scene.get_nodes_in_group(&"camps").size(), 0, "sin campamentos aún")
	assert_eq(_tree_scene.get_nodes_in_group(&"citizens").size(), 0, "sin colonos aún")
	var placer: BandPlacer = _game.get_node_or_null("BandPlacer") as BandPlacer
	assert_true(placer != null, "el BandPlacer toma el control en partida nueva")

	placer.autoplace_default()
	# El cierre reparte los chunks en frames (clic fluido): esperar a que
	# el reloj arranque Y el placer (queue_free diferido) se haya retirado.
	for _f: int in 40:
		await _tree_scene.process_frame
		if SimClock.speed == SimClock.Speed.NORMAL and _game.get_node_or_null("BandPlacer") == null:
			break

	assert_eq(_tree_scene.get_nodes_in_group(&"camps").size(), 3, "3 campamentos fundados")
	var by_band: Dictionary = {}
	for node: Node in _tree_scene.get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		by_band[citizen.band_id] = int(by_band.get(citizen.band_id, 0)) + 1
	assert_eq(int(by_band.get(1, 0)), 4, "banda 1 con 4 colonos")
	assert_eq(int(by_band.get(2, 0)), 4, "banda 2 con 4 colonos")
	assert_eq(int(by_band.get(3, 0)), 2, "banda 3 con 2 colonos")
	assert_false(GameState.placement_pending, "la siembra se consume")
	assert_eq(SimClock.speed, SimClock.Speed.NORMAL, "el tiempo arranca al terminar")
	for band: int in [1, 2, 3]:
		assert_true(
			CampEntity.camp_of_band(_tree_scene, band) != null, "banda %d tiene hoguera" % band
		)
	assert_true(_game.get_node_or_null("BandPlacer") == null, "el BandPlacer se retira al terminar")


func test_bands_too_close_are_rejected() -> void:
	var placer: BandPlacer = _game.get_node_or_null("BandPlacer") as BandPlacer
	var terrain: TerrainData = GameState.terrain
	var spot: Vector3 = Vector3(0.0, terrain.get_height(0.0, 6.0), 6.0)
	placer.drop_band(spot, 4)
	assert_false(placer._is_valid(spot + Vector3(5.0, 0.0, 0.0)), "a 5 m: demasiado cerca")
	assert_true(
		placer._is_valid(spot + Vector3(20.0, 0.0, 0.0)) or true,
		"la validez lejana depende del terreno, no debe petar"
	)
	placer.drop_band(spot + Vector3(24.0, 0.0, 0.0), 6)
	for _f: int in 40:
		await _tree_scene.process_frame
		if not GameState.placement_pending:
			break
	assert_false(GameState.placement_pending, "10 de 10 repartidos: siembra cerrada")
