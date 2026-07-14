class_name Settings
## Opciones persistentes (user://settings.cfg): volúmenes, pantalla, vsync.

const PATH: String = "user://settings.cfg"
const AUDIO_BUSES: Array[String] = ["Master", "Music", "Ambience", "SFX", "UI"]


static func load_and_apply() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	for bus: String in AUDIO_BUSES:
		AudioDirector.set_bus_volume_linear(bus, float(cfg.get_value("audio", bus, 1.0)))
	set_fullscreen(bool(cfg.get_value("display", "fullscreen", false)), false)
	set_vsync(bool(cfg.get_value("display", "vsync", true)), false)


static func get_volume(bus: String) -> float:
	return AudioDirector.get_bus_volume_linear(bus)


static func set_volume(bus: String, linear: float) -> void:
	AudioDirector.set_bus_volume_linear(bus, linear)
	_store("audio", bus, linear)


static func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


static func set_fullscreen(enabled: bool, persist: bool = true) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if persist:
		_store("display", "fullscreen", enabled)


static func is_vsync() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED


static func set_vsync(enabled: bool, persist: bool = true) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
	if persist:
		_store("display", "vsync", enabled)


static func is_tutorial_done() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return bool(cfg.get_value("tutorial", "done", false))


static func set_tutorial_done() -> void:
	_store("tutorial", "done", true)


static func apply_window_icon() -> void:
	var texture: Texture2D = load("res://assets/ui/icons/hearthfolk.png")
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	DisplayServer.set_icon(image)


static func _store(section: String, key: String, value: Variant) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, key, value)
	cfg.save(PATH)
