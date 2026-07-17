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
## SABER DE LAS VELADAS (Build 004, orden del dueño: «primero a puños»):
## el trabajo del día deja chispas; por la noche, la aldea las comparte
## alrededor del fuego. Con saber suficiente llegan las primeras recetas.
const LORE_TOOLS: float = 6.0
## Chispas de saber por tipo de trabajo terminado.
const LORE_BY_KIND: Dictionary = {
	&"chop": 0.8,
	&"build": 1.0,
	&"supply": 0.4,
	&"haul": 0.4,
	&"farm_plant": 0.5,
	&"farm_harvest": 0.5,
	&"plant": 0.7,
}
## Leña objetivo del asentamiento: por debajo, el campamento marca árboles.
const WOOD_TARGET: int = 24
## Receta de la primera casa (nivel 1); mejora sola a cabaña y casa de piedra.
const HOME_RECIPE: String = "res://data/buildings/choza.tres"
## Tinte de ropa por BIOMA (orden del dueño): aldeas del mismo bioma visten
## parecido; biomas lejanos, distinto — se distinguen de un vistazo.
const CLOTH_TINTS: Dictionary = {
	WorldGen.Biome.BOSQUE: Color("#5F7D4F"),
	WorldGen.Biome.RIBERA: Color("#5E7D8C"),
	WorldGen.Biome.COLINAS: Color("#8B8378"),
	WorldGen.Biome.CLARO: Color("#B08E6E"),
	WorldGen.Biome.NIEVE: Color("#9FB2C4"),
	WorldGen.Biome.SABANA: Color("#D9B25E"),
}

var entity_id: int = 0
var band_id: int = 0
var camp_seed: int = 0
## Nombre propio del asentamiento (topónimo automático) y su bioma madre.
var settlement_name: String = ""
var home_biome: int = WorldGen.Biome.PRADERA
## El pozo de la plaza (vida de pueblo): uno por aldea, al subir a Pueblo.
var has_well: bool = false
## Saber acumulado de la aldea (persistido) y chispas del día en curso.
var lore: float = 0.0
var _lore_today: float = 0.0
var _lore_toast_done: bool = false

var _plan_timer: float = 0.0
## Pasadas seguidas (1 cada 15 s de sim) con la despensa en crisis: el
## huerto solo se rotura si el hambre SE SOSTIENE, no por un bajón puntual.
var _hungry_checks: int = 0


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
	_add_bedrolls(camp, rng)
	return camp


## Petates SIEMPRE presentes junto a la hoguera (orden del dueño): quien
## duerma al raso tiene su saco con estera, almohadón y rollo a los pies —
## nada de dormir sobre la hierba pelada. (Camas de madera dentro de las
## casas llegan con las eras, S8.)
static func _add_bedrolls(camp: Node3D, rng: RandomNumberGenerator) -> void:
	var count: int = 3
	for i: int in count:
		var ang: float = TAU * float(i) / float(count) + 1.1 + rng.randf_range(-0.15, 0.15)
		var bed: Node3D = _make_bedroll(rng)
		bed.position = Vector3(cos(ang) * 2.8, 0.0, sin(ang) * 2.8)
		bed.rotation.y = -ang + PI * 0.5
		camp.add_child(bed)


static func _make_bedroll(rng: RandomNumberGenerator) -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var cloths: Array[Color] = [
		palette.cart_cloth, Color("#B07A55"), Color("#8A9A6B"), Color("#9B6A6A")
	]
	var cloth: Color = cloths[rng.randi() % cloths.size()]
	var roll: Node3D = Node3D.new()
	roll.name = "Bedroll"
	var mat: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.7, 0.07, 1.5), 0.03), cloth, "Mat"
	)
	mat.position.y = 0.04
	roll.add_child(mat)
	var pillow: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.5, 0.13, 0.28), 0.05), cloth.lightened(0.18), "Pillow"
	)
	pillow.position = Vector3(0.0, 0.11, -0.6)
	roll.add_child(pillow)
	var foot_roll: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.09, 0.09, 0.72, 8), palette.wood_light, "Roll"
	)
	foot_roll.rotation.z = PI * 0.5
	foot_roll.position = Vector3(0.0, 0.09, 0.72)
	roll.add_child(foot_roll)
	return roll


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


