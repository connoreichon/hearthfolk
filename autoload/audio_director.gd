extends Node
## Buses de audio y reproducción con límite de voces. No genera lógica.

const BUSES: Array[String] = ["Music", "Ambience", "SFX", "UI"]
const MAX_VOICES_PER_SOUND: int = 3

var _voices: Dictionary = {}


func _ready() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))


func active_voices(sound_name: StringName) -> int:
	var list: Array = _voices.get(sound_name, [])
	list = list.filter(func(p: Node) -> bool: return is_instance_valid(p))
	_voices[sound_name] = list
	return list.size()


func _track_voice(sound_name: StringName, player: Node) -> void:
	var list: Array = _voices.get(sound_name, [])
	list.append(player)
	_voices[sound_name] = list
