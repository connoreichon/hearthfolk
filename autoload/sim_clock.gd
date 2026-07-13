extends Node
## Tiempo de simulación: tick fijo desacoplado del frame.
## Prohibido Engine.time_scale. Toda la lógica de gameplay cuelga de sim_tick.

signal sim_tick(delta: float)
signal speed_changed(speed: int)
signal day_changed(day: int)
signal phase_changed(phase: int)

enum Speed { PAUSED = 0, NORMAL = 1, FAST = 2, ULTRA = 4 }
enum Phase { DAWN = 0, DAY = 1, DUSK = 2, NIGHT = 3 }

const TICK_HZ: float = 20.0
const TICK_DT: float = 1.0 / TICK_HZ
const MAX_TICKS_PER_FRAME: int = 8

const DAY_LENGTH_SECONDS: float = 480.0
const DAWN_FRACTION: float = 0.125
const DAY_FRACTION: float = 0.500
const DUSK_FRACTION: float = 0.125

var speed: int = Speed.NORMAL
var day: int = 1
var time_of_day: float = 0.25
var elapsed_sim_seconds: float = 0.0

var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if speed == Speed.PAUSED:
		return
	_accumulator += delta * float(speed)
	var ticks: int = 0
	while _accumulator >= TICK_DT and ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_DT
		_advance_tick()
		ticks += 1
	if ticks >= MAX_TICKS_PER_FRAME:
		_accumulator = 0.0


func set_speed(new_speed: int) -> void:
	if new_speed == speed:
		return
	speed = new_speed
	speed_changed.emit(speed)


func get_phase() -> int:
	if time_of_day < DAWN_FRACTION:
		return Phase.DAWN
	if time_of_day < DAWN_FRACTION + DAY_FRACTION:
		return Phase.DAY
	if time_of_day < DAWN_FRACTION + DAY_FRACTION + DUSK_FRACTION:
		return Phase.DUSK
	return Phase.NIGHT


func is_night() -> bool:
	return get_phase() == Phase.NIGHT


func get_clock_text() -> String:
	var total_minutes: int = int(time_of_day * 24.0 * 60.0)
	@warning_ignore("integer_division")
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	return "%02d:%02d" % [hours, minutes]


func reset(new_day: int = 1, new_time_of_day: float = 0.25) -> void:
	day = new_day
	time_of_day = new_time_of_day
	elapsed_sim_seconds = 0.0
	_accumulator = 0.0


func _advance_tick() -> void:
	elapsed_sim_seconds += TICK_DT
	var prev_phase: int = get_phase()
	time_of_day += TICK_DT / DAY_LENGTH_SECONDS
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		day_changed.emit(day)
	if get_phase() != prev_phase:
		phase_changed.emit(get_phase())
	sim_tick.emit(TICK_DT)
