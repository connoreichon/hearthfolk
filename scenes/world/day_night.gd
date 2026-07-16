class_name DayNight
extends Node
## Ciclo día/noche (§11): rota el sol, aplica gradientes de color/energía
## desde .tres (nada hardcodeado) y enciende la fogata al atardecer.

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial

var _color_gradient: Gradient = load("res://data/config/daylight_gradient.tres")
var _energy_curve: Curve = load("res://data/config/daylight_energy.tres")
var _flicker_noise: FastNoiseLite = FastNoiseLite.new()
var _flicker_t: float = 0.0
## Densidad de niebla base (la del Environment), capturada al vuelo para
## modularla al amanecer sin fijar un número duro aquí.
var _base_fog: float = -1.0

var _day_sky_top: Color = Color("#6E9BC4")
var _day_horizon: Color = Color("#C9D6C2")
var _night_sky_top: Color = Color("#141C2B")
var _night_horizon: Color = Color("#28364B")
## V1: la niebla de distancia también vive el ciclo (dorada→azul noche).
var _day_fog: Color = Color("#BFD0C4")
var _night_fog: Color = Color("#26324A")


func _ready() -> void:
	_flicker_noise.seed = 99
	_flicker_noise.frequency = 3.0


func _process(delta: float) -> void:
	if sun == null:
		return
	var t: float = SimClock.time_of_day
	# Sol: horizonte en t≈0.05, cénit en t≈0.375, se pone en t≈0.70
	sun.rotation_degrees.x = -((t - 0.05) / 0.65) * 180.0
	var season_energy: Array[float] = [1.0, 1.06, 0.92, 0.8]
	var season: int = SimClock.get_season()
	var color: Color = _color_gradient.sample(t)
	if season == SimClock.Season.WINTER:
		color = color.lerp(Color("#AFC4D8"), 0.3)
	sun.light_color = color
	sun.light_energy = _energy_curve.sample_baked(t) * season_energy[season]

	var night_f: float = 1.0 - clampf(inverse_lerp(0.14, 0.9, sun.light_energy), 0.0, 1.0)
	if sky_material != null:
		sky_material.sky_top_color = _day_sky_top.lerp(_night_sky_top, night_f)
		sky_material.sky_horizon_color = _day_horizon.lerp(_night_horizon, night_f)
		sky_material.ground_horizon_color = _day_horizon.lerp(_night_horizon, night_f)
	if environment != null:
		environment.ambient_light_energy = lerpf(1.0, 0.4, night_f)
		# Niebla del amanecer (S3): el valle amanece brumoso y se despeja.
		# Pico en t≈0.1 (recién salido el sol), se disipa hacia el mediodía.
		if _base_fog < 0.0:
			_base_fog = environment.fog_density
		var dawn_mist: float = clampf(1.0 - absf(t - 0.1) / 0.12, 0.0, 1.0)
		environment.fog_density = _base_fog * (1.0 + dawn_mist * 3.2)
		# V1 — la niebla ENFRÍA de noche (azul) y se dora al atardecer
		environment.fog_light_color = _day_fog.lerp(_night_fog, night_f)
		# V1 — god rays por franjas: amanecer y HORA DORADA (la firma).
		# Volumétrica tenue que se enciende/apaga con suavidad.
		var golden: float = clampf(1.0 - absf(t - 0.62) / 0.09, 0.0, 1.0)
		var rays: float = maxf(dawn_mist * 0.7, golden)
		var target_density: float = rays * 0.022
		var current: float = environment.volumetric_fog_density
		var blended: float = lerpf(current, target_density, 1.0 - exp(-2.5 * delta))
		environment.volumetric_fog_density = blended
		environment.volumetric_fog_enabled = blended > 0.0015

	_update_fire(delta)


## Todas las hogueras del grupo &"campfire" (multi-campamento, Build 003):
## se consultan cada frame porque los campamentos nacen DESPUÉS del _ready
## (siembra de bandas) y el grupo es diminuto (2-5 miembros).
func _update_fire(delta: float) -> void:
	var lit: bool = SimClock.get_phase() >= SimClock.Phase.DUSK
	var target: float = 2.4 if lit else 0.0
	_flicker_t += delta
	var flicker: float = 1.0 + _flicker_noise.get_noise_1d(_flicker_t * 60.0) * 0.25
	var k: float = 1.0 - exp(-4.0 * delta)
	var pulse: float = 1.0 + _flicker_noise.get_noise_1d(_flicker_t * 45.0 + 500.0) * 0.12
	for node: Node in get_tree().get_nodes_in_group(&"campfire"):
		var fire_light: OmniLight3D = node.get_node_or_null("Campfire/FireLight") as OmniLight3D
		if fire_light == null:
			continue
		var sparks: GPUParticles3D = node.get_node_or_null("Campfire/Sparks") as GPUParticles3D
		if sparks != null and sparks.emitting != lit:
			sparks.emitting = lit
		fire_light.light_energy = lerpf(fire_light.light_energy, target * flicker, k)
		var flame: Node3D = node.get_node_or_null("Campfire/Flame") as Node3D
		if flame != null:
			flame.visible = fire_light.light_energy > 0.15
			flame.scale = Vector3.ONE * pulse
