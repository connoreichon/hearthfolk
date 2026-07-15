class_name WorldRoot
extends Node3D
## Monta el mundo: mapa procedural por semilla, luz, entorno y navmesh.

const DEFAULT_SEED: int = 20260713
const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")

var terrain_data: TerrainData
var map_counts: Dictionary = {}

var _chunks: ChunkManager
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
		# El menú deja su propio reloj (atardecer, pausado tras la
		# transición): la partida nueva empieza de mañana. Si hay siembra
		# de bandas pendiente, el tiempo espera a que el jugador reparta.
		SimClock.reset(1, 0.25)
		if GameState.placement_pending:
			SimClock.set_speed(SimClock.Speed.PAUSED)
		else:
			SimClock.set_speed(SimClock.Speed.NORMAL)
	elif GameState.world_seed == 0:
		GameState.setup_new_game(DEFAULT_SEED)
		GameState.add_resource(&"food", 12)
		GameState.add_resource(&"tools", 4)
	_setup_world_gen()
	_setup_light_and_environment()
	if GameState.placement_pending:
		# Siembra de bandas: el BandPlacer fundará campamentos y colonos;
		# el navmesh se hornea UNA vez al terminar la colocación.
		pass
	else:
		# Modo automático (tests, soaks, guardados viejos): un campamento
		# central de la banda 0, esquivando ríos y cuestas del mundo gigante.
		var home: Vector3 = _auto_camp_spot()
		found_camp(home, 0)
		_bake_navmesh()
		_spawn_citizens(home)
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
	var milestones: Milestones = Milestones.new()
	milestones.name = "Milestones"
	add_child(milestones)
	var events: WorldEvents = WorldEvents.new()
	events.name = "WorldEvents"
	add_child(events)
	# Las obras alteran la navegación: rehornear al empezar y al terminar
	EventBus.construction_started.connect(_on_construction_changed)
	EventBus.construction_completed.connect(_on_construction_changed)
	EventBus.construction_cancelled.connect(_on_construction_changed)


func _on_construction_changed(_building_id: int) -> void:
	_bake_navmesh()


## Primer sitio de campamento razonable cerca del centro: dentro del mapa,
## seco y llano (el (0,0) a pelo puede caer en un río del mundo gigante).
func _auto_camp_spot() -> Vector3:
	var world_gen: WorldGen = GameState.world_gen
	for ring: int in 9:
		for step: int in 8:
			var ang: float = TAU * float(step) / 8.0 + float(ring) * 0.4
			var x: float = cos(ang) * float(ring) * 6.0
			var z: float = sin(ang) * float(ring) * 6.0
			if not world_gen.is_inside(x, z, 3.0):
				continue
			if world_gen.river_mask(x, z) > 0.18:
				continue
			if terrain_data.get_slope_deg(x, z) > 18.0:
				continue
			return Vector3(x, 0.0, z)
	return Vector3.ZERO


## Mundo gigante (S1): WorldGen como fuente de verdad, fachada TerrainData,
## gestor de chunks y el plano de agua. Los chunks nacen con los campamentos.
func _setup_world_gen() -> void:
	var world_gen: WorldGen = WorldGen.new(GameState.derive_seed(["map"]))
	GameState.world_gen = world_gen
	terrain_data = TerrainData.new(world_gen)
	GameState.terrain = terrain_data
	map_counts = {}
	var far: FarTerrain = FarTerrain.create(world_gen)
	add_child(far)
	_chunks = ChunkManager.new()
	_chunks.name = "ChunkManager"
	_chunks.world_gen = world_gen
	_chunks.nav_parent = nav_region
	_chunks.far_terrain = far
	add_child(_chunks)
	MapGenerator.spawn_water(self, world_gen)


