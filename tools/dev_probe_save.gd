extends SceneTree
## Sonda: primer par de entidades divergente en el round-trip de guardado.
## godot --headless --path . -s tools/dev_probe_save.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	# Simular la contaminación de la suite: un menú (con su mundo de fondo)
	# vive y muere antes del test, como hacen test_menu_ui/test_menu_flow.
	var registry: Node = root.get_node("/root/EntityRegistry")
	var board: Node = root.get_node("/root/TaskBoard")
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	for _f: int in 8:
		await process_frame
	menu.free()
	registry.call("clear")
	board.call("clear")
	game_state.set("world_seed", 0)
	game_state.set("terrain", null)
	game_state.call("setup_new_game", 3333)
	game_state.call("add_resource", &"food", 9)
	game_state.call("add_resource", &"wood", 5)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 2, 0.4)
	sim_clock.call("set_speed", 4)
	for _f: int in 20:
		await process_frame
	# Réplica del test: árbol marcado + obra con material + madera suelta
	var tree: Node = null
	for node: Node in get_nodes_in_group(&"trees"):
		if bool(node.call("choppable")):
			tree = node
			break
	tree.call("set_marked", true)
	var world_root: Node3D = main.get_node("World/NavigationRegion3D") as Node3D
	var terrain: RefCounted = game_state.get("terrain")
	var site_script: GDScript = load("res://scripts/construction/construction_site.gd")
	var site: Node = site_script.call(
		"place",
		world_root,
		Vector3(10.0, float(terrain.call("get_height", 10.0, 10.0)), 10.0),
		0.0,
		555
	)
	site.call("receive_material", &"wood", 3)
	var item_script: GDScript = load("res://scripts/resources/resource_item.gd")
	var item: Node3D = item_script.call("create", &"wood", 2, 42)
	world_root.add_child(item)
	item.global_position = Vector3(5.0, float(terrain.call("get_height", 5.0, 5.0)), 5.0)
	for _f: int in 60:
		await process_frame
	sim_clock.call("set_speed", 0)
	for node: Node in get_nodes_in_group(&"citizens"):
		node.call("drop_carry", false)
		node.call("abandon_task", &"yield")
		node.call("stop_moving")
		(node.get("state_machine") as Object).call("change", &"Idle")
	await process_frame
	var marked_id: int = int(tree.get("entity_id"))
	var save_manager: Node = root.get_node("/root/SaveManager")
	var first: Dictionary = save_manager.call("capture")
	save_manager.call("write_save", first)
	save_manager.call("load_game")
	for _f: int in 5:
		await process_frame
	var restored: Node = registry.call("get_node_by_id", marked_id)
	print(
		(
			"PROBE marcado tras carga: %s (nodo %s)"
			% [str(restored.get("marked")) if restored != null else "NULO", str(restored)]
		)
	)
	var second: Dictionary = save_manager.call("capture")
	var ents_a: Array = first["entities"]
	var ents_b: Array = second["entities"]
	print("PROBE tamaños: %d vs %d" % [ents_a.size(), ents_b.size()])
	var shown: int = 0
	for i: int in mini(ents_a.size(), ents_b.size()):
		var a: String = JSON.stringify(ents_a[i])
		var b: String = JSON.stringify(ents_b[i])
		if a != b and shown < 3:
			shown += 1
			print("PROBE i=%d" % i)
			print("PROBE A=%s" % a)
			print("PROBE B=%s" % b)
	quit(0)
