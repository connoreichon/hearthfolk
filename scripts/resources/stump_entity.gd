class_name StumpEntity
extends Node3D
## Tocón persistente tras la tala. No bloquea la navegación.

var entity_id: int = 0
var visual_seed: int = 0


static func create(seed_value: int) -> StumpEntity:
	var stump: StumpEntity = StumpEntity.new()
	stump.name = "Stump"
	stump.visual_seed = seed_value
	stump.add_to_group(&"persistent")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	# Tocón modelado (glb) con corte de madera clara y raíces
	var variant: String = "stump_a" if rng.randf() < 0.5 else "stump_b"
	var base: MeshInstance3D = PropGen.prop_instance(variant, 0.0, 1.0, 0.0, 1.0)
	base.name = "Base"
	base.rotation.y = rng.randf() * TAU
	base.scale = Vector3.ONE * rng.randf_range(0.85, 1.1)
	stump.add_child(base)
	return stump


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"stump")


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func entity_kind() -> StringName:
	return &"stump"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"seed": visual_seed,
		"pos": [global_position.x, global_position.y, global_position.z],
	}


func load_data(d: Dictionary) -> void:
	visual_seed = int(d.get("seed", 0))
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
