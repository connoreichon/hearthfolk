extends Node
## Buses de audio, ambiente por fase del día y one-shots con límite de
## voces. Todos los WAV son sintetizados por tools/gen_audio.py.

const BUSES: Array[String] = ["Music", "Ambience", "SFX", "UI"]
const MAX_VOICES_PER_SOUND: int = 3
const AUDIO_DIR: String = "res://assets/audio/generated/"

var _streams: Dictionary = {}
var _voices: Dictionary = {}
var _ambience_day: AudioStreamPlayer
var _ambience_night: AudioStreamPlayer
var _fire_player: AudioStreamPlayer3D
var _music_player: AudioStreamPlayer
var _music_season: int = -1
var _bird_timer: float = 6.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_rng.seed = 7
	_load_streams()
	_setup_ambience()
	EventBus.tree_felled.connect(_on_tree_felled)
	EventBus.resource_picked.connect(_on_resource_picked)
	EventBus.toast.connect(_on_toast)
	EventBus.tool_changed.connect(func(_tool: StringName) -> void: play_ui(&"ui_click"))
	EventBus.construction_phase_advanced.connect(
		func(_id: int, _phase: int) -> void: play_ui(&"ui_confirm")
	)
	EventBus.game_saved.connect(func(_slot: int) -> void: play_ui(&"ui_confirm"))


func _load_streams() -> void:
	var dir: DirAccess = DirAccess.open(AUDIO_DIR)
	if dir == null:
		push_warning("AudioDirector: no hay audio generado (ejecuta tools/gen_audio.py)")
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".wav"):
			var stream: AudioStream = load(AUDIO_DIR + file_name)
			_streams[StringName(file_name.get_basename())] = stream


func has_sound(sound: StringName) -> bool:
	return _streams.has(sound)


## One-shot 2D (UI).
func play_ui(sound: StringName) -> void:
	if not _streams.has(sound):
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = _streams[sound]
	player.bus = "UI"
	player.volume_db = -6.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## One-shot posicional con límite de voces por sonido.
func play_at(sound: StringName, position: Vector3, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	if _active_voices(sound) >= MAX_VOICES_PER_SOUND:
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = _streams[sound]
	player.bus = "SFX"
	player.volume_db = volume_db
	player.unit_size = 7.0
	player.max_distance = 60.0
	add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	_track_voice(sound, player)


func play_footstep(position: Vector3) -> void:
	play_at(StringName("footstep_%d" % _rng.randi_range(0, 3)), position, -12.0)


func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))


func get_bus_volume_linear(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _setup_ambience() -> void:
	_ambience_day = _make_loop_player(&"ambience_forest", -14.0)
	_ambience_night = _make_loop_player(&"insects_night", -60.0)
	var wind: AudioStreamPlayer = _make_loop_player(&"wind_soft", -22.0)
	if wind != null:
		wind.play()
	if _ambience_day != null:
		_ambience_day.play()
	if _ambience_night != null:
		_ambience_night.play()
	SimClock.phase_changed.connect(_on_phase_changed)
	SimClock.season_changed.connect(_on_music_season)
	_on_music_season.call_deferred(SimClock.get_season())


## Música generativa por estación con fundido cruzado (Q5).
func _on_music_season(season: int) -> void:
	if season == _music_season:
		return
	_music_season = season
	var names: Array[StringName] = [
		&"music_spring", &"music_summer", &"music_autumn", &"music_winter"
	]
	var sound: StringName = names[season]
	if not _streams.has(sound):
		return
	if _music_player == null:
		_music_player = _make_loop_player(sound, -60.0)
		if _music_player == null:
			return
		_music_player.bus = "Music"
		_music_player.play()
		var fade_in: Tween = create_tween()
		fade_in.tween_property(_music_player, "volume_db", -13.0, 3.0)
		return
	var stream: AudioStreamWAV = (_streams[sound] as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	var fade: Tween = create_tween()
	fade.tween_property(_music_player, "volume_db", -50.0, 2.0)
	fade.tween_callback(
		func() -> void:
			_music_player.stream = stream
			_music_player.play()
	)
	fade.tween_property(_music_player, "volume_db", -13.0, 3.0)


func _make_loop_player(sound: StringName, volume_db: float) -> AudioStreamPlayer:
	if not _streams.has(sound):
		return null
	var stream: AudioStreamWAV = (_streams[sound] as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Ambience"
	player.volume_db = volume_db
	add_child(player)
	return player


func _on_phase_changed(phase: int) -> void:
	var night: bool = phase >= SimClock.Phase.DUSK
	if _ambience_day != null:
		var tween_day: Tween = create_tween()
		tween_day.tween_property(_ambience_day, "volume_db", -34.0 if night else -14.0, 2.5)
	if _ambience_night != null:
		var tween_night: Tween = create_tween()
		tween_night.tween_property(_ambience_night, "volume_db", -14.0 if night else -60.0, 2.5)
	_update_fire_loop(night)


func _update_fire_loop(night: bool) -> void:
	if night and _fire_player == null and _streams.has(&"fire_loop"):
		var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
		if fires.is_empty():
			return
		var stream: AudioStreamWAV = (_streams[&"fire_loop"] as AudioStreamWAV).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2
		_fire_player = AudioStreamPlayer3D.new()
		_fire_player.stream = stream
		_fire_player.bus = "Ambience"
		_fire_player.unit_size = 6.0
		add_child(_fire_player)
		_fire_player.global_position = (fires[0] as Node3D).global_position
		_fire_player.play()
	elif not night and _fire_player != null:
		_fire_player.queue_free()
		_fire_player = null


func _process(delta: float) -> void:
	# Pájaros de día, espaciados al azar (cosmético, delta real)
	if SimClock.get_phase() > SimClock.Phase.DAY:
		return
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(4.0, 11.0)
		var sound: StringName = StringName("bird_%d" % _rng.randi_range(0, 3))
		if _streams.has(sound):
			var offset: Vector3 = Vector3(
				_rng.randf_range(-20.0, 20.0), 6.0, _rng.randf_range(-20.0, 20.0)
			)
			play_at(sound, offset, -10.0)


func _on_tree_felled(_tree_id: int, position: Vector3, _wood: int) -> void:
	play_at(&"tree_fall", position)


func _on_resource_picked(_entity_id: int, citizen_id: int) -> void:
	var citizen: Node = EntityRegistry.get_node_by_id(citizen_id)
	if citizen is Node3D:
		play_at(&"pickup_wood", (citizen as Node3D).global_position, -6.0)


func _on_toast(_message: String, kind: StringName) -> void:
	match kind:
		&"warn", &"error":
			play_ui(&"ui_error")
		&"success":
			play_ui(&"ui_confirm")
		_:
			play_ui(&"ui_click")


func _active_voices(sound: StringName) -> int:
	var list: Array = _voices.get(sound, [])
	# Variant a propósito: la lista puede contener objetos ya liberados
	list = list.filter(func(p: Variant) -> bool: return is_instance_valid(p))
	_voices[sound] = list
	return list.size()


func _track_voice(sound: StringName, player: Node) -> void:
	var list: Array = _voices.get(sound, [])
	list.append(player)
	_voices[sound] = list
