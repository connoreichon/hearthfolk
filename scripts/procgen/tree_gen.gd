class_name TreeGen
## Árboles a partir de MODELOS 3D estilizados (.glb) en vez de primitivas.
## build_visual() devuelve un Node3D "Visual" cuyos hijos DIRECTOS son
## MeshInstance3D (Trunk, Canopy) — así los overlays de hover/marcado de
## TreeEntity siguen funcionando. La copa usa el shader de viento; el verde
## viene por uniforme y el volumen por COLOR de vértice (gris horneado).
## Variación por semilla: tipo de árbol, giro y escala. Joven = escala 0.45.

const MODELS: Dictionary = {
	"broadleaf": "res://assets/models/trees/tree_broadleaf.glb",
	"round": "res://assets/models/trees/tree_round.glb",
	"pine": "res://assets/models/trees/tree_pine.glb",
}
# Verde base (tono iluminado; el COLOR de vértice oscurece hacia abajo/dentro).
const CANOPY_ALBEDO: Dictionary = {
	"broadleaf": "#93B457",
	"round": "#87AC57",
	"pine": "#5E884E",
}
const TRUNK_ALBEDO: String = "#8B5E3C"
const WIND_SHADER: Shader = preload("res://shaders/wind.gdshader")

static var _scenes: Dictionary = {}
static var _canopy_materials: Dictionary = {}
static var _trunk_mat: ShaderMaterial


static func build_visual(seed_value: int, young: bool = false) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var root: Node3D = Node3D.new()
	root.name = "Visual"

	# Mezcla ponderada: frondoso domina, redondo y pino dan variedad.
	var roll: int = rng.randi_range(0, 9)
	var kind: String = "broadleaf"
	if roll >= 8:
		kind = "pine"
	elif roll >= 6:
		kind = "round"

	var model: Node3D = _scene(kind).instantiate()
	var trunk: MeshInstance3D = _find_mesh(model, "Trunk")
	var canopy: MeshInstance3D = _find_mesh(model, "Canopy")
	# Reparentar como hijos directos del root (preservando su transform local).
	for mi: MeshInstance3D in [trunk, canopy]:
		if mi != null:
			var xform: Transform3D = mi.transform
			mi.get_parent().remove_child(mi)
			root.add_child(mi)
			mi.transform = xform
	model.free()

	if trunk != null:
		trunk.material_override = _trunk_material()
	if canopy != null:
		canopy.material_override = _canopy_material(kind)

	root.rotation.y = rng.randf() * TAU
	var s: float = lerpf(0.9, 1.12, rng.randf())
	root.scale = Vector3.ONE * (0.45 if young else s)
	return root


static func _scene(kind: String) -> PackedScene:
	if not _scenes.has(kind):
		_scenes[kind] = load(MODELS[kind])
	return _scenes[kind]


static func _find_mesh(node: Node, key: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name).findn(key) != -1:
		return node
	for child: Node in node.get_children():
		var r: MeshInstance3D = _find_mesh(child, key)
		if r != null:
			return r
	return null


static func _canopy_material(kind: String) -> ShaderMaterial:
	if _canopy_materials.has(kind):
		return _canopy_materials[kind]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WIND_SHADER
	mat.set_shader_parameter(&"albedo", Color(CANOPY_ALBEDO[kind]))
	mat.set_shader_parameter(&"sway_strength", 0.06)
	mat.set_shader_parameter(&"height_ref", 4.5)
	mat.set_shader_parameter(&"season_mix", 1.0)
	mat.set_shader_parameter(&"snow_mix", 1.0)
	_canopy_materials[kind] = mat
	return mat


static func _trunk_material() -> ShaderMaterial:
	if _trunk_mat == null:
		_trunk_mat = ShaderMaterial.new()
		_trunk_mat.shader = WIND_SHADER
		_trunk_mat.set_shader_parameter(&"albedo", Color(TRUNK_ALBEDO))
		_trunk_mat.set_shader_parameter(&"sway_strength", 0.0)
		_trunk_mat.set_shader_parameter(&"height_ref", 4.0)
		_trunk_mat.set_shader_parameter(&"season_mix", 0.0)
		_trunk_mat.set_shader_parameter(&"snow_mix", 1.0)
	return _trunk_mat


static func trunk_collision_shape(young: bool) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.35 if not young else 0.2
	cylinder.height = 2.4 if not young else 1.2
	shape.shape = cylinder
	shape.position = Vector3(0.0, cylinder.height * 0.5, 0.0)
	return shape
