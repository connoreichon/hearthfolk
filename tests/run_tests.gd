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
	# Filtro opcional (M0): HF_TEST_FILTER=haul corre solo los ficheros cuyo
	# nombre contenga la cadena — imprescindible para repetir un test 20×.
	var filter: String = OS.get_environment("HF_TEST_FILTER")
	for dir_path: String in TEST_DIRS:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		var files: PackedStringArray = dir.get_files()
		files.sort()
		for file_name: String in files:
			if not file_name.ends_with(".gd"):
				continue
			if not filter.is_empty() and not file_name.contains(filter):
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
	# M0: soltar los caches estáticos (materiales/meshes compartidos) para
	# que el runner salga sin «RID leaked» ni recursos en uso. Carga DINÁMICA:
	# el runner compila antes que los autoloads (modo -s) y una referencia
	# directa a la clase arrastraría medio juego a parse-time.
	var janitor: GDScript = load("res://scripts/utilities/resource_janitor.gd")
	janitor.call("release_static_caches")
	if root.has_node("AudioDirector"):
		root.get_node("AudioDirector").call("shutdown")
	# Drenaje: el hilo de audio suelta los playbacks al procesar su próximo
	# bloque; unos frames + una pausa corta dejan el recuento de ObjectDB
	# casi limpio (el resto es efímero de audio, sin fuga acumulativa).
	for _f: int in 5:
		await process_frame
	OS.delay_msec(150)
	await process_frame
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
		# await también en before/after: si el setup es asíncrono (espera
		# frames), sin await el método del test arrancaría a medio montar.
		await test.before_each()
		await test.call(method_name)
		await test.after_each()
	_total_checks += test.checks
	_all_failures.append_array(test.failures)
	# Guardia anti-fuga: un mundo vivo entre ficheros de test contamina a
	# todos los siguientes (visto en Build 003: un assert que abortaba
	# saltándose el free() coló 46 árboles fantasma en el round-trip).
	var residue: int = get_nodes_in_group(&"trees").size()
	if residue > 0:
		_all_failures.append(
			"%s: FUGA — %d árboles vivos tras terminar el fichero" % [path.get_file(), residue]
		)
		for node: Node in get_nodes_in_group(&"trees"):
			node.free()
	# M0: dos frames de respiro entre ficheros — el NavigationServer retira
	# la región del mundo recién liberado ANTES del siguiente bake (si no,
	# ambas conviven un frame y salta «edge errors» por aristas solapadas).
	await process_frame
	await process_frame