## Funda el campamento de una banda: activa el suelo bajo sus pies
## (chunks), DESPEJA EL CLARO (la banda tala su campamento al asentarse)
## y planta hoguera + almacén pegados al terreno.
func found_camp(center: Vector3, band: int) -> CampEntity:
	_chunks.ensure_active_around(center)
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: Node3D = node as Node3D
		if tree != null and tree.global_position.distance_to(center) < 7.0:
			tree.free()
	var camp: CampEntity = CampEntity.create(band, GameState.derive_seed(["camp", band]))
	camp.position = Vector3(center.x, terrain_data.get_height(center.x, center.z) - 0.02, center.z)
	nav_region.add_child(camp)
	var pile: StaticBody3D = camp.storage_body()
	var pile_global: Vector3 = pile.global_position
	pile.global_position.y = terrain_data.get_height(pile_global.x, pile_global.z)
	return camp


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
	if _chunks != null:
		_chunks.free()
		_chunks = null
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

	_setup_world_gen()
	_setup_day_night()

	var saved_trees: Dictionary = {}
	var camps_data: Array = []
	var others: Array = []
	for entry: Dictionary in data.get("entities", []):
		var kind: String = entry.get("kind", "")
		var entity_data: Dictionary = entry.get("data", {})
		if kind == "tree":
			saved_trees[int(entity_data.get("id", 0))] = entity_data
		elif kind == "camp":
			camps_data.append(entity_data)
		else:
			others.append(entry)

	# Los campamentos van PRIMERO: activan sus chunks, y con ellos nacen
	# los árboles deterministas que el matching de abajo necesita.
	for camp_entry: Dictionary in camps_data:
		_spawn_saved_entity("camp", camp_entry)
	if camps_data.is_empty():
		found_camp(Vector3.ZERO, 0)

	# Árboles: ID determinista por chunk → mismos IDs; el que falta fue talado
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
		"camp":
			var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
			_chunks.ensure_active_around(Vector3(float(pos[0]), 0.0, float(pos[2])))
			var camp: CampEntity = CampEntity.create(int(d.get("band", 0)), int(d.get("seed", 0)))
			camp.entity_id = entity_id
			EntityRegistry.register_with_id(camp, &"camp", entity_id)
			nav_region.add_child(camp)
			camp.load_data(d)
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

	# Falda de horizonte: pradera lejana bajo el borde del mapa, para que
	# mirar más allá del límite no enseñe el vacío marrón del cielo.
	var skirt: MeshInstance3D = MeshInstance3D.new()
	skirt.name = "HorizonSkirt"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 600.0
	disc.bottom_radius = 600.0
	disc.height = 0.1
	disc.radial_segments = 32
	var skirt_mat: StandardMaterial3D = StandardMaterial3D.new()
	skirt_mat.albedo_color = palette.grass.darkened(0.22)
	disc.material = skirt_mat
	skirt.mesh = disc
	skirt.position = Vector3(0.0, -1.2, 0.0)
	add_child(skirt)

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "Env"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6E9BC4")
	sky_mat.sky_horizon_color = Color("#C9D6C2")
	# Verde oliva apagado, no tierra: si algún ángulo enseña el hemisferio
	# inferior del cielo, que parezca pradera en la niebla y no barro.
	sky_mat.ground_bottom_color = palette.dirt.lerp(palette.grass, 0.55)
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
func _spawn_citizens(center: Vector3 = Vector3.ZERO) -> void:
	var names: Array[String] = ["elian", "mara", "tobin", "nessa"]
	for i: int in names.size():
		var citizen: Citizen = CITIZEN_SCENE.instantiate()
		citizen.data = load("res://data/citizens/%s.tres" % names[i])
		citizen.band_id = 0
		add_child(citizen)
		var ang: float = TAU * float(i) / float(names.size()) + 0.7
		var pos: Vector3 = center + Vector3(cos(ang) * 3.0, 0.0, sin(ang) * 3.0)
		pos.y = terrain_data.get_height(pos.x, pos.z) + 0.05
		citizen.global_position = pos
		citizen.visual.rotation.y = ang + PI * 0.5


func _setup_day_night() -> void:
	var day_night: DayNight = DayNight.new()
	day_night.name = "DayNight"
	day_night.sun = _sun
	day_night.environment = _env
	day_night.sky_material = _sky_mat
	# Las hogueras las descubre DayNight por grupo cada frame: los
	# campamentos pueden nacer después de este _ready (siembra de bandas).
	add_child(day_night)
