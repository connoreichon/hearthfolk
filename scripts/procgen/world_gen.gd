class_name WorldGen
extends RefCounted
## Fuente única de verdad del mundo (S1, Build 003): altura, bioma y agua
## como FUNCIONES PURAS consultables en cualquier (x,z) — sin array
## monolítico. Los chunks del mapa gigante muestrean de aquí; TerrainData y
## las colisiones solo cachean lo que la física necesita. Determinista por
## semilla: mismo seed → mismo mundo, punto a punto.

enum Biome { PRADERA, BOSQUE, RIBERA, COLINAS, CLARO, NIEVE, SABANA, PLAYA, DESIERTO }

const WATER_LEVEL: float = -0.55

## Densidad relativa de árboles por bioma (multiplicador para los props).
const TREE_DENSITY: Dictionary = {
	Biome.BOSQUE: 1.9,
	Biome.RIBERA: 0.7,
	Biome.COLINAS: 0.45,
	Biome.CLARO: 0.1,
	Biome.NIEVE: 0.55,
	Biome.SABANA: 0.12,
	Biome.PLAYA: 0.45,
	Biome.DESIERTO: 0.1,
}
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
var _sea_noise: FastNoiseLite
var _mountain_noise: FastNoiseLite
var _climate_noise: FastNoiseLite
## Qué bordes del mapa son MAR (+X, −X, +Z, −Z): elegidos por semilla —
## cada mundo tiene su costa, siempre distinta (estilo WorldBox procedural).
var _sea_edges: Array[bool] = [false, false, false, false]


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
	# MAR procedural: costa ondulada por ruido; 1-2 bordes con mar por semilla
	_sea_noise = FastNoiseLite.new()
	_sea_noise.seed = seed_value + 909
	_sea_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_sea_noise.frequency = 0.004
	var sea_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	sea_rng.seed = seed_value + 707
	var any_sea: bool = false
	for i: int in 4:
		_sea_edges[i] = sea_rng.randf() < 0.5
		any_sea = any_sea or _sea_edges[i]
	if not any_sea:
		_sea_edges[sea_rng.randi_range(0, 3)] = true
	# MONTAÑAS: macizos raros de gran amplitud — el relieve con drama que
	# pedía el dueño. Nieve en las cimas y roca en las laderas (shader).
	_mountain_noise = FastNoiseLite.new()
	_mountain_noise.seed = seed_value + 818
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_noise.frequency = 0.0011
	# CLIMA (Build 004, orden del dueño): un solo ruido de MUY baja
	# frecuencia parte el mundo en regiones — el extremo frío es TUNDRA
	# NEVADA con montañas, el cálido SABANA seca con oasis. Al ser el mismo
	# eje, nieve y desierto siempre caen en puntas opuestas del mapa.
	_climate_noise = FastNoiseLite.new()
	_climate_noise.seed = seed_value + 404
	_climate_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_climate_noise.frequency = 0.0013


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
	# MONTAÑAS: macizos raros que ROMPEN el horizonte (nieve arriba, roca en
	# la ladera). Sus núcleos son murallas naturales — no se cruzan a pie.
	var mountain: float = _mountain_noise.get_noise_2d(x, z)
	if mountain > 0.32:
		h += smoothstep(0.32, 0.85, mountain) * 13.0
	# TUNDRA NEVADA con carácter: en la región fría las colinas crecen a
	# montaña Y los macizos se encadenan en CORDILLERA — el frío ES altitud,
	# como en la vida real (el norte helado es sierra, no pradera blanca).
	var snow: float = snow_weight(x, z)
	if snow > 0.0:
		h += snow * maxf(hill, 0.0) * 7.0
		h += snow * smoothstep(0.05, 0.6, maxf(mountain, 0.0)) * 6.0
	# DESIERTO: dunas onduladas donde el clima árido aprieta (suaves,
	# navegables: el desierto se camina, las dunas dan el paisaje).
	var arid: float = arid_weight(x, z)
	if arid > 0.6:
		var ripple: float = maxf(_warp_noise.get_noise_2d(x * 2.2, z * 2.2), 0.0)
		h += smoothstep(0.6, 1.0, arid) * ripple * 1.7
	# ALTIPLANOS: por encima de 9 m el relieve se comprime — las cumbres se
	# vuelven mesetas amplias donde se puede vivir (montaña alta habitable).
	if h > 9.0:
		h = 9.0 + (h - 9.0) * 0.55
	# Río: canal donde el ruido cruza cero. La tala manda sobre el relieve:
	# en el corazón del cauce (mask ≥ 0.55) el lecho SIEMPRE se hunde bajo
	# el agua, aunque cruce colinas — el río corta valles, no flota.
	var carve: float = river_mask(x, z)
	h = lerpf(h, WATER_LEVEL - 0.9, smoothstep(0.18, 0.55, carve))
	# Mar: más hondo que los ríos, con plataforma costera suave (la playa
	# la pinta la banda húmeda del shader).
	var sea: float = sea_mask(x, z)
	h = lerpf(h, WATER_LEVEL - 1.1, smoothstep(0.3, 0.85, sea))
	return clampf(h, -1.8, 18.0)


