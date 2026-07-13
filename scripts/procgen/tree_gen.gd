class_name TreeGen
## Árboles procedurales: tronco cónico con ruido + 2–4 copas de esferas
## achatadas. 5 variantes de silueta según semilla. Joven = escala 0.45.

static var _canopy_materials: Dictionary = {}


static func build_visual(seed_value: int, young: bool = false) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Visual"

	var variant: int = rng.randi_range(0, 4)
	var trunk_height: float = lerpf(2.4, 3.4, rng.randf())
	var trunk_radius: float = lerpf(0.16, 0.24, rng.randf())
	var wood_color: Color = palette.wood.lerp(palette.wood_light, rng.randf() * 0.5)

	var trunk_mesh: ArrayMesh = MeshLib.cylinder(
		trunk_radius, trunk_radius * 0.7, trunk_height, 7, 3, 0.10, rng
	)
	var trunk: MeshInstance3D = MeshLib.mesh_instance(trunk_mesh, wood_color, "Trunk")
	root.add_child(trunk)

	var canopy_color: Color = palette.grass.lerp(palette.grass_light, rng.randf())
	if young:
		canopy_color = canopy_color.lerp(palette.grass_light, 0.5)
	var blob_count: int = _blob_count_for_variant(variant)
	var canopy_base: float = trunk_height * lerpf(0.78, 0.92, rng.randf())
	for blob_i: int in blob_count:
		var blob_radius: float = lerpf(0.9, 1.5, rng.randf()) * (0.75 if young else 1.0)
		var squash: float = lerpf(0.62, 0.8, rng.randf())
		var offset: Vector3 = Vector3(
			rng.randf_range(-0.55, 0.55),
			canopy_base + float(blob_i) * blob_radius * lerpf(0.35, 0.6, rng.randf()),
			rng.randf_range(-0.55, 0.55)
		)
		if variant == 3:
			offset.y = canopy_base + rng.randf_range(0.0, 0.4)
			offset.x *= 2.0
			offset.z *= 2.0
		var blob_mesh: ArrayMesh = MeshLib.low_sphere(blob_radius, 5, 8, squash)
		var blob: MeshInstance3D = MeshInstance3D.new()
		blob.name = "Canopy%d" % blob_i
		blob.mesh = blob_mesh
		blob.position = offset
		blob.material_override = _canopy_material(canopy_color)
		root.add_child(blob)

	if young:
		root.scale = Vector3.ONE * 0.45
	return root


static func trunk_collision_shape(young: bool) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.35 if not young else 0.2
	cylinder.height = 2.4 if not young else 1.2
	shape.shape = cylinder
	shape.position = Vector3(0.0, cylinder.height * 0.5, 0.0)
	return shape


static func _blob_count_for_variant(variant: int) -> int:
	match variant:
		0:
			return 2
		1:
			return 3
		2:
			return 4
		3:
			return 3
		_:
			return 2


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
