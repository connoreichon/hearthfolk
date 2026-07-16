class_name TreeGen
## Árboles procedurales con TIPOS de silueta distinta (pasada de arte): frondoso
## de copa por capas, PINO de conos apilados, redondo compacto y esbelto. Copa
## en varios tonos (base oscura, cima clara) para dar volumen; verdes ricos y
## variados por semilla. Joven = escala 0.45. La colisión no cambia.

## Verdes de FRONDA (distintos del verde del suelo: el bosque es más profundo).
const BROAD_GREENS: Array = ["#4E7A38", "#5B8A40", "#69984A", "#7FA652", "#8E9E3E"]
const PINE_GREENS: Array = ["#3A5F3C", "#436B42", "#4C7749", "#2F5238"]

static var _canopy_materials: Dictionary = {}


static func build_visual(seed_value: int, young: bool = false) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Visual"

	# Mezcla ponderada: frondoso domina, pinos y redondos dan variedad.
	var roll: int = rng.randi_range(0, 9)
	var kind: int = 0  # 0 frondoso · 1 pino · 2 redondo · 3 esbelto
	if roll >= 8:
		kind = 3
	elif roll >= 6:
		kind = 2
	elif roll >= 3:
		kind = 1

	match kind:
		1:
			_build_pine(root, rng, palette)
		2:
			_build_round(root, rng, palette)
		3:
			_build_slim(root, rng, palette)
		_:
			_build_broadleaf(root, rng, palette)

	if young:
		root.scale = Vector3.ONE * 0.45
	return root


## Frondoso: tronco cónico + CORONA por capas (blobs anchos y oscuros abajo,
## estrechos y claros arriba) → una copa llena con volumen, no bolas sueltas.
static func _build_broadleaf(
	root: Node3D, rng: RandomNumberGenerator, palette: PaletteData
) -> void:
	var trunk_h: float = lerpf(2.4, 3.4, rng.randf())
	var trunk_r: float = lerpf(0.17, 0.25, rng.randf())
	_add_trunk(root, rng, palette, trunk_h, trunk_r, 0.7)
	var base_green: Color = Color(BROAD_GREENS[rng.randi_range(0, BROAD_GREENS.size() - 1)])
	var layers: int = rng.randi_range(3, 5)
	var canopy_base: float = trunk_h * lerpf(0.72, 0.85, rng.randf())
	for layer: int in layers:
		var t: float = float(layer) / float(maxi(1, layers - 1))
		# Abajo ancho y oscuro; arriba estrecho y claro
		var radius: float = lerpf(1.5, 0.75, t) * lerpf(0.9, 1.1, rng.randf())
		var shade: Color = base_green.darkened(0.16 * (1.0 - t)).lightened(0.12 * t)
		var jitter: float = lerpf(0.5, 0.15, t)
		var y: float = canopy_base + t * lerpf(1.1, 1.6, rng.randf())
		_add_blob(
			root,
			radius,
			lerpf(0.7, 0.85, rng.randf()),
			Vector3(rng.randf_range(-jitter, jitter), y, rng.randf_range(-jitter, jitter)),
			shade
		)


## Pino: tronco alto y fino + 3-4 conos apilados que menguan hacia la cima.
static func _build_pine(root: Node3D, rng: RandomNumberGenerator, palette: PaletteData) -> void:
	var trunk_h: float = lerpf(2.0, 2.8, rng.randf())
	_add_trunk(root, rng, palette, trunk_h, lerpf(0.13, 0.18, rng.randf()), 0.6)
	var base_green: Color = Color(PINE_GREENS[rng.randi_range(0, PINE_GREENS.size() - 1)])
	var tiers: int = rng.randi_range(3, 4)
	var y: float = trunk_h * 0.55
	for tier: int in tiers:
		var t: float = float(tier) / float(tiers)
		var radius: float = lerpf(1.3, 0.35, t) * lerpf(0.92, 1.08, rng.randf())
		var height: float = lerpf(1.4, 0.9, t)
		var cone: MeshInstance3D = MeshInstance3D.new()
		cone.name = "Tier%d" % tier
		cone.mesh = MeshLib.cone(radius, height, 8)
		cone.position = Vector3(0.0, y, 0.0)
		cone.material_override = _canopy_material(base_green.lightened(0.1 * t))
		root.add_child(cone)
		y += height * lerpf(0.55, 0.68, rng.randf())