## Cercanía al agua 0..1 (1 = centro del cauce O mar adentro). El río es la
## banda donde el ruido de ríos cruza el cero; el MAR se pliega aquí para
## que TODAS las reglas de agua (bloqueadores, validación de zonas, biomas
## de ribera, árboles) funcionen igual en costa que en río.
func river_mask(x: float, z: float) -> float:
	# Warp suave: serpentea la línea del cauce SIN trocearla en charcos
	var wx: float = x + _warp_noise.get_noise_2d(x + 311.0, z) * 10.0
	var wz: float = z + _warp_noise.get_noise_2d(x, z + 733.0) * 10.0
	var n: float = absf(_river_noise.get_noise_2d(wx, wz))
	# Banda del cauce: ríos ANCHOS (~25-35 m con orillas) que pesan en el
	# mapa y en la vista — cruzar un río debe imponer (orden del dueño).
	return maxf(clampf(1.0 - n / 0.032, 0.0, 1.0), sea_mask(x, z))


## Mar 0..1 (1 = mar adentro): bordes elegidos por semilla con costa
## ondulada por ruido — SIEMPRE procedural, cada mapa con litoral propio.
func sea_mask(x: float, z: float) -> float:
	var reach: float = 105.0 + _sea_noise.get_noise_2d(x, z) * 48.0
	var best: float = 0.0
	if _sea_edges[0]:
		best = maxf(best, (x - (map_half - reach)) / 30.0)
	if _sea_edges[1]:
		best = maxf(best, (-map_half + reach - x) / 30.0)
	if _sea_edges[2]:
		best = maxf(best, (z - (map_half - reach)) / 30.0)
	if _sea_edges[3]:
		best = maxf(best, (-map_half + reach - z) / 30.0)
	return clampf(best, 0.0, 1.0)


func is_water(x: float, z: float) -> bool:
	return river_mask(x, z) > 0.55


## Región fría 0..1 (tundra nevada). Se ATENÚA junto al mar — la costa es
## templada: la nieve vive tierra adentro, lejos del agua (orden del dueño).
func snow_weight(x: float, z: float) -> float:
	var cold: float = smoothstep(0.28, 0.6, _climate_noise.get_noise_2d(x, z))
	return cold * (1.0 - sea_mask(x, z))


## Banda de PLAYA 0..1: la franja de tierra pegada al mar (arena, palmeras).
## Nace donde la plataforma costera aún es tierra firme y muere mar adentro.
func beach_weight(x: float, z: float) -> float:
	var sea: float = sea_mask(x, z)
	return smoothstep(0.02, 0.10, sea) * (1.0 - smoothstep(0.28, 0.45, sea))


## Región árida 0..1 (sabana y desierto): el extremo cálido del clima.
func arid_weight(x: float, z: float) -> float:
	return smoothstep(0.28, 0.6, -_climate_noise.get_noise_2d(x, z))


## Tinte de clima para el vértice (canal A del COLOR): 0 = nieve plena,
## 0.5 = templado, 1 = árido pleno. El shader del terreno lo pinta.
func climate_tint(x: float, z: float) -> float:
	return clampf(0.5 + arid_weight(x, z) * 0.5 - snow_weight(x, z) * 0.5, 0.0, 1.0)


## Clima extremo del punto (NIEVE/SABANA/DESIERTO) o -1 si es templado.
## El corazón árido es DESIERTO de verdad (dunas, cactus); la SABANA es su
## orla de transición — gradiente realista de seco a muy seco.
func _climate_biome(x: float, z: float) -> int:
	if snow_weight(x, z) > 0.55:
		return Biome.NIEVE
	var arid: float = arid_weight(x, z)
	if arid > 0.82:
		return Biome.DESIERTO
	if arid > 0.55:
		return Biome.SABANA
	return -1


## Bioma del punto (fronteras suaves por ruido deformado; ART_DIRECTION_003).
func biome(x: float, z: float) -> int:
	# La PLAYA manda en la costa: siempre pegada al mar, con palmeras…
	# salvo en la región fría — una costa helada no cría palmeras.
	if beach_weight(x, z) > 0.5 and snow_weight(x, z) < 0.4:
		return Biome.PLAYA
	if river_mask(x, z) > 0.25:
		return Biome.RIBERA
	# Los climas extremos mandan sobre los biomas templados: tundra nevada
	# y sabana. El agua en zona árida sigue siendo RIBERA — esos son los
	# oasis, donde se apiña la vida.
	var extreme: int = _climate_biome(x, z)
	if extreme >= 0:
		return extreme
	if _hill_noise.get_noise_2d(x, z) > 0.32:
		return Biome.COLINAS
	var wx: float = x + _warp_noise.get_noise_2d(x, z) * 45.0
	var wz: float = z + _warp_noise.get_noise_2d(x + 977.0, z - 553.0) * 45.0
	if _clearing_noise.get_noise_2d(wx, wz) > 0.86:
		return Biome.CLARO
	return Biome.BOSQUE if _biome_noise.get_noise_2d(wx, wz) > 0.2 else Biome.PRADERA


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
	return float(TREE_DENSITY.get(which, 1.0))


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	var half: float = map_half - margin
	return absf(x) <= half and absf(z) <= half