## ¿El claro entero está seco y lejos del agua? Muestreo DENSO (centro +
## 12 puntos a 4 m + 8 a 8 m): los meandros se cuelan entre muestras
## sueltas — visto con el navmesh en la mano.
static func clearing_is_dry(world_gen: WorldGen, x: float, z: float) -> bool:
	if world_gen.river_mask(x, z) > 0.08:
		return false
	for i: int in 12:
		var ang: float = TAU * float(i) / 12.0
		if world_gen.river_mask(x + cos(ang) * 4.0, z + sin(ang) * 4.0) > 0.08:
			return false
	for i: int in 8:
		var ang: float = TAU * float(i) / 8.0 + 0.3
		if world_gen.river_mask(x + cos(ang) * 8.0, z + sin(ang) * 8.0) > 0.08:
			return false
	return true


## Campamento de una banda concreta (null si su campamento murió).
static func camp_of_band(tree: SceneTree, which_band: int) -> CampEntity:
	for node: Node in tree.get_nodes_in_group(&"camps"):
		var camp: CampEntity = node as CampEntity
		if camp != null and camp.band_id == which_band:
			return camp
	return null


## Bautiza el asentamiento según su bioma madre (determinista por semilla)
## y levanta los MOJONES que dibujan su frontera en el mundo.
func assign_identity(biome: int) -> void:
	home_biome = biome
	settlement_name = SettlementNames.generate(camp_seed, biome)
	_raise_boundary_stones()


## Anillo de mojones en el borde del territorio: piedra baja con chispa de
## brasa encima — la frontera se LEE en el paisaje, no en un menú.
func _raise_boundary_stones() -> void:
	var terrain: TerrainData = GameState.terrain
	var world_gen: WorldGen = GameState.world_gen
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = camp_seed + 55
	for i: int in 10:
		var ang: float = TAU * float(i) / 10.0 + rng.randf_range(-0.1, 0.1)
		var x: float = global_position.x + cos(ang) * TERRITORY_RADIUS
		var z: float = global_position.z + sin(ang) * TERRITORY_RADIUS
		if not world_gen.is_inside(x, z, 2.0):
			continue
		var h: float = world_gen.height(x, z)
		if h < WorldGen.WATER_LEVEL + 0.15 or terrain.get_slope_deg(x, z) > 30.0:
			continue
		var stone: MeshInstance3D = PropGen.rock(rng.randi(), false)
		stone.name = "Mojon%d" % i
		stone.scale = Vector3.ONE * 0.85
		stone.position = Vector3(
			x - global_position.x, h - 0.04 - global_position.y, z - global_position.z
		)
		add_child(stone)
		var ember: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.09, 0.09, 0.09), 0.02), Color("#E8703A"), "Chispa"
		)
		ember.position = stone.position + Vector3(0.0, 0.34, 0.0)
		ember.rotation.y = rng.randf() * TAU
		add_child(ember)


## Rango del asentamiento por CASAS terminadas en su territorio (los
## cobertizos y demás edificios sin camas no suben de rango).
func rank_name() -> String:
	var houses: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"buildings"):
		var building: ConstructionSite = node as ConstructionSite
		if building == null or building.recipe.sleep_slots <= 0:
			continue
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


## Tinte de ropa de la aldea, por su bioma madre (culturas plenas en S5/004).
func cloth_tint() -> Color:
	return CLOTH_TINTS.get(home_biome, Color("#C8A96B"))


## Clima del hogar: manda sobre CÓMO se abriga la aldea (orden del dueño:
## los ropajes se desarrollan según las necesidades del bioma).
func wardrobe_climate() -> StringName:
	if home_biome == WorldGen.Biome.NIEVE:
		return &"frio"
	if home_biome == WorldGen.Biome.SABANA or home_biome == WorldGen.Biome.DESIERTO:
		return &"calido"
	return &"templado"


## Guardarropa que viste la aldea (orden del dueño «empiezan casi sin
## ropa»): 0 taparrabos (campamento) · 1 túnica (≥1 casa) · 2 ropa entera
## (≥4 casas, rango Pueblo). La ropa PROGRESA con el asentamiento.
func wardrobe_tier() -> int:
	var houses: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"buildings"):
		var building: ConstructionSite = node as ConstructionSite
		if building == null or building.recipe.sleep_slots <= 0:
			continue
		if building.global_position.distance_to(global_position) <= TERRITORY_RADIUS:
			houses += 1
	if houses >= 4:
		return 2
	if houses >= 1:
		return 1
	return 0


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
		"well": has_well,
		"lore": lore,
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
	has_well = bool(d.get("well", false))
	if has_well:
		_raise_well()
	lore = float(d.get("lore", 0.0))
	_lore_toast_done = knows_tools()


