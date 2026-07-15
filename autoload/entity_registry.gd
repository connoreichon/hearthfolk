extends Node
## IDs estables para toda entidad persistente. El guardado solo referencia IDs.

var _next_id: int = 1
var _by_id: Dictionary = {}
var _kind_by_id: Dictionary = {}


func register(node: Node, kind: StringName) -> int:
	var entity_id: int = _next_id
	_next_id += 1
	_by_id[entity_id] = node
	_kind_by_id[entity_id] = kind
	return entity_id


## Registro con ID fijo, usado al cargar partida.
func register_with_id(node: Node, kind: StringName, entity_id: int) -> void:
	_by_id[entity_id] = node
	_kind_by_id[entity_id] = kind
	if entity_id >= _next_id:
		_next_id = entity_id + 1


func get_node_by_id(entity_id: int) -> Node:
	var node: Node = _by_id.get(entity_id)
	if node == null or not is_instance_valid(node):
		return null
	return node


## Reserva el espacio bajo `floor_id` para IDs deterministas (árboles por
## chunk): los IDs dinámicos (colonos, obras…) nacerán siempre por encima.
func reserve_below(floor_id: int) -> void:
	if _next_id < floor_id:
		_next_id = floor_id


func unregister(entity_id: int) -> void:
	_by_id.erase(entity_id)
	_kind_by_id.erase(entity_id)


func all_of_kind(kind: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for entity_id: int in _by_id:
		if _kind_by_id.get(entity_id) != kind:
			continue
		var node: Node = get_node_by_id(entity_id)
		if node != null:
			result.append(node)
	return result


func kind_of(entity_id: int) -> StringName:
	return _kind_by_id.get(entity_id, &"")


func count() -> int:
	return _by_id.size()


func clear() -> void:
	_by_id.clear()
	_kind_by_id.clear()
	_next_id = 1
