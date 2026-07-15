class_name HaulDispatcher
extends Node
## Publica tareas de transporte cuando aparece madera en el suelo.
## Regla del mundo gigante: NUNCA publicar un acarreo sin ruta real desde
## el almacén más cercano (madera caída al otro lado de un río convertía
## a los porteadores en peregrinos). Un repaso lento reintenta los items
## saltados cuando la navegación cambia (obras, futuros puentes).

const RESCAN_SECONDS: float = 20.0

var _rescan_timer: float = 0.0


func _ready() -> void:
	EventBus.resource_spawned.connect(_on_resource_spawned)
	SimClock.sim_tick.connect(_on_sim_tick)
	rescan()


func _on_resource_spawned(entity_id: int, _type: StringName, _position: Vector3) -> void:
	_publish_for(entity_id)


func _on_sim_tick(dt: float) -> void:
	if not is_inside_tree():
		return
	_rescan_timer -= dt
	if _rescan_timer > 0.0:
		return
	_rescan_timer = RESCAN_SECONDS
	rescan()


## Regenerar tareas de transporte desde el mundo (carga y repaso lento).
func rescan() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"resources"):
		var item: ResourceItem = node as ResourceItem
		if item != null:
			_publish_for(item.entity_id)


func _publish_for(entity_id: int) -> void:
	if TaskBoard.first_task_for_target(entity_id) != null:
		return
	var item: Node3D = EntityRegistry.get_node_by_id(entity_id) as Node3D
	if item == null or not item.is_inside_tree():
		return
	var storage: Node3D = CampEntity.nearest_storage_node(get_tree(), item.global_position)
	if storage != null:
		var world_3d: World3D = item.get_world_3d()
		if not NavUtil.is_practical(world_3d, storage.global_position, item.global_position, 2.5):
			return
	TaskBoard.publish(&"haul", entity_id, {}, 4)