func _ready() -> void:
	add_to_group(&"camps")
	add_to_group(&"persistent")
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"camp")
	SimClock.sim_tick.connect(_on_sim_tick)
	EventBus.work_done.connect(_on_work_done)
	SimClock.phase_changed.connect(_on_phase_changed)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


## ---- SABER DE LAS VELADAS (Build 004) ----


## ¿La aldea aprendió ya a tallar herramientas de piedra?
func knows_tools() -> bool:
	return lore >= LORE_TOOLS


## Cada trabajo TERMINADO por gente de esta banda deja su chispa.
func _on_work_done(kind: StringName, worker_id: int) -> void:
	if not is_inside_tree():
		return
	var worker: Citizen = EntityRegistry.get_node_by_id(worker_id) as Citizen
	if worker == null or worker.band_id != band_id:
		return
	_lore_today += float(LORE_BY_KIND.get(kind, 0.3))


## LA VELADA: al caer la noche, la aldea comparte lo aprendido alrededor
## del fuego. Si hay corro (≥3 junto a la hoguera), el saber CUNDE (×1.5).
func _on_phase_changed(phase: int) -> void:
	if not is_inside_tree() or phase != SimClock.Phase.NIGHT or _lore_today <= 0.0:
		return
	var corro: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		if citizen == null or citizen.band_id != band_id:
			continue
		if citizen.global_position.distance_to(global_position) < 9.0:
			corro += 1
	var gained: float = _lore_today * (1.5 if corro >= 3 else 1.0)
	var knew: bool = knows_tools()
	lore += gained
	_lore_today = 0.0
	FloatingText.spawn(
		self, global_position + Vector3(0.0, 2.2, 0.0), "+%.0f saber" % gained, Color("#FFD38A")
	)
	if not knew and knows_tools() and not _lore_toast_done:
		_lore_toast_done = true
		EventBus.toast.emit(
			"En la velada de %s, las manos aprendieron a tallar la piedra" % settlement_name,
			&"success"
		)


func _on_sim_tick(dt: float) -> void:
	if not is_inside_tree():
		return
	_plan_timer -= dt
	if _plan_timer > 0.0:
		return
	_plan_timer = 15.0
	_plan_wood()
	_plan_infrastructure()


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
	var candidates: Array[TreeEntity] = []
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree == null or tree.marked or not tree.choppable():
			continue
		if (
			tree.global_position.distance_squared_to(global_position)
			< (TERRITORY_RADIUS * TERRITORY_RADIUS)
		):
			candidates.append(tree)
	candidates.sort_custom(
		func(a: TreeEntity, b: TreeEntity) -> bool:
			return (
				a.global_position.distance_squared_to(global_position)
				< b.global_position.distance_squared_to(global_position)
			)
	)
	# Como la T del jugador: nunca marcar un árbol SIN RUTA (un río entre
	# medias convertía la tala rutinaria en peregrinajes fallidos)
	for tree: TreeEntity in candidates.slice(0, 4):
		if not is_inside_tree():
			return
		if NavUtil.is_practical(get_world_3d(), global_position, tree.global_position, 2.5):
			tree.set_marked(true)
			# Prioridad 7: la MÁS débil — cede ante órdenes del jugador (5),
			# suministro (4) y construcción (5)
			TaskBoard.publish(&"chop", tree.entity_id, {"band": band_id}, 7)
			return


## REPOBLAR (Build 004, oficio nuevo): si el territorio se queda calvo
## (la tala se come el bosque), la aldea encarga plantar brotes en los
## claros. El bosque es un huerto lento — trabajo del repoblador.
func _plan_replant() -> void:
	# Lujo de aldea ESTABLE: con la leña justa o poca gente, ni un brazo
	# se aparta de la tala, el acarreo o las obras.
	if GameState.get_resource(&"wood") < WOOD_TARGET or population() < 5:
		return
	var alive: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree == null or tree.felled:
			continue
		if (
			tree.global_position.distance_squared_to(global_position)
			< (TERRITORY_RADIUS * TERRITORY_RADIUS)
		):
			alive += 1
	if alive >= 9:
		return
	if TaskBoard.count_kind(&"plant") >= 2:
		return
	# Un claro seco y llano del territorio, lejos de la hoguera y de otros
	# árboles (que el bosque nuevo respire).
	var world_gen: WorldGen = GameState.world_gen
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GameState.rng.randi()
	for _i: int in 20:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(9.0, TERRITORY_RADIUS - 4.0)
		var x: float = global_position.x + cos(ang) * dist
		var z: float = global_position.z + sin(ang) * dist
		var h: float = world_gen.height(x, z)
		if h < WorldGen.WATER_LEVEL + 0.3 or world_gen.river_mask(x, z) > 0.08:
			continue
		if GameState.terrain.get_slope_deg(x, z) > 20.0:
			continue
		var crowded: bool = false
		for node: Node in get_tree().get_nodes_in_group(&"trees"):
			var tree: Node3D = node as Node3D
			if tree != null and tree.global_position.distance_squared_to(Vector3(x, h, z)) < 9.0:
				crowded = true
				break
		if crowded:
			continue
		TaskBoard.publish(&"plant", 0, {"band": band_id, "pos": [x, h, z]}, 8)
		return


