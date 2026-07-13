class_name TreeEntity
extends StaticBody3D
## Árbol persistente: adulto talable (P4) o joven decorativo.

var entity_id: int = 0
var visual_seed: int = 0
var young: bool = false
var hp: int = 10
var marked: bool = false
var felled: bool = false


static func create(seed_value: int, is_young: bool) -> TreeEntity:
	var tree: TreeEntity = TreeEntity.new()
	tree.name = "TreeYoung" if is_young else "Tree"
	tree.visual_seed = seed_value
	tree.young = is_young
	tree.collision_layer = (1 << 2) | (1 << 7)
	tree.collision_mask = 0
	tree.add_child(TreeGen.build_visual(seed_value, is_young))
	tree.add_child(TreeGen.trunk_collision_shape(is_young))
	tree.add_to_group(&"trees")
	tree.add_to_group(&"persistent")
	tree.add_to_group(&"selectable")
	return tree


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"tree")


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func entity_kind() -> StringName:
	return &"tree"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"seed": visual_seed,
		"young": young,
		"hp": hp,
		"marked": marked,
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot_y": rotation.y,
		"scale": scale.x,
	}


func load_data(d: Dictionary) -> void:
	visual_seed = int(d.get("seed", 0))
	young = bool(d.get("young", false))
	hp = int(d.get("hp", 10))
	marked = bool(d.get("marked", false))
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(d.get("rot_y", 0.0))
	scale = Vector3.ONE * float(d.get("scale", 1.0))