## Redondo: tronco corto + una copa grande achatada y un par de refuerzos.
static func _build_round(root: Node3D, rng: RandomNumberGenerator, palette: PaletteData) -> void:
	var trunk_h: float = lerpf(1.5, 2.1, rng.randf())
	_add_trunk(root, rng, palette, trunk_h, lerpf(0.18, 0.26, rng.randf()), 0.72)
	var base_green: Color = Color(BROAD_GREENS[rng.randi_range(0, BROAD_GREENS.size() - 1)])
	var big_r: float = lerpf(1.5, 1.9, rng.randf())
	_add_blob(
		root,
		big_r,
		lerpf(0.6, 0.72, rng.randf()),
		Vector3(0.0, trunk_h + big_r * 0.4, 0.0),
		base_green
	)
	for _i: int in 2:
		var r: float = lerpf(0.7, 1.0, rng.randf())
		_add_blob(
			root,
			r,
			0.72,
			Vector3(rng.randf_range(-0.7, 0.7), trunk_h + big_r * 0.35, rng.randf_range(-0.7, 0.7)),
			base_green.lightened(0.1)
		)


## Esbelto: tronco alto y fino con una copa pequeña y alta (bosque joven).
static func _build_slim(root: Node3D, rng: RandomNumberGenerator, palette: PaletteData) -> void:
	var trunk_h: float = lerpf(3.2, 4.2, rng.randf())
	_add_trunk(root, rng, palette, trunk_h, lerpf(0.11, 0.16, rng.randf()), 0.55)
	var base_green: Color = Color(BROAD_GREENS[rng.randi_range(0, BROAD_GREENS.size() - 1)])
	for i: int in 3:
		var r: float = lerpf(0.65, 0.95, rng.randf())
		_add_blob(
			root,
			r,
			lerpf(0.7, 0.82, rng.randf()),
			Vector3(
				rng.randf_range(-0.3, 0.3),
				trunk_h * 0.82 + float(i) * r * 0.5,
				rng.randf_range(-0.3, 0.3)
			),
			base_green.lightened(0.06 * float(i))
		)


static func _add_trunk(
	root: Node3D,
	rng: RandomNumberGenerator,
	palette: PaletteData,
	height: float,
	radius: float,
	taper: float
) -> void:
	var wood_color: Color = palette.wood.lerp(palette.wood_light, rng.randf() * 0.4).darkened(0.05)
	var trunk_mesh: ArrayMesh = MeshLib.cylinder(radius, radius * taper, height, 7, 3, 0.10, rng)
	root.add_child(MeshLib.mesh_instance(trunk_mesh, wood_color, "Trunk"))


static func _add_blob(
	root: Node3D, radius: float, squash: float, offset: Vector3, color: Color
) -> void:
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.name = "Canopy"
	blob.mesh = MeshLib.low_sphere(radius, 5, 8, squash)
	blob.position = offset
	blob.material_override = _canopy_material(color)
	root.add_child(blob)


static func trunk_collision_shape(young: bool) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.35 if not young else 0.2
	cylinder.height = 2.4 if not young else 1.2
	shape.shape = cylinder
	shape.position = Vector3(0.0, cylinder.height * 0.5, 0.0)
	return shape


static func _canopy_material(color: Color) -> ShaderMaterial:
	var key: String = color.to_html()
	if _canopy_materials.has(key):
		return _canopy_materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/wind.gdshader")
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"sway_strength", 0.05)
	mat.set_shader_parameter(&"height_ref", 1.4)
	_canopy_materials[key] = mat
	return mat
