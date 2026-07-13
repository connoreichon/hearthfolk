class_name Poisson
## Poisson Disk Sampling (Bridson) determinista sobre un rectángulo.

const ATTEMPTS: int = 24


static func sample(size: Vector2, min_dist: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var cell: float = min_dist / sqrt(2.0)
	var grid_w: int = int(ceil(size.x / cell))
	var grid_h: int = int(ceil(size.y / cell))
	var grid: Array[int] = []
	grid.resize(grid_w * grid_h)
	grid.fill(-1)
	var points: Array[Vector2] = []
	var active: Array[int] = []

	var first: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
	points.append(first)
	active.append(0)
	grid[_cell_index(first, cell, grid_w)] = 0

	while not active.is_empty():
		var pick: int = rng.randi_range(0, active.size() - 1)
		var base: Vector2 = points[active[pick]]
		var placed: bool = false
		for _try: int in ATTEMPTS:
			var ang: float = rng.randf() * TAU
			var dist: float = min_dist * (1.0 + rng.randf())
			var candidate: Vector2 = base + Vector2(cos(ang), sin(ang)) * dist
			if candidate.x < 0.0 or candidate.y < 0.0:
				continue
			if candidate.x >= size.x or candidate.y >= size.y:
				continue
			if not _far_enough(candidate, points, grid, cell, grid_w, grid_h, min_dist):
				continue
			points.append(candidate)
			active.append(points.size() - 1)
			grid[_cell_index(candidate, cell, grid_w)] = points.size() - 1
			placed = true
		if not placed:
			active.remove_at(pick)
	return points


static func _cell_index(p: Vector2, cell: float, grid_w: int) -> int:
	return int(p.y / cell) * grid_w + int(p.x / cell)


static func _far_enough(
	candidate: Vector2,
	points: Array[Vector2],
	grid: Array[int],
	cell: float,
	grid_w: int,
	grid_h: int,
	min_dist: float
) -> bool:
	var cx: int = int(candidate.x / cell)
	var cy: int = int(candidate.y / cell)
	for gy: int in range(maxi(cy - 2, 0), mini(cy + 3, grid_h)):
		for gx: int in range(maxi(cx - 2, 0), mini(cx + 3, grid_w)):
			var idx: int = grid[gy * grid_w + gx]
			if idx == -1:
				continue
			if points[idx].distance_to(candidate) < min_dist:
				return false
	return true