## S2 — Infraestructura autoconstruida (docs/S2_DESIGN.md §8): la aldea
## rotura SU huerto cuando la comida aprieta y levanta SU cobertizo de
## suministros cuando la población crece. Misma maquinaria que el jugador.
func _plan_infrastructure() -> void:
	_plan_farm()
	_plan_shed()
	_plan_home()
	_plan_upgrades()
	_plan_well()
	_plan_replant()


## Vida de pueblo: al subir a Pueblo (≥4 casas), la aldea levanta SU POZO
## en la plaza — hito visible de que ya no es un campamento.
func _plan_well() -> void:
	if has_well or wardrobe_tier() < 2:
		return
	if GameState.get_resource(&"wood") < 8:
		return
	if not GameState.take_resource(&"wood", 6):
		return
	has_well = true
	_raise_well()
	EventBus.toast.emit("%s levanta su pozo en la plaza" % settlement_name, &"success")


func _raise_well() -> void:
	var terrain: TerrainData = GameState.terrain
	var world_gen: WorldGen = GameState.world_gen
	for i: int in 8:
		var ang: float = TAU * float(i) / 8.0 + 0.9
		var x: float = global_position.x + cos(ang) * 5.5
		var z: float = global_position.z + sin(ang) * 5.5
		if world_gen != null and world_gen.river_mask(x, z) > 0.08:
			continue
		if terrain != null and terrain.get_slope_deg(x, z) > 12.0:
			continue
		var well: Node3D = PropGen.well(camp_seed + 33)
		well.position = Vector3(
			x - global_position.x,
			(terrain.get_height(x, z) if terrain != null else 0.0) - global_position.y,
			z - global_position.z
		)
		add_child(well)
		return


## S7 — Los aldeanos levantan una CHOZA cuando alguien no tiene cama en casa
## (dormir al raso junto a la hoguera es el recurso, no el objetivo). Una
## casa en obra a la vez: fuego lento. La choza mejora sola con el tiempo.
func _plan_home() -> void:
	# Solo asentamientos ESTABLECIDOS construyen casas (una banda pequeña
	# acampa; una crecida se echa raíces). Umbral de 5 habitantes.
	if population() < 5:
		return
	if population() <= _house_beds():
		return
	if GameState.get_resource(&"wood") < 10:
		return
	if _house_under_construction():
		return
	var rect: Rect2 = _find_plot(Vector2(6.0, 6.0), &"zone")
	if rect.size.x <= 0.0:
		return
	var center: Vector2 = rect.get_center()
	var at: Vector3 = Vector3(center.x, GameState.terrain.get_height(center.x, center.y), center.y)
	# Puerta hacia la hoguera (como las casas del jugador)
	var to_fire: Vector3 = global_position - at
	var yaw: float = snappedf(atan2(to_fire.x, to_fire.z) - PI * 0.5, PI * 0.5)
	ConstructionSite.place(
		get_parent() as Node3D, at, yaw, camp_seed + 900 + _house_beds(), 0, HOME_RECIPE
	)
	EventBus.toast.emit("En %s levantan una nueva choza" % settlement_name, &"info")


