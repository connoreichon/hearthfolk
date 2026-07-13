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
	var palette: PaletteData = PaletteData.get_default()
	var trunk: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.22, 0.2, 0.28, 8, 1, 0.08, rng), palette.wood, "Base"
	)
	stump.add_child(trunk)
	# Anillos: tapa superior más clara
	var rings: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.16, 0.155, 0.02, 8), palette.wood_light, "Rings"
	)
	rings.position = Vector3(0.0, 0.275, 0.0)
	stump.add_child(rings)
	var core: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.08, 0.075, 0.022, 8), palette.wood, "Core"
	)
	core.position = Vector3(0.0, 0.277, 0.0)
	stump.add_child(core)
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
