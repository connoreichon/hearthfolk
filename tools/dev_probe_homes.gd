extends SceneTree
## Sonda S7: ¿los aldeanos construyen y MEJORAN sus casas solos?
## godot --headless --path . -s tools/dev_probe_homes.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.set("pending_new_seed", 2024)
	game_state.set("pending_settlers", 8)
	game_state.set("placement_pending", true)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 10:
		await process_frame
	var placer: Node = main.get_node("BandPlacer")
	var spot: Vector3 = placer.call("_find_valid_near", Vector3(0.0, 0.0, 0.0), 12.0, 20)
	placer.call("drop_band", spot, 8)
	for _f: int in 10:
		await process_frame
	game_state.call("add_resource", &"food", 200)
	game_state.call("add_resource", &"wood", 40)
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	var report_at: Array[int] = [3000, 7000, 12000, 18000]
	var idx: int = 0
	var frame: int = 0
	while idx < report_at.size():
		await process_frame
		frame += 1
		if frame >= report_at[idx]:
			idx += 1
			_report(frame, game_state)
	quit(0)


func _report(frame: int, game_state: Node) -> void:
	var tiers: Dictionary = {}
	var building: int = 0
	for node: Node in get_nodes_in_group(&"construction_sites"):
		var site: Object = node
		if not bool(site.get("completed")):
			building += 1
	for node: Node in get_nodes_in_group(&"buildings"):
		var recipe: Resource = node.get("recipe") as Resource
		if recipe == null or int(recipe.get("sleep_slots")) <= 0:
			continue
		var tname: String = str(recipe.get("display_name"))
		tiers[tname] = int(tiers.get(tname, 0)) + 1
	print(
		(
			"PROBE f%d pob=%d leña=%s casas=%s enObra=%d"
			% [
				frame,
				get_nodes_in_group(&"citizens").size(),
				str(game_state.call("get_resource", &"wood")),
				str(tiers),
				building,
			]
		)
	)
