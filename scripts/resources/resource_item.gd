class_name ResourceItem
extends StaticBody3D
## Recurso físico en el suelo (§8.4). Un item = un haz de 1–2 unidades.
## Nada de "wood += 6" invisible: cada haz tiene posición, ID y persistencia.

var entity_id: int = 0
var resource_type: StringName = &"wood"
var amount: int = 2
var reserved_by: int = -1
var visual_seed: int = 0


static func create(type: StringName, units: int, seed_value: int) -> ResourceItem:
	var item: ResourceItem = ResourceItem.new()
	item.name = "ResourceItem"
	item.resource_type = type
	item.amount = units
	item.visual_seed = seed_value
	item.collision_layer = (1 << 3) | (1 << 7)
	item.collision_mask = 0
	item.add_to_group(&"resources")
	item.add_to_group(&"persistent")
	item.add_to_group(&"selectable")
	item.add_child(item._build_visual())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.7, 0.3, 0.5)
	shape.shape = box
	shape.position = Vector3(0.0, 0.15, 0.0)
	item.add_child(shape)
	return item


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"resource")
		EventBus.resource_spawned.emit(entity_id, resource_type, global_position)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func _build_visual() -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = visual_seed
	var palette: PaletteData = PaletteData.get_default()
	var root: Node3D = Node3D.new()
	root.name = "Visual"
	for log_i: int in amount:
		var wood_log: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.log_cylinder(0.09, 0.72, 7),
			palette.wood.lerp(palette.wood_light, rng.randf() * 0.6),
			"Log%d" % log_i
		)
		wood_log.rotation_degrees = Vector3(
			90.0 + rng.randf_range(-6.0, 6.0), rng.randf_range(-14.0, 14.0), 0.0
		)
		wood_log.position = Vector3(float(log_i) * 0.2 - 0.1, 0.09 + float(log_i) * 0.02, 0.36)
		root.add_child(wood_log)
	return root


func entity_kind() -> StringName:
	return &"resource"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"type": String(resource_type),
		"amount": amount,
		"seed": visual_seed,
		"pos": [global_position.x, global_position.y, global_position.z],
	}


func load_data(d: Dictionary) -> void:
	resource_type = StringName(String(d.get("type", "wood")))
	amount = int(d.get("amount", 2))
	visual_seed = int(d.get("seed", 0))
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
