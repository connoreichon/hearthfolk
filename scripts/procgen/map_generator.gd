class_name MapGenerator
## Genera el mapa completo por semilla (§4): terreno 120×120 deformado,
## arroyo oeste, camino sur, colina NE y distribución de props por Poisson.

const TREES_ADULT: int = 34
const TREES_YOUNG: int = 12
const ROCKS_BIG: int = 4
const ROCKS_SMALL: int = 14
const FLOWER_PATCHES: int = 6
const BUSHES: int = 8

const CENTER_FLAT_RADIUS: float = 25.0
const HILL_CENTER: Vector2 = Vector2(38.0, -38.0)
const WATER_LEVEL: float = -0.55


static func generate(parent: Node3D, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var terrain: TerrainData = build_terrain_data(seed_value)
	_spawn_terrain_nodes(parent, terrain, seed_value)
	var counts: Dictionary = _spawn_props(parent, terrain, rng)
	return {"terrain": terrain, "counts": counts}


static func build_terrain_data(seed_value: int) -> TerrainData:
	var terrain: TerrainData = TerrainData.new()
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var side: int = terrain.vertex_side()
	for iz: int in side:
		for ix: int in side:
			var x: float = float(ix) - 60.0
			var z: float = float(iz) - 60.0
			var dist: float = Vector2(x, z).length()
			var f_center: float = smoothstep(CENTER_FLAT_RADIUS, 45.0, dist)
			var h: float = noise.get_noise_2d(x, z) * 2.2 * f_center
			# Colina suave en el noreste (pico ~4 m con la base del ruido)
			var hill_d2: float = pow(x - HILL_CENTER.x, 2.0) + pow(z - HILL_CENTER.y, 2.0)
			h += 3.4 * exp(-hill_d2 / (2.0 * 14.0 * 14.0))
			# Borde oeste: aplanar hacia el cauce y deprimir el canal
			var f_west: float = smoothstep(44.0, 52.0, -x)
			h = lerpf(h, 0.15, f_west)
			var channel_center: float = -54.0 + sin(z * 0.05) * 2.5
			var dx: float = x - channel_center
			h -= 1.3 * exp(-dx * dx / 8.0) * f_west
			# Camino de tierra: sur (z=60) hasta el centro
			var path_x: float = sin(z * 0.045) * 3.0
			var d_path: float = absf(x - path_x)
			var path_w: float = exp(-d_path * d_path / (2.0 * 1.5 * 1.5))
			path_w *= smoothstep(-4.0, 0.0, z)
			h = lerpf(h, h * 0.35, path_w)
			h = clampf(h, -1.6, 4.0)
			var idx: int = terrain.index_of(ix, iz)
			terrain.heights[idx] = h
			terrain.path_mask[idx] = clampf(path_w * 1.35, 0.0, 1.0)
	return terrain


static func _spawn_terrain_nodes(parent: Node3D, terrain: TerrainData, _seed_value: int) -> void:
	var palette: PaletteData = PaletteData.get_default()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = _build_terrain_mesh(terrain)
	mesh_instance.material_override = _terrain_material(palette)
	body.add_child(mesh_instance)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "TerrainCollision"
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = terrain.vertex_side()
	shape.map_depth = terrain.vertex_side()
	shape.map_data = terrain.heights
	collision.shape = shape
	body.add_child(collision)

	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Water"
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(13.0, 118.0)
	water.mesh = water_mesh
	water.position = Vector3(-53.0, WATER_LEVEL, 0.0)
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = Color(palette.water, 0.78)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.2
	water_mat.metallic = 0.0
	water.material_override = water_mat
	parent.add_child(water)


static func _build_terrain_mesh(terrain: TerrainData) -> ArrayMesh:
	var side: int = terrain.vertex_side()
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.resize(side * side)
	normals.resize(side * side)
	colors.resize(side * side)
	for iz: int in side:
		for ix: int in side:
			var idx: int = terrain.index_of(ix, iz)
			var x: float = float(ix) - 60.0
			var z: float = float(iz) - 60.0
			verts[idx] = Vector3(x, terrain.heights[idx], z)
			var hl: float = terrain.height_at(ix - 1, iz)
			var hr: float = terrain.height_at(ix + 1, iz)
			var hd: float = terrain.height_at(ix, iz - 1)
			var hu: float = terrain.height_at(ix, iz + 1)
			normals[idx] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			colors[idx] = Color(terrain.path_mask[idx], 0.0, 0.0)
	for iz: int in side - 1:
		for ix: int in side - 1:
			var i00: int = terrain.index_of(ix, iz)
			var i10: int = terrain.index_of(ix + 1, iz)
			var i01: int = terrain.index_of(ix, iz + 1)
			var i11: int = terrain.index_of(ix + 1, iz + 1)
			# Winding horario visto desde arriba (cara frontal en Godot)
			indices.append_array([i00, i10, i01, i10, i11, i01])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _terrain_material(palette: PaletteData) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain_blend.gdshader")
	mat.set_shader_parameter(&"grass_color", palette.grass)
	mat.set_shader_parameter(&"grass_light_color", palette.grass_light)
	mat.set_shader_parameter(&"dirt_color", palette.dirt)
	mat.set_shader_parameter(&"dirt_light_color", palette.dirt_light)
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	var tex_noise: FastNoiseLite = FastNoiseLite.new()
	tex_noise.seed = 4242
	tex_noise.frequency = 0.008
	noise_tex.noise = tex_noise
	noise_tex.seamless = true
	mat.set_shader_parameter(&"noise_tex", noise_tex)
	return mat


static func _spawn_props(
	parent: Node3D, terrain: TerrainData, rng: RandomNumberGenerator
) -> Dictionary:
	var props: Node3D = Node3D.new()
	props.name = "Props"
	parent.add_child(props)

	var counts: Dictionary = {
		"trees_adult": 0,
		"trees_young": 0,
		"rocks_big": 0,
		"rocks_small": 0,
		"flowers": 0,
		"bushes": 0,
	}
	var points: Array[Vector2] = Poisson.sample(Vector2(112.0, 112.0), 4.0, rng)
	# Fisher-Yates determinista: sin esto, Bridson agrupa las primeras
	# muestras (y por tanto los árboles) alrededor del punto inicial.
	for i: int in range(points.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = points[i]
		points[i] = points[j]
		points[j] = tmp
	for point: Vector2 in points:
		var x: float = point.x - 56.0
		var z: float = point.y - 56.0
		var dist: float = Vector2(x, z).length()
		var slope: float = terrain.get_slope_deg(x, z)
		var on_path: bool = terrain.get_path_mask(x, z) > 0.22
		var in_water: bool = x < -46.0
		var h: float = terrain.get_height(x, z)
		if in_water or on_path or slope > 22.0:
			continue
		if counts["trees_adult"] < TREES_ADULT and dist > 10.0:
			_place_tree(props, rng, x, h, z, false)
			counts["trees_adult"] += 1
		elif counts["trees_young"] < TREES_YOUNG and dist > 8.0:
			_place_tree(props, rng, x, h, z, true)
			counts["trees_young"] += 1
		elif counts["rocks_big"] < ROCKS_BIG and dist > 7.0:
			_place_big_rock(props, rng, x, h, z)
			counts["rocks_big"] += 1
		elif counts["rocks_small"] < ROCKS_SMALL and dist > 5.0:
			var small: MeshInstance3D = PropGen.rock(rng.randi(), false)
			_place_visual(props, small, rng, x, h - 0.06, z)
			counts["rocks_small"] += 1
		elif counts["bushes"] < BUSHES and dist > 6.0:
			var bush: Node3D = PropGen.bush(rng.randi())
			_place_visual(props, bush, rng, x, h, z)
			counts["bushes"] += 1
		elif counts["flowers"] < FLOWER_PATCHES and dist > 6.0 and slope < 10.0:
			var flowers: Node3D = PropGen.flower_patch(rng.randi())
			_place_visual(props, flowers, rng, x, h, z)
			counts["flowers"] += 1
	if counts["trees_adult"] < TREES_ADULT or counts["flowers"] < FLOWER_PATCHES:
		push_error("MapGenerator: distribución incompleta: %s" % str(counts))

	_place_campfire(props, rng, terrain)
	_place_cart(props, rng, terrain)
	counts["campfire"] = 1
	counts["cart"] = 1
	return counts


static func _place_tree(
	props: Node3D, rng: RandomNumberGenerator, x: float, h: float, z: float, young: bool
) -> void:
	var tree: TreeEntity = TreeEntity.create(rng.randi(), young)
	tree.position = Vector3(x, h - 0.03, z)
	tree.rotation.y = rng.randf() * TAU
	tree.scale = Vector3.ONE * rng.randf_range(0.88, 1.12)
	props.add_child(tree)


static func _place_big_rock(
	props: Node3D, rng: RandomNumberGenerator, x: float, h: float, z: float
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "BigRock"
	body.collision_layer = 1 << 5
	body.collision_mask = 0
	var visual: MeshInstance3D = PropGen.rock(rng.randi(), true)
	body.add_child(visual)
	var radius: float = float(visual.get_meta(&"radius", 0.7))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius * 0.95
	shape.shape = sphere
	shape.position = Vector3(0.0, radius * 0.3, 0.0)
	body.add_child(shape)
	body.position = Vector3(x, h - radius * 0.2, z)
	body.rotation.y = rng.randf() * TAU
	body.scale = Vector3.ONE * rng.randf_range(0.95, 1.25)
	body.add_to_group(&"rocks_big")
	props.add_child(body)


static func _place_visual(
	props: Node3D, node: Node3D, rng: RandomNumberGenerator, x: float, h: float, z: float
) -> void:
	node.position = Vector3(x, h, z)
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * rng.randf_range(0.88, 1.12)
	props.add_child(node)


static func _place_campfire(
	props: Node3D, rng: RandomNumberGenerator, terrain: TerrainData
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CampfireBody"
	body.collision_layer = (1 << 5) | (1 << 7)
	body.collision_mask = 0
	body.add_child(PropGen.campfire(rng.randi()))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	# 1.35 ≈ agujero del navmesh − radio del agente: elimina la franja
	# pisable-pero-sin-navmesh donde el RVO empujaba a los habitantes
	cylinder.radius = 1.35
	cylinder.height = 0.8
	shape.shape = cylinder
	shape.position = Vector3(0.0, 0.4, 0.0)
	body.add_child(shape)
	# RVO: sin esto los habitantes se empujan unos a otros contra la fogata.
	# CLAVE: disco RVO + radio del agente (0.35) DEBE caber dentro del
	# agujero del navmesh (~1.45), o veta los caminos que lo bordean.
	var fire_obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	fire_obstacle.radius = 1.0
	fire_obstacle.avoidance_enabled = true
	body.add_child(fire_obstacle)
	body.position = Vector3(0.0, terrain.get_height(0.0, 0.0), 0.0)
	body.add_to_group(&"campfire")
	body.add_to_group(&"selectable")
	props.add_child(body)


static func _place_cart(props: Node3D, rng: RandomNumberGenerator, terrain: TerrainData) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CartBody"
	body.collision_layer = (1 << 5) | (1 << 7)
	body.collision_mask = 0
	body.add_child(PropGen.cart(rng.randi()))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	# Crecido hasta casar con el agujero del navmesh (mismo motivo que la fogata)
	box.size = Vector3(3.2, 1.4, 2.3)
	shape.shape = box
	shape.position = Vector3(0.0, 0.7, 0.0)
	body.add_child(shape)
	# Mismo criterio que la fogata: dentro del agujero (lado corto ~1.35)
	var cart_obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	cart_obstacle.radius = 1.0
	cart_obstacle.avoidance_enabled = true
	body.add_child(cart_obstacle)
	var angle: float = rng.randf() * TAU
	var x: float = cos(angle) * 4.0
	var z: float = sin(angle) * 4.0
	body.position = Vector3(x, terrain.get_height(x, z), z)
	body.rotation.y = PI - angle
	body.add_to_group(&"storage")
	body.add_to_group(&"selectable")
	props.add_child(body)
