extends Node
## Guardado/carga por IDs estables (§14). Las tareas NO se persisten:
## se regeneran desde la realidad del mundo al cargar. Autosave cada 60 s
## reales (no corre en pausa).

const SAVE_PATH: String = "user://save_001.json"
const FORMAT_VERSION: int = 1
const AUTOSAVE_SECONDS: float = 60.0

var _autosave_timer: float = 0.0


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
	return {
		"format_version": FORMAT_VERSION,
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


func save_game() -> void:
	if write_save(capture()):
		EventBus.game_saved.emit(1)
		EventBus.toast.emit("Partida guardada", &"success")


func load_game() -> bool:
	var data: Dictionary = read_save()
	if data.is_empty():
		EventBus.toast.emit("No hay partida guardada", &"warn")
		return false
	var worlds: Array[Node] = get_tree().get_nodes_in_group(&"world")
	if worlds.is_empty():
		return false
	worlds[0].call(&"rebuild_from_save", data)
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty() and data.has("camera"):
		rigs[0].call(&"set_state", data["camera"])
	EventBus.game_loaded.emit(1)
	EventBus.toast.emit("Partida cargada", &"success")
	return true


func write_save(data: Dictionary) -> bool:
	data["format_version"] = FORMAT_VERSION
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo abrir %s para escribir" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: no se pudo abrir %s para leer" % SAVE_PATH)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: JSON inválido en %s" % SAVE_PATH)
		return {}
	return migrate(parsed as Dictionary)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Migraciones incrementales. Un campo que falte se rellena con su valor
## por defecto; nunca debe romper la carga.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("format_version", 1))
	match version:
		1:
			pass
		_:
			push_warning("SaveManager: versión de guardado desconocida %d" % version)
	data["format_version"] = FORMAT_VERSION
	if not data.has("entities"):
		data["entities"] = []
	if not data.has("inventory"):
		data["inventory"] = {"wood": 0, "food": 0, "tools": 0}
	return data
