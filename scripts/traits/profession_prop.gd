class_name ProfessionProp
## Herramienta de oficio que el colono lleva a la espalda (§S2, «verlo
## todo»): el oficio se LEE en la figura sin abrir ningún menú. Primitivas
## biseladas como el resto del arte; nada de cápsulas.


## Nodo con la herramienta del oficio, ya orientado para colgar del
## soporte de la espalda. null para oficio vacío (recién nacido sin decidir).
static func build(profession: StringName) -> Node3D:
	match profession:
		&"lenador":
			return _axe()
		&"agricultor":
			return _hoe()
		&"constructor":
			return _mallet()
		&"recolector":
			return _basket()
		&"repoblador":
			return _spade()
		_:
			return null


static func _axe() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "ToolAxe"
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.022, 0.022, 0.58, 6), palette.wood, "Handle"
	)
	root.add_child(handle)
	var head: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.055, 0.14, 0.11), 0.015), palette.stone, "Head"
	)
	head.position = Vector3(0.045, 0.26, 0.0)
	head.rotation.z = deg_to_rad(-8.0)
	root.add_child(head)
	return root


static func _hoe() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "ToolHoe"
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.02, 0.02, 0.62, 6), palette.wood_light, "Handle"
	)
	root.add_child(handle)
	var blade: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.12, 0.07, 0.02), 0.01), palette.stone, "Blade"
	)
	blade.position = Vector3(0.0, 0.3, 0.06)
	blade.rotation.x = deg_to_rad(62.0)
	root.add_child(blade)
	return root


static func _mallet() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "ToolMallet"
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.022, 0.022, 0.5, 6), palette.wood, "Handle"
	)
	root.add_child(handle)
	var head: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.1, 0.1, 0.1), 0.02), palette.wood_light, "Head"
	)
	head.position = Vector3(0.0, 0.24, 0.0)
	root.add_child(head)
	return root


static func _spade() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "ToolSpade"
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.02, 0.02, 0.55, 6), palette.wood_light, "Handle"
	)
	root.add_child(handle)
	var blade: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.09, 0.13, 0.02), 0.012), palette.stone, "Blade"
	)
	blade.position = Vector3(0.0, -0.32, 0.0)
	root.add_child(blade)
	var grip: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.09, 0.03, 0.03), 0.01), palette.wood, "Grip"
	)
	grip.position = Vector3(0.0, 0.28, 0.0)
	root.add_child(grip)
	return root


static func _basket() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "ToolBasket"
	var body: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.1, 0.14, 0.2, 9), palette.cart_cloth, "Body"
	)
	root.add_child(body)
	var rim: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.145, 0.145, 0.03, 9), palette.wood_light, "Rim"
	)
	rim.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(rim)
	# Un par de bayas asomando: color de la brasa sagrada, guiño cálido
	var berry: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.03, 4, 6, 1.0), Color("#B4432F"), "Berry"
	)
	berry.position = Vector3(0.04, 0.11, 0.03)
	root.add_child(berry)
	return root
