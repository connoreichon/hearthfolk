class_name PropGen
## Props con MODELOS 3D estilizados (§5.3): glb CC0 (Kenney) retrabajados a la
## paleta del juego en Blender. El color viene HORNEADO en el COLOR de vértice
## (paleta × volumen), así que el material es wind.gdshader con albedo neutro.
## Carro y pozo siguen siendo procedurales (ya leen bien).

const PROPS_DIR: String = "res://assets/models/props/"
const MK_DIR: String = "res://assets/models/props2/"
const WIND_SHADER: Shader = preload("res://shaders/wind.gdshader")
const CANOPY_SHADER: Shader = preload("res://shaders/canopy_wind.gdshader")

# Sotobosque del Stylized Nature MegaKit (Quaternius CC0): texturas pintadas
# a mano, mismos materiales importados que los árboles (nada de albedo plano).
const MK_ROCKS_SMALL: Array = [
	"Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Square_1", "Pebble_Square_2"
]
const MK_ROCKS_BIG: Array = ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const MK_BUSHES: Array = ["Bush_Common", "Bush_Common_Flowers"]
const MK_FLOWERS: Array = [
	"Flower_3_Group", "Flower_3_Single", "Flower_4_Group", "Flower_4_Single",
	"Clover_1", "Clover_2", "Fern_1"
]
const MK_MUSHROOMS: Array = ["Mushroom_Common", "Mushroom_Laetiporus"]

static var _wind_materials: Dictionary = {}
static var _mesh_cache: Dictionary = {}


## Malla compartida de un prop glb (cacheada: mismas mallas → instancing GPU).
static func prop_mesh(prop: String) -> Mesh:
	if _mesh_cache.has(prop):
		return _mesh_cache[prop]
	var scene: PackedScene = load(PROPS_DIR + prop + ".glb")
	var inst: Node = scene.instantiate()
	var mesh: Mesh = _first_mesh(inst)
	inst.free()
	_mesh_cache[prop] = mesh
	return mesh


static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child: Node in node.get_children():
		var found: Mesh = _first_mesh(child)
		if found != null:
			return found
	return null


## Malla de un prop del MegaKit (gltf con material pintado en superficie).
static func mk_mesh(prop: String) -> Mesh:
	var key: String = "mk:" + prop
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var scene: PackedScene = load(MK_DIR + prop + ".gltf")
	var inst: Node = scene.instantiate()
	var mesh: Mesh = _first_mesh(inst)
	inst.free()
	_mesh_cache[key] = mesh
	return mesh


