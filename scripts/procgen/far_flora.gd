class_name FarFlora
extends Node3D
## Los BOSQUES DEL MUNDO ENTERO desde el primer frame (orden del dueño):
## árboles visuales por MultiMesh — sin colisión, sin IDs, sin coste de
## nodos — cubriendo TODO el mapa antes incluso de sembrar colonos.
## Cuando un chunk real se activa, sus instancias se encogen a cero y los
## árboles-entidad (talables) toman el relevo en esa celda.

const CELL: float = 64.0
## Rejilla de muestreo por celda: paso ~8 m con jitter (≈ mirada de lejos
## del Poisson real; el canon de cerca lo pone TerrainChunk.populate).
const GRID: int = 8

## Vector2i celda → Array[Dictionary {model: String, index: int}]
var _cells: Dictionary = {}
## model_name → Array[MultiMeshInstance3D] (una por pieza del gltf)
var _instances: Dictionary = {}


static func create(world_gen: WorldGen) -> FarFlora:
	var flora: FarFlora = FarFlora.new()
	flora.name = "FarFlora"
	var chunks_per_side: int = int(ceil(world_gen.map_half * 2.0 / CELL))
	var first: int = -chunks_per_side / 2
	# 1º muestreo: transforms por modelo + pertenencia por celda
	var by_model: Dictionary = {}
	for cz: int in range(first, first + chunks_per_side):
		for cx: int in range(first, first + chunks_per_side):
			flora._sample_cell(world_gen, Vector2i(cx, cz), by_model)
	# 2º volcado: un MultiMesh por (modelo, pieza), compartiendo índice
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
			# Sin sombra: es vestuario de lejos; la sombra la ponen los
			# árboles reales de los chunks activos.
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flora.add_child(instance)
			mm_list.append(instance)
		flora._instances[model_name] = mm_list
	return flora


## El chunk real ha llegado: sus árboles visuales se retiran (escala 0).
func hide_cell(coord: Vector2i) -> void:
	var members: Array = _cells.get(coord, [])
	if members.is_empty():
		return
	var zero: Transform3D = Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -50, 0))
	for member: Dictionary in members:
		var mm_list: Array[MultiMeshInstance3D] = _instances.get(
			member["model"], [] as Array[MultiMeshInstance3D]
		)
		for instance: MultiMeshInstance3D in mm_list:
			instance.multimesh.set_instance_transform(int(member["index"]), zero)
	_cells.erase(coord)


func _sample_cell(world_gen: WorldGen, coord: Vector2i, by_model: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GameState.derive_seed(["farflora", coord.x, coord.y])
	var origin_x: float = float(coord.x) * CELL
	var origin_z: float = float(coord.y) * CELL
	var step: float = CELL / float(GRID)
	var members: Array = []
	for gz: int in GRID:
		for gx: int in GRID:
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
	if not members.is_empty():
		_cells[coord] = members
