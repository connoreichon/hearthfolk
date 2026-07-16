extends HFTestCase
## §14: guardar → cargar → guardar produce JSON semánticamente idéntico,
## y la carga con campos ausentes no revienta.

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(3333)
	GameState.add_resource(&"food", 9)
	GameState.add_resource(&"wood", 5)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(2, 0.4)
	SimClock.set_speed(4)


func after_each() -> void:
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_save_load_save_round_trip() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	# Estado interesante: árbol marcado, obra con material, madera en el suelo
	var tree: TreeEntity = null
	for node: Node in _tree_scene.get_nodes_in_group(&"trees"):
		var candidate: TreeEntity = node as TreeEntity
		if candidate != null and candidate.choppable():
			tree = candidate
			break
	tree.set_marked(true)
	var world_root: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	var site: ConstructionSite = ConstructionSite.place(
		world_root, Vector3(10.0, GameState.terrain.get_height(10.0, 10.0), 10.0), 0.0, 555
	)
	site.receive_material(&"wood", 3)
	var item: ResourceItem = ResourceItem.create(&"wood", 2, 42)
	world_root.add_child(item)
	item.global_position = Vector3(5.0, GameState.terrain.get_height(5.0, 5.0), 5.0)
	for _f: int in 60:
		await _tree_scene.process_frame

	# Estabilizar: pausa y habitantes en Idle. La carga vuelve al inventario
	# (stash, no drop): con los oficios de S2 un constructor puede estar en
	# pleno suministro con 2 maderas en las manos — devolverlas mantiene el
	# inventario determinista para el round-trip.
	SimClock.set_speed(0)
	for node: Node in _tree_scene.get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		citizen.stash_carry()
		citizen.abandon_task(&"yield")
		citizen.stop_moving()
		citizen.state_machine.change(&"Idle")
	await _tree_scene.process_frame

	var marked_id: int = tree.entity_id
	var first: Dictionary = SaveManager.capture()
	assert_true(SaveManager.write_save(first))
	assert_true(SaveManager.load_game(), "la carga debe funcionar")
	assert_eq(SimClock.speed, 0, "sigue en pausa justo tras cargar")
	var elapsed_after_load: float = SimClock.elapsed_sim_seconds
	for _f: int in 5:
		await _tree_scene.process_frame
	assert_eq(SimClock.speed, 0, "sigue en pausa tras 5 frames")
	assert_almost_eq(
		SimClock.elapsed_sim_seconds, elapsed_after_load, 0.001, "el reloj no avanzó en pausa"
	)

	# Estado restaurado
	assert_eq(GameState.get_resource(&"wood"), 5, "inventario restaurado")
	var restored_tree: TreeEntity = EntityRegistry.get_node_by_id(marked_id) as TreeEntity
	assert_true(restored_tree != null and restored_tree.marked, "árbol sigue marcado")
	assert_eq(EntityRegistry.all_of_kind(&"construction_site").size(), 1, "obra restaurada")
	var restored_site: ConstructionSite = (
		EntityRegistry.all_of_kind(&"construction_site")[0] as ConstructionSite
	)
	assert_eq(restored_site.delivered_total, 3, "material entregado restaurado")
	assert_eq(EntityRegistry.all_of_kind(&"resource").size(), 1, "item restaurado")
	assert_true(
		TaskBoard.first_task_for_target(marked_id, &"chop") != null,
		"tarea chop regenerada desde el mundo"
	)

	# Round-trip: segundo guardado semánticamente idéntico
	var second: Dictionary = SaveManager.capture()
	for key: String in ["seed", "day", "time_of_day", "speed", "inventory", "format_version"]:
		assert_eq(
			JSON.stringify(second.get(key)),
			JSON.stringify(first.get(key)),
			"campo «%s» idéntico" % key
		)
	# La cámara deriva (lerp del pivot al terreno, vivo incluso en pausa):
	# X/Z apenas se mueven; la Y PERSIGUE la altura del relieve bajo el
	# pivot y con montañas puede recorrer >1 m en los frames del test.
	# No es estado semántico: tolerancia ancha SOLO en Y.
	var cam_a: Array = first["camera"]["pos"]
	var cam_b: Array = second["camera"]["pos"]
	assert_almost_eq(float(cam_b[0]), float(cam_a[0]), 0.05, "cámara eje X")
	assert_almost_eq(float(cam_b[1]), float(cam_a[1]), 2.5, "cámara eje Y (persigue terreno)")
	assert_almost_eq(float(cam_b[2]), float(cam_a[2]), 0.05, "cámara eje Z")
	var ents_a: Array = first["entities"]
	var ents_b: Array = second["entities"]
	assert_eq(ents_b.size(), ents_a.size(), "mismo número de entidades")
	for i: int in mini(ents_a.size(), ents_b.size()):
		var json_a: String = JSON.stringify(ents_a[i])
		var json_b: String = JSON.stringify(ents_b[i])
		if json_a != json_b:
			var diff_at: int = -1
			for c: int in mini(json_a.length(), json_b.length()):
				if json_a[c] != json_b[c]:
					diff_at = c
					break
			var id_a: int = int((ents_a[i]["data"] as Dictionary).get("id", -1))
			var id_b: int = int((ents_b[i]["data"] as Dictionary).get("id", -1))
			assert_true(
				false,
				(
					"entidad %d (%s#%d vs %s#%d) difiere en el carácter %d: «%s» vs «%s»"
					% [
						i,
						String(ents_a[i]["kind"]),
						id_a,
						String(ents_b[i]["kind"]),
						id_b,
						diff_at,
						json_a.substr(maxi(0, diff_at - 30), 60),
						json_b.substr(maxi(0, diff_at - 30), 60)
					]
				)
			)


func test_migration_fills_missing_fields() -> void:
	var sparse: Dictionary = {"format_version": 2, "seed": 42}
	var migrated: Dictionary = SaveManager.migrate(sparse)
	assert_true(migrated.has("entities"), "entities por defecto")
	assert_true(migrated.has("inventory"), "inventory por defecto")
	assert_eq(int(migrated["format_version"]), SaveManager.FORMAT_VERSION)