## MeshInstance3D de un prop MegaKit: el material pintado va en la malla.
static func mk_instance(prop: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = prop.replace("_", "")
	mi.mesh = mk_mesh(prop)
	return mi


## Material VIVO (canopy_wind) para una superficie texturizada: viento +
## otoño + nieve dinámica en las caras que miran al cielo. Cacheado.
static func living_material(
	tex: Texture2D, sway: float, height_ref: float, season: float, snow: float
) -> ShaderMaterial:
	var key: String = "%s|%.2f|%.1f|%.1f|%.1f" % [tex.get_rid(), sway, height_ref, season, snow]
	if _wind_materials.has(key):
		return _wind_materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = CANOPY_SHADER
	mat.set_shader_parameter(&"albedo_tex", tex)
	mat.set_shader_parameter(&"sway_strength", sway)
	mat.set_shader_parameter(&"height_ref", height_ref)
	mat.set_shader_parameter(&"season_mix", season)
	mat.set_shader_parameter(&"snow_mix", snow)
	_wind_materials[key] = mat
	return mat


## Aplica el material vivo a TODAS las superficies texturizadas de la malla
## (hojas: viento+otoño; corteza/roca: quieto, solo nieve).
static func apply_living(
	mi: MeshInstance3D, sway: float, height_ref: float, season: float, snow: float
) -> void:
	for i: int in mi.mesh.get_surface_count():
		var src: BaseMaterial3D = mi.mesh.surface_get_material(i) as BaseMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		var is_foliage: bool = src.resource_name.containsn("leaf") \
			or src.resource_name.containsn("leaves")
		var s: float = sway if is_foliage else 0.0
		var season_k: float = season if is_foliage else 0.0
		mi.set_surface_override_material(
			i, living_material(src.albedo_texture, s, height_ref, season_k, snow)
		)


## MeshInstance3D de un prop: color horneado + viento/estaciones del shader.
static func prop_instance(
	prop: String, sway: float, height_ref: float, season: float, snow: float
) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = prop.capitalize().replace(" ", "")
	mi.mesh = prop_mesh(prop)
	mi.material_override = _baked_material(sway, height_ref, season, snow)
	return mi


static func rock(seed_value: int, big: bool) -> MeshInstance3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var variants: Array = MK_ROCKS_BIG if big else MK_ROCKS_SMALL
	var mi: MeshInstance3D = mk_instance(variants[rng.randi_range(0, variants.size() - 1)])
	apply_living(mi, 0.0, 1.0, 0.0, 1.0)  # nieve dinámica sobre la piedra
	mi.name = "Rock"
	mi.rotation.y = rng.randf() * TAU
	var s: float = rng.randf_range(0.8, 1.25)
	mi.scale = Vector3.ONE * s
	var aabb: AABB = mi.mesh.get_aabb()
	mi.set_meta(&"radius", maxf(aabb.size.x, aabb.size.z) * 0.5 * s)
	return mi


static func bush(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var root: Node3D = Node3D.new()
	root.name = "Bush"
	var mi: MeshInstance3D = mk_instance(
		MK_BUSHES[rng.randi_range(0, MK_BUSHES.size() - 1)]
	)
	apply_living(mi, 0.05, 0.9, 1.0, 1.0)  # viento + otoño + nieve
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * rng.randf_range(0.85, 1.2)
	root.add_child(mi)
	# Arbusto de BAYAS (frutos): puntitos rojos o azulados encima
	if rng.randf() < 0.55:
		var berry_color: Color = Color("#B4432F") if rng.randf() < 0.6 else Color("#6A5B9E")
		var aabb: AABB = mi.mesh.get_aabb()
		var r: float = maxf(aabb.size.x, aabb.size.z) * 0.5 * mi.scale.x
		var top: float = aabb.size.y * mi.scale.y
		for _b: int in rng.randi_range(3, 5):
			var berry: MeshInstance3D = MeshLib.mesh_instance(
				MeshLib.low_sphere(0.035, 3, 5, 1.0), berry_color, "Berry"
			)
			var ang: float = rng.randf() * TAU
			var dist: float = rng.randf_range(0.25, 0.7) * r
			berry.position = Vector3(
				cos(ang) * dist, top * rng.randf_range(0.65, 0.95), sin(ang) * dist
			)
			root.add_child(berry)
	return root


static func flower_patch(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var root: Node3D = Node3D.new()
	root.name = "Flowers"
	var flower_count: int = rng.randi_range(3, 6)
	for flower_i: int in flower_count:
		var mi: MeshInstance3D = mk_instance(
			MK_FLOWERS[rng.randi_range(0, MK_FLOWERS.size() - 1)]
		)
		apply_living(mi, 0.05, 0.4, 0.0, 1.0)  # brisa + nieve encima
		mi.name = "Flower%d" % flower_i
		mi.position = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.15)
		root.add_child(mi)
	return root


## Árbol SECO (tundra/sabana): silueta desnuda pintada, decorativo.
static func dead_tree(seed_value: int) -> MeshInstance3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var variants: Array = ["DeadTree_1", "DeadTree_2", "DeadTree_3"]
	var mi: MeshInstance3D = mk_instance(variants[rng.randi_range(0, variants.size() - 1)])
	apply_living(mi, 0.0, 4.0, 0.0, 1.0)  # quieto, sin otoño, acumula nieve
	mi.name = "DeadTree"
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
	return mi


## Corro de setas del bosque (solo decorativo).
static func mushroom_patch(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var root: Node3D = Node3D.new()
	root.name = "Mushrooms"
	for shroom_i: int in rng.randi_range(1, 3):
		var mi: MeshInstance3D = mk_instance(
			MK_MUSHROOMS[rng.randi_range(0, MK_MUSHROOMS.size() - 1)]
		)
		apply_living(mi, 0.0, 1.0, 0.0, 1.0)  # nieve en el sombrero
		mi.name = "Mushroom%d" % shroom_i
		mi.position = Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.75, 1.1)
		root.add_child(mi)
	return root


## Carro almacén: caja biselada + 4 ruedas + toldo de tela.
static func cart(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Cart"
	var body: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(2.2, 0.6, 1.25), 0.05), palette.wood, "Body"
	)
	body.position = Vector3(0.0, 0.75, 0.0)
	root.add_child(body)
	for wheel_i: int in 4:
		var wheel: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.cylinder(0.34, 0.34, 0.12, 10), palette.wood_light, "Wheel%d" % wheel_i
		)
		wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		var side_x: float = -0.75 if wheel_i < 2 else 0.75
		var side_z: float = -0.68 if wheel_i % 2 == 0 else 0.68 + 0.12
		wheel.position = Vector3(side_x, 0.34, side_z)
		root.add_child(wheel)
	var cloth: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.72, 0.72, 1.9, 9, 1, 0.0, null, false, false),
		palette.cart_cloth,
		"Cloth"
	)
	cloth.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	cloth.position = Vector3(0.95, 1.1, 0.0)
	root.add_child(cloth)
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.05, 0.04, 1.1, 6), palette.wood_light, "Handle"
	)
	handle.rotation_degrees = Vector3(0.0, 0.0, -65.0)
	handle.position = Vector3(-1.1, 0.55, 0.0)
	root.add_child(handle)
	return root


