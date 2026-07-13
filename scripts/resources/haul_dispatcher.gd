class_name HaulDispatcher
extends Node
## Publica tareas de transporte cuando aparece madera en el suelo.
## Al cargar partida, regenera las tareas desde la realidad del mundo.


func _ready() -> void:
	EventBus.resource_spawned.connect(_on_resource_spawned)
	for node: Node in get_tree().get_nodes_in_group(&"resources"):
		var item: ResourceItem = node as ResourceItem
		if item != null:
			_publish_for(item.entity_id)


func _on_resource_spawned(entity_id: int, _type: StringName, _position: Vector3) -> void:
	_publish_for(entity_id)


## Regenerar tareas de transporte desde el mundo (tras cargar partida).
func rescan() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"resources"):
		var item: ResourceItem = node as ResourceItem
		if item != null:
			_publish_for(item.entity_id)


func _publish_for(entity_id: int) -> void:
	if TaskBoard.first_task_for_target(entity_id) != null:
		return
	TaskBoard.publish(&"haul", entity_id, {}, 4)
