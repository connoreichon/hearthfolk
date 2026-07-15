class_name CampEntity
extends Node3D
## Campamento de una banda: SU hoguera + SU montón de suministros. Es la
## semilla del asentamiento (y en S5, de su cultura). Reutiliza los grupos
## &"campfire" y &"storage" en sus cuerpos hijos para que todo el código
## que hoy consulta esos grupos funcione igual con N campamentos.
## Números de colisión/RVO: los conquistados en los soaks de la 002
## (cilindro 1.35 dentro del agujero ~1.45; RVO + agente 0.35 < agujero).

## Radio del territorio del campamento (S1; crecerá con el rango en S8).
const TERRITORY_RADIUS: float = 30.0
## Leña objetivo del asentamiento: por debajo, el campamento marca árboles.
const WOOD_TARGET: int = 24

var entity_id: int = 0
var band_id: int = 0
var camp_seed: int = 0
## Nombre propio del asentamiento (topónimo automático) y su bioma madre.
var settlement_name: String = ""
var home_biome: int = WorldGen.Biome.PRADERA

var _plan_timer: float = 0.0


static func create(new_band_id: int, seed_value: int) -> CampEntity:
	var camp: CampEntity = CampEntity.new()
	camp.name = "Camp%d" % new_band_id
	camp.band_id = new_band_id
	camp.camp_seed = seed_value
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	var fire_body: StaticBody3D = StaticBody3D.new()
	fire_body.name = "FireBody"
	fire_body.collision_layer = (1 << 5) | (1 << 7)
	fire_body.collision_mask = 0
	fire_body.add_child(PropGen.campfire(rng.randi()))
	var fire_shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 1.35
	cylinder.height = 0.8
	fire_shape.shape = cylinder
	fire_shape.position = Vector3(0.0, 0.4, 0.0)
	fire_body.add_child(fire_shape)
	var fire_obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	fire_obstacle.radius = 1.0
	fire_obstacle.avoidance_enabled = true
	fire_body.add_child(fire_obstacle)
	fire_body.add_to_group(&"campfire")
	fire_body.add_to_group(&"selectable")
	camp.add_child(fire_body)

	var pile_body: StaticBody3D = StaticBody3D.new()
	pile_body.name = "StoragePile"
	pile_body.collision_layer = (1 << 5) | (1 << 7)
	pile_body.collision_mask = 0
	pile_body.add_child(PropGen.supply_pile(rng.randi()))
	var pile_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.6, 0.9, 1.2)
	pile_shape.shape = box
	pile_shape.position = Vector3(0.0, 0.45, 0.0)
	pile_body.add_child(pile_shape)
	var pile_obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	pile_obstacle.radius = 0.9
	pile_obstacle.avoidance_enabled = true
	pile_body.add_child(pile_obstacle)
	var pile_ang: float = rng.randf() * TAU
	pile_body.position = Vector3(cos(pile_ang) * 3.2, 0.0, sin(pile_ang) * 3.2)
	pile_body.rotation.y = -pile_ang
	pile_body.add_to_group(&"storage")
	pile_body.add_to_group(&"selectable")
	camp.add_child(pile_body)
	return camp


## La hoguera (miembro del grupo &"campfire") de este campamento.
func fire_body() -> StaticBody3D:
	return get_node("FireBody") as StaticBody3D


## El montón de suministros (miembro del grupo &"storage") de este campamento.
func storage_body() -> StaticBody3D:
	return get_node("StoragePile") as StaticBody3D


## Campamento más cercano a un punto, o null si no hay ninguno.
static func nearest_camp(tree: SceneTree, from: Vector3) -> CampEntity:
	var best: CampEntity = null
	var best_d: float = INF
	for node: Node in tree.get_nodes_in_group(&"camps"):
		var camp: CampEntity = node as CampEntity
		if camp == null:
			continue
		var d: float = camp.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = camp
	return best


## Posición de la hoguera más cercana a un punto (ZERO si no hay ninguna).
static func nearest_fire_position(tree: SceneTree, from: Vector3) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for node: Node in tree.get_nodes_in_group(&"campfire"):
		var d: float = (node as Node3D).global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = (node as Node3D).global_position
	return best


## El nodo de almacén más cercano a un punto (null si no hay ninguno).
static func nearest_storage_node(tree: SceneTree, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for node: Node in tree.get_nodes_in_group(&"storage"):
		var d: float = (node as Node3D).global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = node as Node3D
	return best


## Campamento de una banda concreta (null si su campamento murió).
static func camp_of_band(tree: SceneTree, which_band: int) -> CampEntity:
	for node: Node in tree.get_nodes_in_group(&"camps"):
		var camp: CampEntity = node as CampEntity
		if camp != null and camp.band_id == which_band:
			return camp
	return null


## Bautiza el asentamiento según su bioma madre (determinista por semilla).
func assign_identity(biome: int) -> void:
	home_biome = biome
	settlement_name = SettlementNames.generate(camp_seed, biome)


## Rango del asentamiento por casas terminadas en su territorio.
func rank_name() -> String:
	var houses: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"buildings"):
		var building: Node3D = node as Node3D
		if building.global_position.distance_to(global_position) <= TERRITORY_RADIUS:
			houses += 1
	if houses >= 14:
		return "Ciudad"
	if houses >= 8:
		return "Villa"
	if houses >= 4:
		return "Pueblo"
	if houses >= 1:
		return "Aldea"
	return "Campamento"


## Habitantes de la banda de este asentamiento.
func population() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		if (node as Citizen).band_id == band_id:
			count += 1
	return count


func entity_kind() -> String:
	return "camp"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"band": band_id,
		"seed": camp_seed,
		"name": settlement_name,
		"biome": home_biome,
		"pos": [global_position.x, global_position.y, global_position.z],
	}


func load_data(d: Dictionary) -> void:
	band_id = int(d.get("band", 0))
	settlement_name = String(d.get("name", ""))
	home_biome = int(d.get("biome", WorldGen.Biome.PRADERA))
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	if settlement_name.is_empty():
		assign_identity(home_biome)


func _ready() -> void:
	add_to_group(&"camps")
	add_to_group(&"persistent")
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"camp")
	SimClock.sim_tick.connect(_on_sim_tick)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func _on_sim_tick(dt: float) -> void:
	if not is_inside_tree():
		return
	_plan_timer -= dt
	if _plan_timer > 0.0:
		return
	_plan_timer = 15.0
	_plan_wood()


## Auto-tala (corazón de la S2, adelantado por orden del dueño): el
## campamento se procura su propia leña marcando el árbol más cercano de
## SU TERRITORIO cuando la reserva baja — con prioridad más débil que las
## órdenes del jugador (0 = máxima), que estas se respetan primero.
func _plan_wood() -> void:
	if GameState.get_resource(&"wood") >= WOOD_TARGET:
		return
	var stats: Dictionary = TaskBoard.stats()
	if int(stats["free"]) + int(stats["claimed"]) >= 14:
		return
	var best: TreeEntity = null
	var best_d: float = TERRITORY_RADIUS * TERRITORY_RADIUS
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree == null or tree.marked or not tree.choppable():
			continue
		var d: float = tree.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = tree
	if best != null:
		best.set_marked(true)
		TaskBoard.publish(&"chop", best.entity_id, {}, 6)
