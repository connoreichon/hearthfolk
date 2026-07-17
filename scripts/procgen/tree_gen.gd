class_name TreeGen
## Árboles con texturas/materiales de packs CC0 de Quaternius: MegaKit
## (pintado a mano: frondosos, pinos, carmesí) + Ultimate Nature Pack
## (abetos de montaña, palmeras de playa, sauces de ribera). build_visual()
## devuelve un Node3D "Visual" cuyos hijos DIRECTOS son MeshInstance3D
## (contrato del overlay de hover/marcado de TreeEntity). Joven = escala 0.45.
##
## ESPECIE = franja del roll (0-999) derivado del seed. El seed ES lo único
## que persiste, así que el sesgo de bioma (tundra→abetos, playa→palmeras,
## ribera→sauces) sobrevive a guardar/cargar (diseño del agente principal).

const TREES_DIR: String = "res://assets/models/trees2/"
const ULT_DIR: String = "res://assets/models/ultimate/"

const COMMON: Array = [
	"CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"
]
const PINES: Array = ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const ACCENT: Array = ["TwistedTree_1"]
const FIRS: Array = ["PineTree_1", "PineTree_3", "PineTree_5"]
const PALMS: Array = ["PalmTree_1", "PalmTree_2", "PalmTree_3", "PalmTree_4"]
const WILLOWS: Array = ["Willow_2", "Willow_4"]

## Franjas del roll de especie (0-999). Templado = COMMON+PINES+ACCENT.
const BAND_TEMPERATE_LO: int = 0
const BAND_TEMPERATE_HI: int = 879
const BAND_PINES_LO: int = 600
const BAND_PINES_HI: int = 849
const BAND_FIRS_LO: int = 880
const BAND_FIRS_HI: int = 919
const BAND_PALMS_LO: int = 920
const BAND_PALMS_HI: int = 969
const BAND_WILLOWS_LO: int = 970
const BAND_WILLOWS_HI: int = 999

static var _scenes: Dictionary = {}
## Piezas por modelo para MultiMesh (FarFlora); el janitor las limpia.
static var _model_parts: Dictionary = {}
# La conserva el janitor (release_static_caches); hoy sin uso activo.
static var _canopy_materials: Dictionary = {}
static var _trunk_mat: ShaderMaterial


static func build_visual(seed_value: int, young: bool = false) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var root: Node3D = Node3D.new()
	root.name = "Visual"

	var model_name: String = _model_for_roll(rng.randi_range(0, 999), rng)
	# Perennes de verdad: ni abetos, ni palmeras, ni pinos se tiñen de otoño.
	var evergreen: bool = (
		model_name.begins_with("Pine") or model_name.begins_with("Palm")
	)

	var model: Node3D = _scene(model_name).instantiate()
	var meshes: Array = []
	_collect_meshes(model, meshes)
	for mi: MeshInstance3D in meshes:
		var xform: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
		mi.owner = null  # el owner del gltf ya no aplica al reparentar
		mi.get_parent().remove_child(mi)
		root.add_child(mi)
		mi.transform = xform
		# Copa VIVA: viento, tinte de otoño (si caduco) y nieve que se
		# acumula/derrite con el snow_amount global.
		PropGen.apply_living(mi, 0.05, 4.5, 0.0 if evergreen else 1.0, 1.0)
	model.free()

	root.rotation.y = rng.randf() * TAU
	var s: float = lerpf(0.88, 1.14, rng.randf())
	root.scale = Vector3.ONE * (0.45 if young else s)
	return root


## Modelo para un roll de especie (mismas franjas que seed_for_band).
static func _model_for_roll(roll: int, rng: RandomNumberGenerator) -> String:
	var pool: Array = COMMON
	if roll >= BAND_WILLOWS_LO:
		pool = WILLOWS
	elif roll >= BAND_PALMS_LO:
		pool = PALMS
	elif roll >= BAND_FIRS_LO:
		pool = FIRS
	elif roll >= 850:
		pool = ACCENT
	elif roll >= BAND_PINES_LO:
		pool = PINES
	return pool[rng.randi_range(0, pool.size() - 1)]


## Piezas (mesh + transform local) de un modelo, para instanciarlo en
## MultiMesh (FarFlora: los bosques del mundo entero sin coste de nodos).
static func model_parts(model_name: String) -> Array[Dictionary]:
	if _model_parts.has(model_name):
		return _model_parts[model_name]
	var parts: Array[Dictionary] = []
	var model: Node3D = _scene(model_name).instantiate()
	var meshes: Array = []
	_collect_meshes(model, meshes)
	for mi: MeshInstance3D in meshes:
		parts.append({"mesh": mi.mesh, "xform": mi.transform})
	model.free()
	_model_parts[model_name] = parts
	return parts


## Elige el modelo con la MISMA lógica de build_visual — para que la flora
## lejana respire igual. force_pines (tundra) sirve ABETOS: la cordillera
## fría se lee de lejos como manto de coníferas oscuras.
static func pick_model(rng: RandomNumberGenerator, force_pines: bool = false) -> String:
	if force_pines:
		return FIRS[rng.randi_range(0, FIRS.size() - 1)]
	return _model_for_roll(rng.randi_range(0, 999), rng)


## Devuelve un seed cercano al dado cuyo roll (0-999) caiga en la franja
## pedida. El seed ES lo que persiste el guardado, así que el sesgo de bioma
## sobrevive a guardar/cargar sin campos nuevos. Determinista.
static func seed_for_band(base: int, lo: int, hi: int) -> int:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	var candidate: int = base
	for _i: int in 256:
		probe.seed = candidate
		var roll: int = probe.randi_range(0, 999)
		if roll >= lo and roll <= hi:
			return candidate
		candidate += 1
	return base


## Compat (API del agente principal): tundra → coníferas.
static func seed_for_pines(base: int) -> int:
	return seed_for_band(base, BAND_FIRS_LO, BAND_FIRS_HI)


static func _scene(model_name: String) -> PackedScene:
	if not _scenes.has(model_name):
		var dir: String = TREES_DIR
		if (
			model_name.begins_with("PineTree_")
			or model_name.begins_with("PalmTree_")
			or model_name.begins_with("Willow_")
		):
			dir = ULT_DIR
		_scenes[model_name] = load(dir + model_name + ".gltf")
	return _scenes[model_name]


static func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
		return
	for child: Node in node.get_children():
		_collect_meshes(child, out)


static func trunk_collision_shape(young: bool) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.35 if not young else 0.2
	cylinder.height = 2.4 if not young else 1.2
	shape.shape = cylinder
	shape.position = Vector3(0.0, cylinder.height * 0.5, 0.0)
	return shape
