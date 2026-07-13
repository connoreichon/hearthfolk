extends SceneTree
## Sonda de desarrollo: relación entre winding y normales en meshes de Godot.


func _initialize() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var arrays: Array = plane.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var a: Vector3 = verts[indices[0]]
	var b: Vector3 = verts[indices[1]]
	var c: Vector3 = verts[indices[2]]
	var cross: Vector3 = (b - a).cross(c - a)
	print("PlaneMesh tri0: a=%s b=%s c=%s" % [a, b, c])
	print(
		(
			"cross=%s  normal_almacenada=%s  dot=%f"
			% [cross, normals[indices[0]], cross.dot(normals[indices[0]])]
		)
	)
	var box: ArrayMesh = MeshLib.beveled_box(Vector3(1, 1, 1), 0.1)
	var st_arrays: Array = box.surface_get_arrays(0)
	var bverts: PackedVector3Array = st_arrays[Mesh.ARRAY_VERTEX]
	var bnormals: PackedVector3Array = st_arrays[Mesh.ARRAY_NORMAL]
	var ba: Vector3 = bverts[0]
	var bb: Vector3 = bverts[1]
	var bc: Vector3 = bverts[2]
	var bcross: Vector3 = (bb - ba).cross(bc - ba)
	print("BeveledBox tri0: centro=%s" % [(ba + bb + bc) / 3.0])
	print("cross=%s  normal_generada=%s  dot=%f" % [bcross, bnormals[0], bcross.dot(bnormals[0])])
	quit(0)
