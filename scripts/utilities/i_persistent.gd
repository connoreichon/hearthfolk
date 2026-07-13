class_name IPersistent
## Contrato de persistencia (duck typing: GDScript no tiene interfaces y las
## entidades heredan de CharacterBody3D/StaticBody3D, así que no pueden
## heredar de una clase común). Toda entidad persistente:
##   - implementa save_data() -> Dictionary (datos puros serializables a JSON)
##   - implementa load_data(d: Dictionary) -> void
##   - implementa entity_kind() -> StringName
##   - expone entity_id: int (asignado por EntityRegistry)
##   - pertenece al grupo "persistent"


static func implemented_by(node: Node) -> bool:
	return (
		node.has_method(&"save_data")
		and node.has_method(&"load_data")
		and node.has_method(&"entity_kind")
	)