## Montón de suministros: pila de leños (modelo) + fardo con lona.
static func supply_pile(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "SupplyPile"
	var stack: MeshInstance3D = prop_instance("log_stack", 0.0, 1.0, 0.0, 1.0)
	stack.position = Vector3(-0.35, 0.0, 0.0)
	stack.rotation.y = rng.randf_range(-0.15, 0.15)
	root.add_child(stack)
	var bundle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.7, 0.5, 0.8), 0.1), palette.cart_cloth, "Bundle"
	)
	bundle.position = Vector3(0.45, 0.25, 0.0)
	bundle.rotation.y = rng.randf_range(-0.3, 0.3)
	root.add_child(bundle)
	var rope: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.74, 0.06, 0.84), 0.02), palette.wood_light, "Rope"
	)
	rope.position = Vector3(0.45, 0.3, 0.0)
	rope.rotation.y = bundle.rotation.y
	root.add_child(rope)
	return root


## Pozo de la plaza (vida de pueblo): brocal de piedra, dos postes con
## tejadillo a dos aguas y cubo colgando. Nace cuando la aldea sube a Pueblo.
static func well(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Well"
	# Brocal: anillo de piedra con boca oscura
	var ring: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.55, 0.5, 0.55, 10, 1, 0.06, rng), palette.stone, "Ring"
	)
	ring.position.y = 0.27
	root.add_child(ring)
	var mouth: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.38, 0.38, 0.06, 10), Color("#20252B"), "Mouth"
	)
	mouth.position.y = 0.56
	root.add_child(mouth)
	# Postes y caballete
	for side: float in [-1.0, 1.0]:
		var post: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.1, 1.25, 0.1), 0.02), palette.wood, "Post"
		)
		post.position = Vector3(side * 0.52, 0.9, 0.0)
		root.add_child(post)
	var beam: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.045, 0.045, 1.15, 7), palette.wood_light, "Beam"
	)
	beam.rotation.z = PI * 0.5
	beam.position = Vector3(0.0, 1.42, 0.0)
	root.add_child(beam)
	# Tejadillo a dos aguas
	for roof_side: float in [-1.0, 1.0]:
		var panel: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(1.5, 0.06, 0.62)), palette.roof, "RoofPanel"
		)
		panel.rotation.x = roof_side * deg_to_rad(38.0)
		panel.position = Vector3(0.0, 1.72, roof_side * 0.26)
		root.add_child(panel)
	# Cubo colgando de una soga
	var rope: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.015, 0.015, 0.45, 5), palette.cart_cloth, "Rope"
	)
	rope.position = Vector3(0.0, 1.18, 0.0)
	root.add_child(rope)
	var bucket: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.1, 0.13, 0.16, 8, 1, 0.0, null, true, false), palette.wood, "Bucket"
	)
	bucket.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(bucket)
	return root


