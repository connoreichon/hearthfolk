class_name SimConfig
extends Resource
## Valores de balance de la simulación. Nada hardcodeado en gameplay.

static var _instance: SimConfig

@export var day_length_seconds: float = 480.0
@export var dawn_fraction: float = 0.125
@export var day_fraction: float = 0.500
@export var dusk_fraction: float = 0.125
@export var night_fraction: float = 0.250
@export var hunger_per_sim_minute: float = 1.4
@export var energy_per_sim_minute_working: float = 1.8
@export var energy_per_sim_minute_idle: float = 0.6
@export var energy_recovered_per_sim_minute_resting: float = 8.0
@export var hunger_threshold_eat: float = 25.0
@export var energy_threshold_rest: float = 20.0
@export var carry_capacity: int = 2
@export var stuck_seconds: float = 5.0
@export var stuck_max_retries: int = 3


static func get_default() -> SimConfig:
	if _instance == null:
		_instance = load("res://data/config/sim_config.tres") as SimConfig
	return _instance
