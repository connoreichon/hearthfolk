class_name WorldGen
extends RefCounted
## Fuente única de verdad del mundo (S1, Build 003): altura, bioma y agua
## como FUNCIONES PURAS consultables en cualquier (x,z) — sin array
## monolítico. Los chunks del mapa gigante muestrean de aquí; TerrainData y
## las colisiones solo cachean lo que la física necesita. Determinista por
## semilla: mismo seed → mismo mundo, punto a punto.

enum Biome { PRADERA, BOSQUE, RIBERA, COLINAS, CLARO }

const WATER_LEVEL: float = -0.55
## Lado por defecto del mapa gigante: 1024 m (16×16 chunks de 64 m).
const DEFAULT_HALF: float = 512.0

## Mitad del lado del mapa en metros.
var map_half: float = DEFAULT_HALF

var _height_noise: FastNoiseLite
var _hill_noise: FastNoiseLite
var _river_noise: FastNoiseLite
var _biome_noise: FastNoiseLite
var _warp_noise: FastNoiseLite
var _clearing_noise: FastNoiseLite


func _init(seed_value: int, half: float = DEFAULT_HALF) -> void:
	map_half = half
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = seed_value
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.008
	_height_noise.fractal_octaves = 4
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = seed_value + 77
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hill_noise.frequency = 0.0022
	_river_noise = FastNoiseLite.new()
	_river_noise.seed = seed_value + 500
	_river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Frecuencia baja: pocos ríos LARGOS y algún lago, no un valle acharcado
	_river_noise.frequency = 0.0008
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = seed_value + 101
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.003
	_warp_noise = FastNoiseLite.new()
	_warp_noise.seed = seed_value + 202
	_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_noise.frequency = 0.008
	_clearing_noise = FastNoiseLite.new()
	_clearing_noise.seed = seed_value + 303
	_clearing_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_clearing_noise.frequency = 0.012


## Altura del terreno en cualquier punto del mundo gigante: lomas suaves
## por ruido multi-octava, cerros donde late el ruido de colinas y la RED
## DE RÍOS tallada encima. Pendientes pensadas para navmesh (<22° casi
## en todas partes; los cerros y orillas son el relieve con carácter).
func height(x: float, z: float) -> float:
	# Suelo firme SIEMPRE sobre el agua: las hondonadas del ruido se
	# comprimen (suelo ~0.0) — solo los ríos y lagos tallados se hunden.
	var n: float = _height_noise.get_noise_2d(x, z)
	var h: float = 0.4 + maxf(n, -0.15) * 2.6
	# Cerros: donde el ruido de colinas sube de umbral, el relieve se
	# multiplica — cadenas suaves de lomas altas, no picos alpinos.
	var hill: float = _hill_noise.get_noise_2d(x, z)
	if hill > 0.15:
		h += smoothstep(0.15, 0.75, hill) * 5.5
	# Río: canal donde el ruido cruza cero. La tala manda sobre el relieve:
	# en el corazón del cauce (mask ≥ 0.55) el lecho SIEMPRE se hunde bajo
	# el agua, aunque cruce colinas — el río corta valles, no flota.
	var carve: float = river_mask(x, z)
	h = lerpf(h, WATER_LEVEL - 0.9, smoothstep(0.18, 0.55, carve))
	return clampf(h, -1.8, 8.5)


## Cercanía al agua 0..1 (1 = centro del cauce). El río es la banda donde
## el ruido de ríos cruza el cero — serpentea solo, sin trazado a mano.
func river_mask(x: float, z: float) -> float:
	# Warp suave: serpentea la línea del cauce SIN trocearla en charcos
	var wx: float = x + _warp_noise.get_noise_2d(x + 311.0, z) * 10.0
	var wz: float = z + _warp_noise.get_noise_2d(x, z + 733.0) * 10.0
	var n: float = absf(_river_noise.get_noise_2d(wx, wz))
	# Banda del cauce: ríos ANCHOS (~25-35 m con orillas) que pesan en el
	# mapa y en la vista — cruzar un río debe imponer (orden del dueño).
	return clampf(1.0 - n / 0.032, 0.0, 1.0)


func is_water(x: float, z: float) -> bool:
	return river_mask(x, z) > 0.55


## Bioma del punto (fronteras suaves por ruido deformado; ART_DIRECTION_003).
func biome(x: float, z: float) -> int:
	if river_mask(x, z) > 0.25:
		return Biome.RIBERA
	if _hill_noise.get_noise_2d(x, z) > 0.32:
		return Biome.COLINAS
	var wx: float = x + _warp_noise.get_noise_2d(x, z) * 45.0
	var wz: float = z + _warp_noise.get_noise_2d(x + 977.0, z - 553.0) * 45.0
	if _clearing_noise.get_noise_2d(wx, wz) > 0.86:
		return Biome.CLARO
	if _biome_noise.get_noise_2d(wx, wz) > 0.2:
		return Biome.BOSQUE
	return Biome.PRADERA


## Peso CONTINUO de bosque 0..1 (mismo eje que biome() pero suave): tinta
## el terreno de verde más oscuro donde hay fronda, sin fronteras duras.
## El mapa se lee de un vistazo (praderas claras, bosques umbríos).
func forest_weight(x: float, z: float) -> float:
	var wx: float = x + _warp_noise.get_noise_2d(x, z) * 45.0
	var wz: float = z + _warp_noise.get_noise_2d(x + 977.0, z - 553.0) * 45.0
	return smoothstep(0.05, 0.5, _biome_noise.get_noise_2d(wx, wz))


## Peso CONTINUO de tierras altas 0..1: tono seco y tostado en las colinas.
func highland_weight(x: float, z: float) -> float:
	return smoothstep(0.12, 0.5, _hill_noise.get_noise_2d(x, z))


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
