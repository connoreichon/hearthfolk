class_name WorldEvents
extends Node
## Q5: eventos suaves al amanecer (máx. uno al día). Sin fracaso duro:
## sabor y pequeñas sorpresas.


func _ready() -> void:
	SimClock.day_changed.connect(_on_day_changed)


func _on_day_changed(_day: int) -> void:
	var roll: float = GameState.rng.randf()
	var season: int = SimClock.get_season()
	if season == SimClock.Season.AUTUMN and roll < 0.22:
		apply_frost()
	elif season <= SimClock.Season.SUMMER and roll < 0.15:
		apply_traveler()
	elif season != SimClock.Season.WINTER and roll < 0.28:
		apply_bird_flock()


## Helada temprana: los brotes retroceden a recién plantados.
func apply_frost() -> void:
	var regressed: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"farms"):
		var farm: FarmField = node as FarmField
		if farm != null:
			regressed += farm.regress_sprouts()
	if regressed > 0:
		EventBus.toast.emit(
			"Helada temprana: %d brotes se encogen y vuelven a empezar" % regressed, &"warn"
		)


## Un viajero agradece la fogata y deja provisiones.
func apply_traveler() -> void:
	GameState.add_resource(&"food", 6)
	EventBus.toast.emit("Un viajero pasa la noche y deja 6 de comida", &"success")
	AudioDirector.play_ui(&"ui_confirm")


## Una bandada cruza la colina (solo ambiente).
func apply_bird_flock() -> void:
	EventBus.toast.emit("Una bandada cruza el cielo del valle", &"info")
	for i: int in 3:
		var offset: Vector3 = Vector3(
			GameState.rng.randf_range(-14.0, 14.0), 8.0, GameState.rng.randf_range(-14.0, 14.0)
		)
		AudioDirector.play_at(StringName("bird_%d" % (i % 4)), offset, -6.0)
