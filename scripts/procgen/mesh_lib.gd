class_name MeshLib
## Primitivas procedurales biseladas y materiales mate compartidos (§5.2, §5.3).
## Todo flat-shaded; una caja nunca es una BoxMesh, es una caja biselada.

static var _materials: Dictionary = {}


static func matte(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.metallic_specular = 0.1
	_materials[key] = mat
	return mat


static func mesh_instance(mesh: Mesh, color: Color, node_name: String = "Mesh") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = matte(color)
	return mi


## Caja con chaflán en todas las aristas. size = dimensiones totales.
static func beveled_box(size: Vector3, bevel: float = 0.04) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: Vector3 = size * 0.5
	var b: float = minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	# 6 caras principales (insetadas por el bisel)
	for axis_i: int in 3:
		var u: Vector3 = axes[(axis_i + 1) % 3]
		var v: Vector3 = axes[(axis_i + 2) % 3]
		var hu: float = h[(axis_i + 1) % 3] - b
		var hv: float = h[(axis_i + 2) % 3] - b
		for sign_f: float in [-1.0, 1.0]:
			var n: Vector3 = axes[axis_i] * sign_f
			var c: Vector3 = n * h[axis_i]
			_quad_out(
				st,
				c - u * hu - v * hv,
				c + u * hu - v * hv,
				c + u * hu + v * hv,
				c - u * hu + v * hv,
				n
			)
	# 12 aristas (quads de chaflán)
	for pair: Array in [[0, 1], [1, 2], [2, 0]]:
		var a1: int = pair[0]
		var a2: int = pair[1]
		var a3: int = 3 - a1 - a2
		var n1: Vector3 = axes[a1]
		var n2: Vector3 = axes[a2]
		var t: Vector3 = axes[a3]
		var ht: float = h[a3] - b
		for s1: float in [-1.0, 1.0]:
			for s2: float in [-1.0, 1.0]:
				var e1: Vector3 = n1 * s1 * h[a1] + n2 * s2 * (h[a2] - b)
				var e2: Vector3 = n2 * s2 * h[a2] + n1 * s1 * (h[a1] - b)
				_quad_out(st, e1 - t * ht, e1 + t * ht, e2 + t * ht, e2 - t * ht, n1 * s1 + n2 * s2)
	# 8 esquinas (triángulos)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var px: Vector3 = Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))
				var py: Vector3 = Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))
				var pz: Vector3 = Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)
				_tri_out(st, px, py, pz, Vector3(sx, sy, sz))
	st.generate_normals()
	return st.commit()


## Tablón: caja biselada fina.
static func plank(size: Vector3) -> ArrayMesh:
	return beveled_box(size, 0.03)


## Cilindro/tronco flat-shaded con base en y=0. radius_noise perturba cada
## anillo (troncos orgánicos). deform opcional recibe y devuelve Vector3.
static func cylinder(
	radius_bottom: float,
	radius_top: float,
	height: float,
	segments: int = 10,
	rings: int = 1,
	radius_noise: float = 0.0,
	rng: RandomNumberGenerator = null,
	cap_bottom: bool = true,
	cap_top: bool = true
) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_points: Array = []
	for ring_i: int in rings + 1:
		var f: float = float(ring_i) / float(rings)
		var y: float = f * height
		var r: float = lerpf(radius_bottom, radius_top, f)
		var points: PackedVector3Array = PackedVector3Array()
		for seg: int in segments:
			var ang: float = TAU * float(seg) / float(segments)
			var rr: float = r
			if radius_noise > 0.0 and rng != null:
				rr = r * (1.0 + rng.randf_range(-radius_noise, radius_noise))
			points.append(Vector3(cos(ang) * rr, y, sin(ang) * rr))
		ring_points.append(points)
	for ring_i: int in rings:
		var low: PackedVector3Array = ring_points[ring_i]
		var high: PackedVector3Array = ring_points[ring_i + 1]
		for seg: int in segments:
			var nxt: int = (seg + 1) % segments
			var mid: Vector3 = (low[seg] + high[seg] + low[nxt] + high[nxt]) / 4.0
			var out: Vector3 = Vector3(mid.x, 0.0, mid.z)
			if out.length() < 0.001:
				out = Vector3.RIGHT
			_quad_out(st, low[seg], low[nxt], high[nxt], high[seg], out)
	if cap_bottom:
		var base: PackedVector3Array = ring_points[0]
		var center_b: Vector3 = Vector3(0.0, 0.0, 0.0)
		for seg: int in segments:
			_tri_out(st, center_b, base[seg], base[(seg + 1) % segments], Vector3.DOWN)
	if cap_top:
		var top: PackedVector3Array = ring_points[rings]
		var center_t: Vector3 = Vector3(0.0, height, 0.0)
		for seg: int in segments:
			_tri_out(st, center_t, top[seg], top[(seg + 1) % segments], Vector3.UP)
	st.generate_normals()
	return st.commit()


static func log_cylinder(radius: float, length: float, segments: int = 7) -> ArrayMesh:
	return cylinder(radius, radius * 0.92, length, segments)


## Esfera de baja resolución, flat-shaded, achatable, deformable.
static func low_sphere(
	radius: float,
	rings: int = 5,
	segments: int = 8,
	squash: float = 1.0,
	deform: Callable = Callable()
) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ring_i: int in rings + 1:
		var v_ang: float = PI * float(ring_i) / float(rings)
		var y: float = cos(v_ang) * radius * squash
		var ring_r: float = sin(v_ang) * radius
		var points: PackedVector3Array = PackedVector3Array()
		for seg: int in segments:
			var ang: float = TAU * float(seg) / float(segments)
			var p: Vector3 = Vector3(cos(ang) * ring_r, y, sin(ang) * ring_r)
			if deform.is_valid():
				p = deform.call(p)
			points.append(p)
		grid.append(points)
	for ring_i: int in rings:
		var low: PackedVector3Array = grid[ring_i + 1]
		var high: PackedVector3Array = grid[ring_i]
		for seg: int in segments:
			var nxt: int = (seg + 1) % segments
			var mid: Vector3 = (low[seg] + high[seg]) * 0.5
			if mid.length() < 0.001:
				mid = Vector3.UP
			if ring_i == 0:
				_tri_out(st, high[0], low[seg], low[nxt], mid)
			elif ring_i == rings - 1:
				_tri_out(st, high[seg], low[0], high[nxt], mid)
			else:
				_quad_out(st, high[seg], high[nxt], low[nxt], low[seg], mid)
	st.generate_normals()
	return st.commit()


static func cone(radius: float, height: float, segments: int = 8) -> ArrayMesh:
	return cylinder(radius, 0.02, height, segments, 1, 0.0, null, true, true)


## Cápsula suave (única primitiva no facetada permitida, para detalles).
static func capsule_smooth(radius: float, height: float) -> CapsuleMesh:
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	return capsule


static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot: cara frontal = winding horario → cross(b-a, c-a) OPUESTO a outward.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _quad_out(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3
) -> void:
	_tri_out(st, a, b, c, outward)
	_tri_out(st, a, c, d, outward)
