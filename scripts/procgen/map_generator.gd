class_name MapGenerator
## Servicios del mundo gigante (S1): material del terreno compartido por
## los chunks y plano de agua global. La forma vive en WorldGen y el suelo
## en TerrainChunk/ChunkManager; la vegetación nace por chunk según bioma.

const WATER_LEVEL: float = WorldGen.WATER_LEVEL

static var _shared_material: ShaderMaterial


## Material del terreno (compartido entre todos los chunks: 1 shader).
static func terrain_material(palette: PaletteData) -> ShaderMaterial:
	if _shared_material != null:
		return _shared_material
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
	_shared_material = mat
	return mat


## Plano de agua global al nivel del mar: se ve donde el terreno se hunde
## (la red de ríos tallada por WorldGen). Idempotente en recargas.
static func spawn_water(parent: Node3D, world_gen: WorldGen) -> void:
	var previous: Node = parent.get_node_or_null("Water")
	if previous != null:
		previous.free()
	var palette: PaletteData = PaletteData.get_default()
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Water"
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(world_gen.map_half * 2.0, world_gen.map_half * 2.0)
	water.mesh = water_mesh
	water.position = Vector3(0.0, WATER_LEVEL, 0.0)
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = Color(palette.water, 0.78)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.2
	water_mat.metallic = 0.0
	water.material_override = water_mat
	parent.add_child(water)
