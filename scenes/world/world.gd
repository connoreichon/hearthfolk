extends Node3D
## Monta el mundo: mapa procedural por semilla, luz, entorno y navmesh.

const DEFAULT_SEED: int = 20260713
const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")

var terrain_data: TerrainData
var map_counts: Dictionary = {}

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	add_to_group(&"world")
	if GameState.pending_new_seed != 0:
		# Partida nueva pedida desde el menú
		TaskBoard.clear()
		EntityRegistry.clear()
		GameState.setup_new_game(GameState.pending_new_seed)
		GameState.pending_new_seed = 0
		GameState.add_resource(&"food", 12)
		GameState.add_resource(&"tools", 4)
	elif GameState.world_seed == 0:
		GameState.setup_new_game(DEFAULT_SEED)
		GameState.add_resource(&"food", 12)
		GameState.add_resource(&"tools", 4)
	var result: Dictionary = MapGenerator.generate(nav_region, GameState.derive_seed(["map"]))
	terrain_data = result["terrain"]
	map_counts = result["counts"]
	GameState.terrain = terrain_data
	_setup_light_and_environment()
	_bake_navmesh()
	_spawn_citizens()
	_setup_day_night()
	var dispatcher: HaulDispatcher = HaulDispatcher.new()
	dispatcher.name = "HaulDispatcher"
	add_child(dispatcher)
	var seasons: SeasonController = SeasonController.new()
	seasons.name = "SeasonController"
	add_child(seasons)
	var arrivals: SettlerArrivals = SettlerArrivals.new()
	arrivals.name = "SettlerArrivals"
	add_child(arrivals)
	# Las obras alteran la navegación: rehornear al empezar y al terminar
	EventBus.construction_started.connect(_on_construction_changed)
	EventBus.construction_completed.connect(_on_construction_changed)


func _on_construction_changed(_building_id: int) -> void:
	_bake_navmesh()


## Reconstrucción completa desde un guardado (§14): purga, regeneración
## determinista del mapa (mismos IDs de árboles) y recreación por ID.
func rebuild_from_save(data: Dictionary) -> void:
	TaskBoard.clear()
	for child: Node in nav_region.get_children():
		child.free()
	var old_citizens: Array[Node] = get_tree().get_nodes_in_group(&"citizens")
	for node: Node in old_citizens:
		node.free()
	var old_day_night: Node = get_node_or_null("DayNight")
	if old_day_night != null:
		old_day_night.free()
	EntityRegistry.clear()

	GameState.setup_new_game(int(data.get("seed", DEFAULT_SEED)))
	var inv: Dictionary = data.get("inventory", {})
	GameState.inventory = {
		&"wood": int(inv.get("wood", 0)),
		&"food": int(inv.get("food", 0)),
		&"tools": int(inv.get("tools", 0)),
	}
	SimClock.day = int(data.get("day", 1))
	SimClock.time_of_day = float(data.get("time_of_day", 0.25))
	SimClock.elapsed_sim_seconds = (
		float(SimClock.day - 1) * SimClock.DAY_LENGTH_SECONDS
		+ SimClock.time_of_day * SimClock.DAY_LENGTH_SECONDS
	)
	SimClock.set_speed(int(data.get("speed", 1)))

	var result: Dictionary = MapGenerator.generate(nav_region, GameState.derive_seed(["map"]))
	terrain_data = result["terrain"]
	map_counts = result["counts"]
	GameState.terrain = terrain_data
	_setup_day_night()

	var saved_trees: Dictionary = {}
	var others: Array = []
	for entry: Dictionary in data.get("entities", []):
		var kind: String = entry.get("kind", "")
		var entity_data: Dictionary = entry.get("data", {})
		if kind == "tree":
			saved_trees[int(entity_data.get("id", 0))] = entity_data
		else:
			others.append(entry)

	# Árboles: mismo orden de creación → mismos IDs; el que falta fue talado
	var matched: Dictionary = {}
	var regenerated: Array[Node] = get_tree().get_nodes_in_group(&"trees")
	for node: Node in regenerated:
		var tree: TreeEntity = node as TreeEntity
		if tree == null:
			continue
		if saved_trees.has(tree.entity_id):
			tree.load_data(saved_trees[tree.entity_id])
			matched[tree.entity_id] = true
		else:
			tree.free()
	# Brotes sembrados después de la generación del mapa (otoños pasados)
	for tree_id: int in saved_trees:
		if matched.has(tree_id):
			continue
		var d: Dictionary = saved_trees[tree_id]
		var extra: TreeEntity = TreeEntity.create(int(d.get("seed", 0)), bool(d.get("young", true)))
		extra.entity_id = tree_id
		EntityRegistry.register_with_id(extra, &"tree", tree_id)
		nav_region.add_child(extra)
		extra.load_data(d)

	for entry: Dictionary in others:
		_spawn_saved_entity(String(entry.get("kind", "")), entry.get("data", {}))

	# Regenerar tareas desde la realidad del mundo (nunca se persisten)
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree != null and tree.marked:
			TaskBoard.publish(&"chop", tree.entity_id, {}, 5)
	var dispatcher: HaulDispatcher = get_node_or_null("HaulDispatcher") as HaulDispatcher
	if dispatcher != null:
		dispatcher.rescan()
	_bake_navmesh()


