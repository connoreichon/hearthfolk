extends SceneTree
## Runner headless propio:  godot --headless --path . -s tests/run_tests.gd
## Descubre tests/unit y tests/integration, ejecuta métodos test_* de cada
## HFTestCase y devuelve código de salida != 0 si algo falla.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]

var _total_methods: int = 0
var _total_checks: int = 0
var _all_failures: Array[String] = []


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	print("== Hearthfolk test runner ==")
	if not root.has_node("EventBus"):
		print("AVISO: autoloads no disponibles en este modo de ejecución")
	for dir_path: String in TEST_DIRS:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		var files: PackedStringArray = dir.get_files()
		files.sort()
		for file_name: String in files:
			if not file_name.ends_with(".gd"):
				continue
			await _run_script("%s/%s" % [dir_path, file_name])
	print("---")
	print(
		(
			"Métodos: %d  Comprobaciones: %d  Fallos: %d"
			% [_total_methods, _total_checks, _all_failures.size()]
		)
	)
	for failure: String in _all_failures:
		printerr("FALLO  " + failure)
	if _all_failures.is_empty():
		print("RESULTADO: OK")
	else:
		print("RESULTADO: FALLOS")
	quit(0 if _all_failures.is_empty() else 1)


func _run_script(path: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		_all_failures.append("%s: no se pudo cargar" % path)
		return
	var instance: Variant = script.new()
	if not instance is HFTestCase:
		return
	var test: HFTestCase = instance as HFTestCase
	print("- %s" % path.get_file())
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		_total_methods += 1
		test.current = "%s::%s" % [path.get_file(), method_name]
		test.before_each()
		await test.call(method_name)
		test.after_each()
	_total_checks += test.checks
	_all_failures.append_array(test.failures)
