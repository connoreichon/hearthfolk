class_name PropGen
## Props procedurales: rocas, arbustos, flores, carro, fogata (§5.3).

static var _wind_materials: Dictionary = {}


static func rock(seed_value: int, big: bool) -> MeshInstance3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var radius: float = rng.randf_range(0.55, 0.95) if big else rng.randf_range(0.18, 0.38)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.4
	var deform: Callable = func(p: Vector3) -> Vector3:
		var n: float = noise.get_noise_3d(p.x, p.y, p.z)
		return p * (1.0 + n * 0.35) * Vector3(1.0, rng.randf_range(0.55, 0.75), 1.0)
	var mesh: ArrayMesh = MeshLib.low_sphere(radius, 5, 7, 1.0, deform)
	var color: Color = palette.stone.lerp(palette.dirt, rng.randf() * 0.25)
	var mi: MeshInstance3D = MeshLib.mesh_instance(mesh, color, "Rock")
	mi.set_meta(&"radius", radius)
	return mi


static func bush(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Bush"
	var blob_count: int = rng.randi_range(2, 3)
	for blob_i: int in blob_count:
		var radius: float = rng.randf_range(0.3, 0.55)
		var mesh: ArrayMesh = MeshLib.low_sphere(radius, 4, 7, rng.randf_range(0.6, 0.75))
		var blob: MeshInstance3D = MeshInstance3D.new()
		blob.name = "Blob%d" % blob_i
		blob.mesh = mesh
		blob.position = Vector3(
			rng.randf_range(-0.3, 0.3), radius * 0.45, rng.randf_range(-0.3, 0.3)
		)
		var color: Color = palette.grass.lerp(palette.grass_light, rng.randf())
		blob.material_override = _wind_material(color, 0.04, 0.8)
		root.add_child(blob)
	return root


static func flower_patch(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Flowers"
	var petal_colors: Array[Color] = [
		palette.accent,
		palette.roof.lerp(palette.cart_cloth, 0.4),
		palette.cart_cloth,
	]
	var flower_count: int = rng.randi_range(4, 7)
	for flower_i: int in flower_count:
		var flower: Node3D = Node3D.new()
		flower.name = "Flower%d" % flower_i
		var stem_height: float = rng.randf_range(0.22, 0.4)
		var stem: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.cylinder(0.015, 0.012, stem_height, 5), palette.grass, "Stem"
		)
		stem.material_override = _wind_material(palette.grass, 0.05, 0.4)
		flower.add_child(stem)
		var head_color: Color = petal_colors[rng.randi_range(0, petal_colors.size() - 1)]
		var head: MeshInstance3D = MeshInstance3D.new()
		head.name = "Head"
		head.mesh = MeshLib.low_sphere(rng.randf_range(0.05, 0.09), 4, 6, 0.7)
		head.position = Vector3(0.0, stem_height, 0.0)
		head.material_override = _wind_material(head_color, 0.05, 0.4)
		flower.add_child(head)
		flower.position = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
		root.add_child(flower)
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


## Montón de suministros de campamento: leños apilados + fardo con lona.
## Sustituto primitivo del carro como &"storage" de cada banda (Build 003).
static func supply_pile(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "SupplyPile"
	for row: int in 3:
		var per_row: int = 3 - row
		for log_i: int in per_row:
			var log_mesh: MeshInstance3D = MeshLib.mesh_instance(
				MeshLib.log_cylinder(0.11, rng.randf_range(0.9, 1.1), 7),
				palette.wood,
				"Log%d_%d" % [row, log_i]
			)
			log_mesh.rotation_degrees = Vector3(0.0, rng.randf_range(-6.0, 6.0), 90.0)
			log_mesh.position = Vector3(
				-0.35, 0.11 + float(row) * 0.19, (float(log_i) - float(per_row - 1) * 0.5) * 0.24
			)
			root.add_child(log_mesh)
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


## Fogata: anillo de piedras + leños cruzados + luz (apagada de día).
static func campfire(seed_value: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Campfire"
	var stone_count: int = 7
	for stone_i: int in stone_count:
		var ang: float = TAU * float(stone_i) / float(stone_count) + rng.randf_range(-0.15, 0.15)
		var stone: MeshInstance3D = rock(seed_value + 100 + stone_i, false)
		stone.name = "Stone%d" % stone_i
		stone.position = Vector3(cos(ang) * 0.62, 0.05, sin(ang) * 0.62)
		stone.scale = Vector3.ONE * rng.randf_range(0.7, 1.0)
		root.add_child(stone)
	for log_i: int in 4:
		var log_mesh: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.log_cylinder(0.07, 0.7, 6), palette.wood, "Log%d" % log_i
		)
		var ang: float = TAU * float(log_i) / 4.0 + 0.4
		log_mesh.position = Vector3(cos(ang) * 0.18, 0.1, sin(ang) * 0.18)
		log_mesh.rotation_degrees = Vector3(52.0, rad_to_deg(-ang) + 90.0, 0.0)
		root.add_child(log_mesh)
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


static func _wind_material(color: Color, strength: float, height_ref: float) -> ShaderMaterial:
	var key: String = "%s_%f_%f" % [color.to_html(), strength, height_ref]
	if _wind_materials.has(key):
		return _wind_materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/wind.gdshader")
	mat.set_shader_parameter(&"albedo", color)
	mat.set_shader_parameter(&"sway_strength", strength)
	mat.set_shader_parameter(&"height_ref", height_ref)
	_wind_materials[key] = mat
	return mat
