extends Node
## Serialización por IDs estables. Formato JSON con versión y migraciones.
## La lógica de reconstrucción del mundo se conecta en P7.

const SAVE_PATH: String = "user://save_001.json"
const FORMAT_VERSION: int = 1


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
	return data
