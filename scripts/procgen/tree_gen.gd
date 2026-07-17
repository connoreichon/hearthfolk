class_name TreeGen
## Árboles del Stylized Nature MegaKit (Quaternius, CC0): modelos glTF con
## texturas PINTADAS A MANO (corteza + hojas). Los materiales importados se
## usan tal cual — nada de albedo plano. build_visual() devuelve un Node3D
## "Visual" cuyos hijos DIRECTOS son MeshInstance3D (contrato del overlay de
## hover/marcado de TreeEntity). Joven = escala 0.45.

const TREES_DIR: String = "res://assets/models/trees2/"

const COMMON: Array = [
	"CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"
]
const PINES: Array = ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const ACCENT: Array = ["TwistedTree_1"]

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

	# Frondoso domina; pinos dan variedad; el árbol CARMESÍ es un hito raro.
	var roll: int = rng.randi_range(0, 99)
	var pool: Array = COMMON
	if roll >= 95:
		pool = ACCENT
	elif roll >= 70:
		pool = PINES
	var model_name: String = pool[rng.randi_range(0, pool.size() - 1)]

	var model: Node3D = _scene(model_name).instantiate()
	var meshes: Array = []
	_collect_meshes(model, meshes)
	for mi: MeshInstance3D in meshes:
		var xform: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
		mi.owner = null  # el owner del gltf ya no aplica al reparentar
		mi.get_parent().remove_child(mi)
		root.add_child(mi)
		mi.transform = xform
	model.free()

	root.rotation.y = rng.randf() * TAU
	var s: float = lerpf(0.88, 1.14, rng.randf())
	root.scale = Vector3.ONE * (0.45 if young else s)
	return root


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


## Elige el modelo con la MISMA lógica de build_visual (frondoso domina,
## pino 25%, carmesí 5%) — para que la flora lejana respire igual.
static func pick_model(rng: RandomNumberGenerator, force_pines: bool = false) -> String:
	var roll: int = rng.randi_range(0, 99)
	var pool: Array = COMMON
	if force_pines or (roll >= 70 and roll < 95):
		pool = PINES
	elif roll >= 95:
		pool = ACCENT
	return pool[rng.randi_range(0, pool.size() - 1)]


## Devuelve un seed cercano al dado cuyo roll caiga en la franja pedida
## (70-94 = pinos). El seed ES lo que persiste el guardado, así que el
## sesgo de bioma (tundra = pinos) sobrevive a guardar/cargar sin añadir
## campos nuevos. Determinista; ~4 sondas de media.
static func seed_for_pines(base: int) -> int:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	var candidate: int = base
	for _i: int in 64:
		probe.seed = candidate
		var roll: int = probe.randi_range(0, 99)
		if roll >= 70 and roll < 95:
			return candidate
		candidate += 1
	return base


static func _scene(model_name: String) -> PackedScene:
	if not _scenes.has(model_name):
		_scenes[model_name] = load(TREES_DIR + model_name + ".gltf")
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
