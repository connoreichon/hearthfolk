extends Node3D
## Monta el mundo: mapa procedural por semilla, luz, entorno y navmesh.

const DEFAULT_SEED: int = 20260713

var terrain_data: TerrainData
var map_counts: Dictionary = {}

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	if GameState.world_seed == 0:
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
	# terrain(1) | tree(4) | building(16) | prop_static(32)
	nav_mesh.geometry_collision_mask = 53
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh(false)


## Cuatro habitantes en anillo de 3 m alrededor de la fogata (§4).
func _spawn_citizens() -> void:
	var scene: PackedScene = load("res://scenes/citizens/citizen.tscn")
	var names: Array[String] = ["elian", "mara", "tobin", "nessa"]
	for i: int in names.size():
		var citizen: Citizen = scene.instantiate()
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
