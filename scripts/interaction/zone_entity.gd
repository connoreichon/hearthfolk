class_name ZoneEntity
extends Node3D
## Intención residencial confirmada: rectángulo persistente en el terreno.

var entity_id: int = 0
var rect: Rect2 = Rect2()


static func create(zone_rect: Rect2) -> ZoneEntity:
	var zone: ZoneEntity = ZoneEntity.new()
	zone.name = "Zone"
	zone.rect = zone_rect
	zone.add_to_group(&"zones")
	zone.add_to_group(&"persistent")
	zone._build_border()
	return zone


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"zone")


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func _build_border() -> void:
	var palette: PaletteData = PaletteData.get_default()
	var corners: Array[Vector2] = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	]
	for i: int in corners.size():
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % corners.size()]
		var length: float = from.distance_to(to)
		var edge: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.1, 0.05, length)), palette.accent, "Edge%d" % i
		)
		var mid: Vector2 = (from + to) * 0.5
		var y: float = 0.06
		if GameState.terrain != null:
			y = GameState.terrain.get_height(mid.x, mid.y) + 0.06
		edge.position = Vector3(mid.x, y, mid.y)
		edge.rotation.y = Vector2(to - from).angle() + PI * 0.5
		add_child(edge)


func entity_kind() -> StringName:
	return &"zone"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
	}


func load_data(d: Dictionary) -> void:
	var r: Array = d.get("rect", [0.0, 0.0, 6.0, 6.0])
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	_build_border()
