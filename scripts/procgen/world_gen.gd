class_name WorldGen
extends RefCounted
## Fuente única de verdad del mundo (S1, Build 003): altura, bioma y agua
## como FUNCIONES PURAS consultables en cualquier (x,z) — sin array
## monolítico. Los chunks del mapa gigante muestrean de aquí; TerrainData y
## las colisiones solo cachean lo que la física necesita. Determinista por
## semilla: mismo seed → mismo mundo, punto a punto.

enum Biome { PRADERA, BOSQUE, RIBERA, COLINAS, CLARO }

const WATER_LEVEL: float = -0.55
const CENTER_FLAT_RADIUS: float = 25.0
const HILL_CENTER: Vector2 = Vector2(38.0, -38.0)

## Mitad del lado del mapa en metros (S1-B lo subirá a 512 = mapa de 1 km).
var map_half: float = 60.0

var _height_noise: FastNoiseLite
var _biome_noise: FastNoiseLite
var _warp_noise: FastNoiseLite
var _clearing_noise: FastNoiseLite


func _init(seed_value: int, half: float = 60.0) -> void:
	map_half = half
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = seed_value
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.02
	_height_noise.fractal_octaves = 3
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = seed_value + 101
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.008
	_warp_noise = FastNoiseLite.new()
	_warp_noise.seed = seed_value + 202
	_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_noise.frequency = 0.02
	_clearing_noise = FastNoiseLite.new()
	_clearing_noise.seed = seed_value + 303
	_clearing_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_clearing_noise.frequency = 0.03


## Altura del terreno en un punto cualquiera del mundo.
## (Réplica exacta de la fórmula de la Build 002 mientras el mapa siga en
## 120 m; S1-B la generaliza a la escala gigante con red de ríos.)
func height(x: float, z: float) -> float:
	var dist: float = Vector2(x, z).length()
	var f_center: float = smoothstep(CENTER_FLAT_RADIUS, 45.0, dist)
	var h: float = _height_noise.get_noise_2d(x, z) * 2.2 * f_center
	var hill_d2: float = pow(x - HILL_CENTER.x, 2.0) + pow(z - HILL_CENTER.y, 2.0)
	h += 3.4 * exp(-hill_d2 / (2.0 * 14.0 * 14.0))
	var f_west: float = smoothstep(44.0, 52.0, -x)
	h = lerpf(h, 0.15, f_west)
	var channel_center: float = -54.0 + sin(z * 0.05) * 2.5
	var dx: float = x - channel_center
	h -= 1.3 * exp(-dx * dx / 8.0) * f_west
	var vale: float = _south_vale(x, z)
	h = lerpf(h, h * 0.35, vale)
	return clampf(h, -1.6, 4.0)


## Vaguada suave del sur al centro (relieve heredado de la 002).
func _south_vale(x: float, z: float) -> float:
	var path_x: float = sin(z * 0.045) * 3.0
	var d: float = absf(x - path_x)
	var w: float = exp(-d * d / (2.0 * 1.5 * 1.5))
	return w * smoothstep(-4.0, 0.0, z)


## Cercanía al agua 0..1 (1 = en el cauce). Base de la Ribera de Juncos.
func river_mask(x: float, z: float) -> float:
	var f_west: float = smoothstep(40.0, 52.0, -x)
	if f_west <= 0.0:
		return 0.0
	var channel_center: float = -54.0 + sin(z * 0.05) * 2.5
	var dx: float = absf(x - channel_center)
	return clampf(1.0 - dx / 14.0, 0.0, 1.0) * f_west


func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_LEVEL + 0.05 and river_mask(x, z) > 0.3


## Bioma del punto (fronteras suaves por ruido deformado; ART_DIRECTION_003).
func biome(x: float, z: float) -> int:
	if river_mask(x, z) > 0.35:
		return Biome.RIBERA
	if height(x, z) > 2.2:
		return Biome.COLINAS
	var wx: float = x + _warp_noise.get_noise_2d(x, z) * 18.0
	var wz: float = z + _warp_noise.get_noise_2d(x + 977.0, z - 553.0) * 18.0
	if _clearing_noise.get_noise_2d(wx, wz) > 0.82:
		return Biome.CLARO
	if _biome_noise.get_noise_2d(wx, wz) > 0.22:
		return Biome.BOSQUE
	return Biome.PRADERA


## Densidad relativa de árboles del bioma (multiplicador para los props).
func tree_density(which: int) -> float:
	match which:
		Biome.BOSQUE:
			return 1.9
		Biome.RIBERA:
			return 0.7
		Biome.COLINAS:
			return 0.45
		Biome.CLARO:
			return 0.1
		_:
			return 1.0


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	var half: float = map_half - margin
	return absf(x) <= half and absf(z) <= half
