extends Node3D
## Punto de entrada. Registra el mapa de entrada y soporta capturas
## automatizadas: godot --path . -- --screenshot ruta.png [segundos]


func _ready() -> void:
	InputSetup.setup()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			var wait_s: float = 2.0
			if i + 2 < args.size() and args[i + 2].is_valid_float():
				wait_s = float(args[i + 2])
			_capture(args[i + 1], wait_s)
		elif args[i] == "--zoom" and i + 1 < args.size():
			var rig: CameraRig = get_node_or_null("CameraRig") as CameraRig
			if rig != null:
				rig.set_zoom(float(args[i + 1]))


func _capture(path: String, wait_s: float) -> void:
	await get_tree().create_timer(wait_s).timeout
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print(
		"screenshot %s -> %s (FPS=%d)" % [path, error_string(err), Engine.get_frames_per_second()]
	)
	get_tree().quit(0 if err == OK else 1)
