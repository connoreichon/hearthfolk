extends SceneTree
## Censo de biomas del seed de la sonda visual: cuántos puntos de cada bioma
## hay en una rejilla de 12 m — para calibrar umbrales y escáneres.


func _initialize() -> void:
	var world_gen: WorldGen = WorldGen.new(4242)
	var counts: Dictionary = {}
	var arid_max: float = 0.0
	var beach_max: float = 0.0
	var step: float = 12.0
	var half: int = int(world_gen.map_half)
	var x: float = -float(half) + 6.0
	while x < float(half):
		var z: float = -float(half) + 6.0
		while z < float(half):
			var b: int = world_gen.biome(x, z)
			counts[b] = int(counts.get(b, 0)) + 1
			arid_max = maxf(arid_max, world_gen.arid_weight(x, z))
			beach_max = maxf(beach_max, world_gen.beach_weight(x, z))
			z += step
		x += step
	for b: int in counts:
		print("BIOMA %d (%s): %d" % [b, WorldGen.Biome.keys()[b], counts[b]])
	print("arid_max=%.2f beach_max=%.2f" % [arid_max, beach_max])
	quit(0)