func _spawn_saved_entity(kind: String, d: Dictionary) -> void:
	var entity_id: int = int(d.get("id", 0))
	match kind:
		"citizen":
			var citizen: Citizen = CITIZEN_SCENE.instantiate()
			citizen.data = SettlerGen.data_from_save(d)
			citizen.entity_id = entity_id
			EntityRegistry.register_with_id(citizen, &"citizen", entity_id)
			add_child(citizen)
			citizen.load_data(d)
			# Los estados ligados a tareas no se restauran: las tareas se
			# regeneran desde el mundo y FindTask las volverá a reclamar.
			var state: StringName = StringName(String(d.get("state", "Idle")))
			var restorable: Array[StringName] = [
				&"Idle", &"Wander", &"Eat", &"Rest", &"ReturnToSettlement"
			]
			if state in restorable and citizen.state_machine.states.has(state):
				citizen.state_machine.change(state)
		"resource":
			var item: ResourceItem = ResourceItem.create(
				StringName(String(d.get("type", "wood"))),
				int(d.get("amount", 2)),
				int(d.get("seed", 0))
			)
			item.entity_id = entity_id
			EntityRegistry.register_with_id(item, &"resource", entity_id)
			nav_region.add_child(item)
			item.load_data(d)
		"stump":
			var stump: StumpEntity = StumpEntity.create(int(d.get("seed", 0)))
			stump.entity_id = entity_id
			EntityRegistry.register_with_id(stump, &"stump", entity_id)
			nav_region.add_child(stump)
			stump.load_data(d)
		"zone":
			var zone: ZoneEntity = ZoneEntity.create(Rect2())
			zone.entity_id = entity_id
			EntityRegistry.register_with_id(zone, &"zone", entity_id)
			nav_region.add_child(zone)
			zone.load_data(d)
		"farm":
			var r: Array = d.get("rect", [0.0, 0.0, 4.0, 4.0])
			var farm_rect: Rect2 = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			var farm: FarmField = FarmField.place(nav_region, farm_rect, entity_id)
			farm.load_data(d)
		"construction_site":
			var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
			var site: ConstructionSite = ConstructionSite.place(
				nav_region,
				Vector3(float(pos[0]), float(pos[1]), float(pos[2])),
				float(d.get("rot_y", 0.0)),
				int(d.get("seed", 0)),
				entity_id,
				String(d.get("recipe", "res://data/buildings/cottage_a.tres"))
			)
			site.load_data(d)
		_:
			push_warning("World: tipo de entidad desconocido al cargar: %s" % kind)


func _setup_light_and_environment() -> void:
	var palette: PaletteData = PaletteData.get_default()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	_sun = sun
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color("#FFF4E0")
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "Env"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6E9BC4")
	sky_mat.sky_horizon_color = Color("#C9D6C2")
	sky_mat.ground_bottom_color = palette.dirt
	sky_mat.ground_horizon_color = Color("#C9D6C2")
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	_sky_mat = sky_mat
	_env = env
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.ssao_radius = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.15
	world_env.environment = env
	add_child(world_env)


func _bake_navmesh() -> void:
	var nav_mesh: NavigationMesh = NavigationMesh.new()
	# cell 0.3 = valor del mapa de navegación en project.godot (evita warnings)
	nav_mesh.agent_radius = 0.6
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.6
	nav_mesh.agent_max_slope = 42.0
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.3
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# terrain(1) | building(16) | prop_static(32). Los árboles NO se hornean:
	# usan NavigationObstacle3D dinámico y así talar no obliga a rehornear.
	nav_mesh.geometry_collision_mask = 49
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh(false)


## Cuatro habitantes en anillo de 3 m alrededor de la fogata (§4).
func _spawn_citizens() -> void:
	var names: Array[String] = ["elian", "mara", "tobin", "nessa"]
	for i: int in names.size():
		var citizen: Citizen = CITIZEN_SCENE.instantiate()
		citizen.data = load("res://data/citizens/%s.tres" % names[i])
		add_child(citizen)
		var ang: float = TAU * float(i) / float(names.size()) + 0.7
		var pos: Vector3 = Vector3(cos(ang) * 3.0, 0.0, sin(ang) * 3.0)
		pos.y = terrain_data.get_height(pos.x, pos.z) + 0.05
		citizen.global_position = pos
		citizen.visual.rotation.y = ang + PI * 0.5


func _setup_day_night() -> void:
	var day_night: DayNight = DayNight.new()
	day_night.name = "DayNight"
	day_night.sun = _sun
	day_night.environment = _env
	day_night.sky_material = _sky_mat
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		var fire: Node = fires[0]
		day_night.fire_light = fire.get_node_or_null("Campfire/FireLight") as OmniLight3D
		day_night.flame = fire.get_node_or_null("Campfire/Flame") as Node3D
		day_night.sparks = fire.get_node_or_null("Campfire/Sparks") as GPUParticles3D
	add_child(day_night)
