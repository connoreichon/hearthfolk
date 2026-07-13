extends HFTestCase
## SimClock: 480 s = 1 día; pausa congela; ×4 avanza 4× en el mismo tiempo real.

var clock: Node
var _tick_count: int = 0


func before_each() -> void:
	clock = (load("res://autoload/sim_clock.gd") as GDScript).new()
	_tick_count = 0


func after_each() -> void:
	clock.free()


func test_one_day_is_480_sim_seconds() -> void:
	clock.speed = 1
	var start_day: int = clock.day
	for _frame: int in 9600:
		clock._process(0.05)
	assert_almost_eq(clock.elapsed_sim_seconds, 480.0, 0.01)
	assert_eq(clock.day, start_day + 1, "un día completo debe incrementar day")
	assert_almost_eq(clock.time_of_day, 0.25, 0.001)


func test_pause_freezes_everything() -> void:
	clock.speed = 0
	clock.sim_tick.connect(_count_tick)
	for _frame: int in 200:
		clock._process(0.05)
	assert_eq(_tick_count, 0, "en pausa no se emite sim_tick")
	assert_almost_eq(clock.elapsed_sim_seconds, 0.0)


func test_ultra_speed_is_4x() -> void:
	clock.speed = 4
	for _frame: int in 2400:
		clock._process(0.05)
	assert_almost_eq(clock.elapsed_sim_seconds, 480.0, 0.01, "120 s reales ×4 = 480 s sim")


func test_tick_count_matches_speed() -> void:
	clock.speed = 1
	clock.sim_tick.connect(_count_tick)
	for _frame: int in 100:
		clock._process(0.05)
	assert_eq(_tick_count, 100)
	clock.sim_tick.disconnect(_count_tick)


func test_spiral_of_death_protection() -> void:
	clock.speed = 4
	clock.sim_tick.connect(_count_tick)
	clock._process(1.0)
	assert_eq(_tick_count, 8, "máximo 8 ticks por frame")
	assert_almost_eq(clock._accumulator, 0.0, 0.0001, "el retraso se descarta")


func test_phases() -> void:
	clock.time_of_day = 0.05
	assert_eq(clock.get_phase(), 0, "amanecer")
	clock.time_of_day = 0.4
	assert_eq(clock.get_phase(), 1, "día")
	clock.time_of_day = 0.68
	assert_eq(clock.get_phase(), 2, "atardecer")
	clock.time_of_day = 0.9
	assert_eq(clock.get_phase(), 3, "noche")


func _count_tick(_delta: float) -> void:
	_tick_count += 1
