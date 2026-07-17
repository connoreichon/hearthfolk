class_name FarFlora
extends Node3D
## El MUNDO ENTERO VESTIDO desde el primer frame (orden del dueño): árboles
## Y hierba visuales por MultiMesh cubriendo TODO el mapa — misma densidad,
## mismos meshes y mismo material que los chunks reales, para que al
## activarse una zona NO SE NOTE el relevo (ni costuras ni calvas).
## Sin colisión, sin IDs, sin coste de nodos.

const CELL: float = 64.0
## Rejilla de árboles 16×16 (paso 4 m con jitter) ≈ el conteo del Poisson
## 3.9 de TerrainChunk.populate — la densidad de lejos y de cerca CASA.
const TREE_GRID: int = 16
## Matas por celda: mismas 1500 tiradas que _plant_grass (el canon).
const TUFT_TRIES: int = 1500

## Vector2i celda → Array[Dictionary {model: String, index: int} | {tuft: int}]
var _cells: Dictionary = {}
## model_name → Array[MultiMeshInstance3D] (una por pieza del gltf)
var _instances: Dictionary = {}
var _tufts: MultiMeshInstance3D
## Celdas activadas ANTES de terminar la generación: se ocultan al acabar.
var _hidden_early: Array[Vector2i] = []
var _world_gen: WorldGen
var _built: bool = false


static func create(world_gen: WorldGen) -> FarFlora:
	var flora: FarFlora = FarFlora.new()
	flora.name = "FarFlora"
	flora._world_gen = world_gen
	return flora


func _ready() -> void:
	_build_async.call_deferred()


## Generación REPARTIDA en frames: el jugador está eligiendo asentamiento
## sobre el mapa 2D mientras el valle termina de vestirse detrás — la
## partida abre ágil y la flora completa llega en un suspiro.
func _build_async() -> void:
	var chunks_per_side: int = int(ceil(_world_gen.map_half * 2.0 / CELL))
	var first: int = -chunks_per_side / 2
	var by_model: Dictionary = {}
	var tuft_transforms: Array[Transform3D] = []
	var tuft_colors: Array[Color] = []
	var tree: SceneTree = get_tree()
	var batch: int = 0
	for cz: int in range(first, first + chunks_per_side):
		for cx: int in range(first, first + chunks_per_side):
			_sample_cell(_world_gen, Vector2i(cx, cz), by_model, tuft_transforms, tuft_colors)
			batch += 1
			if batch % 24 == 0 and tree != null:
				await tree.process_frame
	if not is_inside_tree():
		return
	# Árboles: un MultiMesh por (modelo, pieza), compartiendo índice — CON
	# sombra, como los reales (la costura de sombras también cantaba).
	for model_name: String in by_model:
		var transforms: Array = by_model[model_name]
		var parts: Array[Dictionary] = TreeGen.model_parts(model_name)
		var mm_list: Array[MultiMeshInstance3D] = []
		for part: Dictionary in parts:
			var multi: MultiMesh = MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = part["mesh"]
			multi.instance_count = transforms.size()
			var local: Transform3D = part["xform"]
			for i: int in transforms.size():
				multi.set_instance_transform(i, (transforms[i] as Transform3D) * local)
			var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
			instance.name = "Far_%s_%d" % [model_name, mm_list.size()]
			instance.multimesh = multi
			add_child(instance)
			mm_list.append(instance)
		_instances[model_name] = mm_list
		if tree != null:
			await tree.process_frame
	# Hierba: EXACTAMENTE la mata y el material de los chunks reales.
	if not tuft_transforms.is_empty():
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = TerrainChunk._tuft_mesh()
		multi.instance_count = tuft_transforms.size()
		for i: int in tuft_transforms.size():
			multi.set_instance_transform(i, tuft_transforms[i])
			multi.set_instance_color(i, tuft_colors[i])
		_tufts = MultiMeshInstance3D.new()
		_tufts.name = "FarTufts"
		_tufts.multimesh = multi
		_tufts.material_override = TerrainChunk._grass_mat()
		_tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_tufts)
	_built = true
	# Chunks que despertaron durante la generación: retirar su flora ya
	for coord: Vector2i in _hidden_early:
		hide_cell(coord)
	_hidden_early.clear()