## Fogata: anillo de piedras + leños (modelos) + luz (apagada de día).
## Los nodos FireLight/Flame/Sparks conservan nombre y comportamiento.
static func campfire(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Campfire"
	var ring: MeshInstance3D = prop_instance("campfire_ring", 0.0, 1.0, 0.0, 1.0)
	ring.rotation.y = rng.randf() * TAU
	root.add_child(ring)
	var logs: MeshInstance3D = prop_instance("campfire", 0.0, 1.0, 0.0, 0.0)
	logs.name = "Logs"
	logs.rotation.y = rng.randf() * TAU
	logs.position.y = 0.03
	root.add_child(logs)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = palette.warm_light
	light.omni_range = 11.0
	light.light_energy = 0.0
	light.position = Vector3(0.0, 0.8, 0.0)
	light.shadow_enabled = true
	root.add_child(light)

	var flame: Node3D = Node3D.new()
	flame.name = "Flame"
	flame.visible = false
	var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = palette.warm_light
	flame_mat.emission_enabled = true
	flame_mat.emission = palette.warm_light
	flame_mat.emission_energy_multiplier = 2.6
	for flame_i: int in 3:
		var cone: MeshInstance3D = MeshInstance3D.new()
		cone.name = "Cone%d" % flame_i
		cone.mesh = MeshLib.cone(0.16 - float(flame_i) * 0.04, 0.5 + float(flame_i) * 0.2, 7)
		cone.material_override = flame_mat
		cone.position = Vector3(rng.randf_range(-0.06, 0.06), 0.14, rng.randf_range(-0.06, 0.06))
		flame.add_child(cone)
	root.add_child(flame)

	var sparks: GPUParticles3D = GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 14
	sparks.lifetime = 1.3
	sparks.emitting = false
	sparks.position = Vector3(0.0, 0.5, 0.0)
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 14.0
	proc.initial_velocity_min = 0.7
	proc.initial_velocity_max = 1.6
	proc.gravity = Vector3(0.0, 0.4, 0.0)
	proc.scale_min = 0.03
	proc.scale_max = 0.07
	proc.color = palette.warm_light
	sparks.process_material = proc
	var spark_mesh: QuadMesh = QuadMesh.new()
	spark_mesh.size = Vector2(0.06, 0.06)
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.albedo_color = palette.warm_light
	spark_mesh.material = spark_mat
	sparks.draw_pass_1 = spark_mesh
	root.add_child(sparks)
	return root


## Material del shader de viento para mallas con color HORNEADO en vértice:
## albedo neutro (el color ya viene en COLOR = paleta × volumen).
static func _baked_material(
	sway: float, height_ref: float, season: float, snow: float
) -> ShaderMaterial:
	var key: String = "baked_%f_%f_%f_%f" % [sway, height_ref, season, snow]
	if _wind_materials.has(key):
		return _wind_materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WIND_SHADER
	mat.set_shader_parameter(&"albedo", Color(1.0, 1.0, 1.0))
	mat.set_shader_parameter(&"sway_strength", sway)
	mat.set_shader_parameter(&"height_ref", height_ref)
	mat.set_shader_parameter(&"season_mix", season)
	mat.set_shader_parameter(&"snow_mix", snow)
	_wind_materials[key] = mat
	return mat


static func _wind_material(color: Color, strength: float, height_ref: float) -> ShaderMaterial:
	var key: String = "%s_%f_%f" % [color.to_html(), strength, height_ref]
	if _wind_materials.has(key):
		return _wind_materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WIND_SHADER
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"sway_strength", strength)
	mat.set_shader_parameter(&"height_ref", height_ref)
	_wind_materials[key] = mat
	return mat
