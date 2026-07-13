class_name StatusIcon
extends Node3D
## Icono de estado sobre la cabeza (§5.5): mini-mesh vectorial orientado a
## cámara. Se desvanece si la cámara está lejos.

const FADE_DISTANCE: float = 32.0

var _icons: Dictionary = {}
var _current: StringName = &""


func _ready() -> void:
	var palette: PaletteData = PaletteData.get_default()
	_icons[&"Harvest"] = _make_axe(palette)
	_icons[&"CarryResource"] = _make_bundle(palette)
	_icons[&"DeliverResource"] = _icons[&"CarryResource"]
	_icons[&"Build"] = _make_hammer(palette)
	_icons[&"Eat"] = _make_bread(palette)
	_icons[&"Rest"] = _make_moon(palette)
	_icons[&"RecoverFromStuck"] = _make_question(palette)
	for key: StringName in _icons:
		var icon: Node3D = _icons[key]
		if icon.get_parent() == null:
			icon.visible = false
			add_child(icon)


func show_for_state(state: StringName) -> void:
	_current = state
	for key: StringName in _icons:
		(_icons[key] as Node3D).visible = false
	if _icons.has(state):
		(_icons[state] as Node3D).visible = true


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var dist: float = camera.global_position.distance_to(global_position)
	visible = dist < FADE_DISTANCE and _icons.has(_current)
	if visible:
		var flat: Vector3 = camera.global_position
		flat.y = global_position.y
		if flat.distance_squared_to(global_position) > 0.01:
			look_at(flat, Vector3.UP)


func _make_axe(palette: PaletteData) -> Node3D:
	var icon: Node3D = Node3D.new()
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.022, 0.02, 0.3, 6), palette.wood_light, "Handle"
	)
	handle.position = Vector3(0.0, -0.15, 0.0)
	icon.add_child(handle)
	var head: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.16, 0.09, 0.03), 0.012), palette.accent, "Head"
	)
	head.position = Vector3(0.05, 0.09, 0.0)
	icon.add_child(head)
	return icon


func _make_bundle(palette: PaletteData) -> Node3D:
	var icon: Node3D = Node3D.new()
	for i: int in 2:
		var wood_log: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.log_cylinder(0.035, 0.3, 6), palette.wood_light, "Log%d" % i
		)
		wood_log.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		wood_log.position = Vector3(0.15, float(i) * 0.075 - 0.04, 0.0)
		icon.add_child(wood_log)
	return icon


func _make_hammer(palette: PaletteData) -> Node3D:
	var icon: Node3D = Node3D.new()
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.02, 0.018, 0.26, 6), palette.wood_light, "Handle"
	)
	handle.position = Vector3(0.0, -0.13, 0.0)
	icon.add_child(handle)
	var head: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.07, 0.16, 0.07), 0.015), palette.stone, "Head"
	)
	head.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	head.position = Vector3(0.0, 0.06, 0.0)
	icon.add_child(head)
	return icon


func _make_bread(palette: PaletteData) -> Node3D:
	var icon: Node3D = Node3D.new()
	var loaf: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.13, 5, 8, 0.6),
		palette.cart_cloth.lerp(palette.dirt_light, 0.5),
		"Loaf"
	)
	icon.add_child(loaf)
	return icon


func _make_moon(palette: PaletteData) -> Node3D:
	var icon: Node3D = Node3D.new()
	var moon: MeshInstance3D = MeshInstance3D.new()
	moon.name = "Moon"
	moon.mesh = MeshLib.low_sphere(0.11, 6, 10, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = palette.warm_light
	moon.material_override = mat
	icon.add_child(moon)
	var shade: MeshInstance3D = MeshInstance3D.new()
	shade.name = "Shade"
	shade.mesh = MeshLib.low_sphere(0.1, 6, 10, 1.0)
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = palette.night
	shade.material_override = dark
	shade.position = Vector3(0.06, 0.03, 0.03)
	icon.add_child(shade)
	return icon


func _make_question(palette: PaletteData) -> Node3D:
	var icon: Node3D = Node3D.new()
	var label: Label3D = Label3D.new()
	label.text = "?"
	label.font_size = 96
	label.outline_size = 18
	label.modulate = palette.accent
	label.outline_modulate = palette.ui_panel
	icon.add_child(label)
	return icon
