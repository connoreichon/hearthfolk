extends HFTestCase
## Q1: matemática de estaciones y año de 8 días.

var clock: Node


func before_each() -> void:
	clock = (load("res://autoload/sim_clock.gd") as GDScript).new()


func after_each() -> void:
	clock.free()


func test_season_progression() -> void:
	var expected: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 0, 0]
	for i: int in expected.size():
		clock.day = i + 1
		assert_eq(clock.get_season(), expected[i], "estación del día %d" % (i + 1))


func test_year_counter() -> void:
	clock.day = 1
	assert_eq(clock.get_year(), 1)
	clock.day = 8
	assert_eq(clock.get_year(), 1)
	clock.day = 9
	assert_eq(clock.get_year(), 2)
	clock.day = 17
	assert_eq(clock.get_year(), 3)


func test_season_changed_signal_fires_on_day_boundary() -> void:
	clock.speed = 1
	clock.day = 2
	clock.time_of_day = 0.999
	var seasons_seen: Array[int] = []
	clock.season_changed.connect(func(season: int) -> void: seasons_seen.append(season))
	for _f: int in 40:
		clock._process(0.05)
	assert_eq(seasons_seen, [1] as Array[int], "día 2→3 dispara verano")


func test_season_names() -> void:
	clock.day = 7
	assert_eq(clock.season_name(), "Invierno")
	clock.day = 3
	assert_eq(clock.season_name(), "Verano")