## El chunk real ha llegado: su flora visual se retira (escala ~0) y las
## entidades del chunk toman el relevo sin que se note el cambio.
func hide_cell(coord: Vector2i) -> void:
	if not _built:
		if not _hidden_early.has(coord):
			_hidden_early.append(coord)
		return
	var members: Array = _cells.get(coord, [])
	if members.is_empty():
		return
	var zero: Transform3D = Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -50, 0))
	for member: Dictionary in members:
		if member.has("tuft"):
			if _tufts != null:
				_tufts.multimesh.set_instance_transform(int(member["tuft"]), zero)
			continue
		var mm_list: Array[MultiMeshInstance3D] = _instances.get(
			member["model"], [] as Array[MultiMeshInstance3D]
		)
		for instance: MultiMeshInstance3D in mm_list:
			instance.multimesh.set_instance_transform(int(member["index"]), zero)
	_cells.erase(coord)


func _sample_cell(
	world_gen: WorldGen,
	coord: Vector2i,
	by_model: Dictionary,
	tuft_transforms: Array[Transform3D],
	tuft_colors: Array[Color]
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GameState.derive_seed(["farflora", coord.x, coord.y])
	var origin_x: float = float(coord.x) * CELL
	var origin_z: float = float(coord.y) * CELL
	var members: Array = []
	var step: float = CELL / float(TREE_GRID)
	for gz: int in TREE_GRID:
		for gx: int in TREE_GRID:
			var x: float = origin_x + (float(gx) + rng.randf()) * step
			var z: float = origin_z + (float(gz) + rng.randf()) * step
			var roll: float = rng.randf()
			if not world_gen.is_inside(x, z, 2.0):
				continue
			var which: int = world_gen.biome(x, z)
			var density: float = world_gen.tree_density(which)
			if which == WorldGen.Biome.SABANA and world_gen.river_mask(x, z) < 0.05:
				density = 0.0
			if roll >= 0.24 * density:
				continue
			var h: float = world_gen.height(x, z)
			if h < WorldGen.WATER_LEVEL + 0.15 or h > 8.0:
				continue
			var model_name: String = TreeGen.pick_model(rng, which == WorldGen.Biome.NIEVE)
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU)
			basis = basis.scaled(Vector3.ONE * rng.randf_range(0.85, 1.12))
			var xform: Transform3D = Transform3D(basis, Vector3(x, h - 0.03, z))
			if not by_model.has(model_name):
				by_model[model_name] = []
			var index: int = (by_model[model_name] as Array).size()
			(by_model[model_name] as Array).append(xform)
			members.append({"model": model_name, "index": index})
	_sample_cell_grass(world_gen, rng, origin_x, origin_z, members, tuft_transforms, tuft_colors)
	if not members.is_empty():
		_cells[coord] = members


## RÉPLICA de TerrainChunk._plant_grass (el canon de cerca): mismas
## densidades por bioma, misma escala y mismos tintes de clima — si aquello
## cambia, esto debe cambiar igual (la costura delataría la diferencia).
func _sample_cell_grass(
	world_gen: WorldGen,
	rng: RandomNumberGenerator,
	origin_x: float,
	origin_z: float,
	members: Array,
	tuft_transforms: Array[Transform3D],
	tuft_colors: Array[Color]
) -> void:
	var palette: PaletteData = PaletteData.get_default()
	for _i: int in TUFT_TRIES:
		var x: float = origin_x + rng.randf() * CELL
		var z: float = origin_z + rng.randf() * CELL
		if not world_gen.is_inside(x, z, 2.0):
			continue
		var which: int = world_gen.biome(x, z)
		var density: float = 1.0
		match which:
			WorldGen.Biome.BOSQUE:
				density = 0.62
			WorldGen.Biome.COLINAS:
				density = 0.45
			WorldGen.Biome.RIBERA:
				density = 0.8
			WorldGen.Biome.NIEVE:
				density = 0.22
			WorldGen.Biome.SABANA:
				density = 0.5
			WorldGen.Biome.PLAYA:
				density = 0.18
			WorldGen.Biome.DESIERTO:
				density = 0.02
		if rng.randf() > density:
			continue
		var h: float = world_gen.height(x, z)
		if h < WorldGen.WATER_LEVEL + 0.2:
			continue
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3.ONE * rng.randf_range(0.38, 0.72))
		var tuft: Color = palette.grass.darkened(0.06).lerp(palette.grass_light, rng.randf() * 0.4)
		var tint: float = world_gen.climate_tint(x, z)
		if tint > 0.5:
			tuft = tuft.lerp(Color("#C2A95C"), (tint - 0.5) * 2.0 * 0.85)
		elif tint < 0.5:
			tuft = tuft.lerp(Color("#7E8B76"), (0.5 - tint) * 2.0 * 0.7)
		members.append({"tuft": tuft_transforms.size()})
		tuft_transforms.append(Transform3D(basis, Vector3(x, h - 0.01, z)))
		tuft_colors.append(tuft.srgb_to_linear())
