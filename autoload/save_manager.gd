extends Node
## Guardado/carga por IDs estables (§14). Las tareas NO se persisten:
## se regeneran desde la realidad del mundo al cargar. Autosave cada 60 s
## reales (no corre en pausa).

## v2 = mundo gigante por chunks con IDs de árbol deterministas (S1).
const FORMAT_VERSION: int = 2
const MIN_SUPPORTED_VERSION: int = 2
const AUTOSAVE_SECONDS: float = 60.0
const SLOTS: int = 3

var active_slot: int = 1

var _autosave_timer: float = 0.0


func slot_path(slot: int) -> String:
	return "user://save_%03d.json" % slot


func _process(delta: float) -> void:
	if SimClock.speed == SimClock.Speed.PAUSED:
		return
	if get_tree().get_nodes_in_group(&"world").is_empty():
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()


## Captura el estado completo del mundo en un Dictionary serializable.
func capture() -> Dictionary:
	var entities: Array = []
	for node: Node in get_tree().get_nodes_in_group(&"persistent"):
		if IPersistent.implemented_by(node):
			entities.append(
				{"kind": String(node.call(&"entity_kind")), "data": node.call(&"save_data")}
			)
	var camera_state: Dictionary = {}
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty():
		camera_state = rigs[0].call(&"get_state")
	var milestone_state: Array = []
	var milestone_nodes: Array[Node] = get_tree().get_nodes_in_group(&"milestones")
	if not milestone_nodes.is_empty():
		milestone_state = milestone_nodes[0].call(&"save_state")
	return {
		"format_version": FORMAT_VERSION,
		"milestones": milestone_state,
		"seed": GameState.world_seed,
		"day": SimClock.day,
		"time_of_day": SimClock.time_of_day,
		"speed": SimClock.speed,
		"inventory":
		{
			"wood": GameState.get_resource(&"wood"),
			"food": GameState.get_resource(&"food"),
			"tools": GameState.get_resource(&"tools"),
		},
		"camera": camera_state,
		"entities": entities,
	}


func save_game(slot: int = -1) -> void:
	if slot > 0:
		active_slot = slot
	if write_save(capture()):
		EventBus.game_saved.emit(active_slot)
		EventBus.toast.emit("Partida guardada (slot %d)" % active_slot, &"success")


func load_game(slot: int = -1) -> bool:
	if slot > 0:
		active_slot = slot
	var data: Dictionary = read_save()
	if data.is_empty():
		EventBus.toast.emit("No hay partida guardada", &"warn")
		return false
	if int(data.get("format_version", 1)) < MIN_SUPPORTED_VERSION:
		EventBus.toast.emit(
			"Guardado de una versión antigua del mundo: empieza una partida nueva", &"warn"
		)
		return false
	var worlds: Array[Node] = get_tree().get_nodes_in_group(&"world")
	if worlds.is_empty():
		return false
	worlds[0].call(&"rebuild_from_save", data)
	var milestone_nodes: Array[Node] = get_tree().get_nodes_in_group(&"milestones")
	if not milestone_nodes.is_empty():
		milestone_nodes[0].call(&"load_state", data.get("milestones", []))
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty() and data.has("camera"):
		rigs[0].call(&"set_state", data["camera"])
	EventBus.game_loaded.emit(1)
	EventBus.toast.emit("Partida cargada", &"success")
	return true


func write_save(data: Dictionary, slot: int = -1) -> bool:
	var path: String = slot_path(active_slot if slot <= 0 else slot)
	data["format_version"] = FORMAT_VERSION
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo abrir %s para escribir" % path)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


func read_save(slot: int = -1) -> Dictionary:
	var path: String = slot_path(active_slot if slot <= 0 else slot)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: no se pudo abrir %s para leer" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: JSON inválido en %s" % path)
		return {}
	return migrate(parsed as Dictionary)


func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(slot_path(active_slot if slot <= 0 else slot))


## Resumen para el menú: día y estación del guardado, o vacío.
func slot_summary(slot: int) -> String:
	if not has_save(slot):
		return "Slot %d — vacío" % slot
	var data: Dictionary = read_save(slot)
	return "Slot %d — Día %d" % [slot, int(data.get("day", 1))]


## Migraciones incrementales. Un campo que falte se rellena con su valor
## por defecto; nunca debe romper la carga.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("format_version", 1))
	match version:
		1, 2:
			pass
		_:
			push_warning("SaveManager: versión de guardado desconocida %d" % version)
	data["format_version"] = FORMAT_VERSION
	if not data.has("entities"):
		data["entities"] = []
	if not data.has("inventory"):
		data["inventory"] = {"wood": 0, "food": 0, "tools": 0}
	return data