## S7 — Una casa TERMINADA sube de nivel cuando la aldea crece y hay madera
## de sobra: choza→cabaña (pob ≥4), cabaña→casa de piedra (pob ≥7). Una
## mejora por pasada: las casas maduran poco a poco, a distintos ritmos.
func _plan_upgrades() -> void:
	var pop: int = population()
	for node: Node in get_tree().get_nodes_in_group(&"buildings"):
		var site: ConstructionSite = node as ConstructionSite
		if site == null or not site.completed or site.recipe.upgrade_to.is_empty():
			continue
		if site.global_position.distance_to(global_position) > TERRITORY_RADIUS:
			continue
		var next_tier: int = site.recipe.tier + 1
		if next_tier == 2 and pop < 4:
			continue
		if next_tier >= 3 and pop < 7:
			continue
		if GameState.get_resource(&"wood") < site.recipe.upgrade_cost + 6:
			continue
		if site.upgrade_to_next():
			return


## Camas dentro de casas de la banda (las de la hoguera son el recurso base).
func _house_beds() -> int:
	var beds: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"buildings"):
		var site: ConstructionSite = node as ConstructionSite
		if site == null or not site.completed:
			continue
		if site.global_position.distance_to(global_position) <= TERRITORY_RADIUS:
			beds += site.recipe.sleep_slots
	return beds


func _house_under_construction() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"construction_sites"):
		var site: ConstructionSite = node as ConstructionSite
		if site == null or site.completed:
			continue
		if site.recipe.sleep_slots <= 0:
			continue
		if site.global_position.distance_to(global_position) <= TERRITORY_RADIUS:
			return true
	return false


func _plan_farm() -> void:
	var food_target: float = float(10 + 4 * population())
	if float(GameState.get_resource(&"food")) >= food_target * 0.6:
		_hungry_checks = 0
		return
	_hungry_checks += 1
	if _hungry_checks < 6:
		return
	if _has_in_territory(&"farms"):
		return
	var rect: Rect2 = _find_plot(Vector2(6.0, 6.0), &"farm")
	if rect.size.x <= 0.0:
		return
	FarmField.place(get_parent() as Node3D, rect)
	EventBus.toast.emit("En %s roturan su primer huerto" % settlement_name, &"success")


func _plan_shed() -> void:
	if population() < 6:
		return
	if GameState.get_resource(&"wood") < 10:
		return
	if _storage_points_in_territory() >= 2 or _shed_site_pending():
		return
	var rect: Rect2 = _find_plot(Vector2(6.5, 6.5), &"zone")
	if rect.size.x <= 0.0:
		return
	var center: Vector2 = rect.get_center()
	var at: Vector3 = Vector3(center.x, GameState.terrain.get_height(center.x, center.y), center.y)
	ConstructionSite.place(
		get_parent() as Node3D, at, 0.0, camp_seed + 77, 0, "res://data/buildings/shed.tres"
	)
	EventBus.toast.emit("En %s levantan un cobertizo de suministros" % settlement_name, &"info")


## Parcela válida en anillos desde la hoguera, con la MISMA validación
## que las zonas del jugador (agua, pendiente, solapes, acceso práctico).
## Rect2 de tamaño cero = no hay sitio esta pasada.
func _find_plot(plot_size: Vector2, kind: StringName) -> Rect2:
	var tools: Node = get_tree().get_first_node_in_group(&"tool_manager")
	if tools == null or not is_inside_tree():
		return Rect2()
	for radius: float in [9.0, 12.0, 15.0, 18.0, 21.0]:
		for step: int in 10:
			var ang: float = TAU * float(step) / 10.0 + 0.35
			var cx: float = global_position.x + cos(ang) * radius
			var cz: float = global_position.z + sin(ang) * radius
			var rect: Rect2 = Rect2(
				cx - plot_size.x * 0.5, cz - plot_size.y * 0.5, plot_size.x, plot_size.y
			)
			if bool(
				(tools.call("validate_zone", rect, get_world_3d(), kind) as Dictionary)["valid"]
			):
				return rect
	return Rect2()


func _has_in_territory(group: StringName) -> bool:
	for node: Node in get_tree().get_nodes_in_group(group):
		var spot: Node3D = node as Node3D
		if spot == null:
			continue
		if spot.global_position.distance_to(global_position) <= TERRITORY_RADIUS * 1.5:
			return true
	return false


func _storage_points_in_territory() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"storage"):
		if (node as Node3D).global_position.distance_to(global_position) <= TERRITORY_RADIUS:
			count += 1
	return count


func _shed_site_pending() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"construction_sites"):
		var site: ConstructionSite = node as ConstructionSite
		if site == null or site.completed:
			continue
		if site.recipe.id != &"shed":
			continue
		if site.global_position.distance_to(global_position) <= TERRITORY_RADIUS:
			return true
	return false
