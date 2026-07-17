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
var _crest_noise: FastNoiseLite
var _cliff_noise: FastNoiseLite
## Eje de latitud del clima (frío hacia -eje, cálido hacia +eje).
var _climate_axis: Vector2 = Vector2.RIGHT
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
	_mountain_noise.frequency = 0.0016
	# CLIMA GEOGRÁFICO (v2, orden del dueño: «los biomas cálidos lejos de
	# los fríos»): el clima es un EJE tipo latitud — frío en una punta del
	# mapa, desierto en la opuesta, templado en medio. El ruido solo ondula
	# la frontera; ya no hay manchas que peguen nieve con palmeras.
	_climate_noise = FastNoiseLite.new()
	_climate_noise.seed = seed_value + 404
	_climate_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_climate_noise.frequency = 0.0013
	var axis_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	axis_rng.seed = seed_value + 405
	var axis_angle: float = axis_rng.randf() * TAU
	_climate_axis = Vector2(cos(axis_angle), sin(axis_angle))
	# CORDILLERAS (v2): crestas LINEALES ridged; el ruido de montaña regional
	# decide dónde viven las sierras y las crestas les dan el filo.
	_crest_noise = FastNoiseLite.new()
	_crest_noise.seed = seed_value + 819
	_crest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_crest_noise.frequency = 0.0042
	# ACANTILADOS (encargo del agente de sistemas): qué tramos de costa son
	# farallón en vez de playa.
	_cliff_noise = FastNoiseLite.new()
	_cliff_noise.seed = seed_value + 515
	_cliff_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cliff_noise.frequency = 0.002


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
	# CORDILLERAS v2 («montañas de verdad»): el ruido regional decide DÓNDE
	# viven las sierras; las crestas ridged (1-|ruido|) les dan filo lineal.
	# Dos sistemas con alturas distintas: la GRAN cordillera (lóbulos
	# positivos, hasta ~22 m) y una sierra media (lóbulos negativos, ~10 m).
	var mountain: float = _mountain_noise.get_noise_2d(x, z)
	var crest: float = 1.0 - absf(_crest_noise.get_noise_2d(x, z))
	var range_big: float = smoothstep(0.22, 0.6, mountain)
	if range_big > 0.0:
		h += range_big * (3.5 + smoothstep(0.50, 0.90, crest) * 21.0)
	var range_mid: float = smoothstep(0.24, 0.6, -mountain)
	if range_mid > 0.0:
		h += range_mid * smoothstep(0.58, 0.92, crest) * 11.0
	# El frío ES altitud: hacia el polo del mapa la gran cordillera crece
	# aún más (nieves perpetuas) y las colinas se quiebran en sierra.
	var snow: float = snow_weight(x, z)
	if snow > 0.0:
		h += snow * maxf(hill, 0.0) * 7.0
		h += snow * range_big * 5.0
	# DESIERTO: dunas GRANDES rodantes + rizado fino — mar de arena que se
	# camina (pendientes suaves), con el paisaje ondulado de un erg real.
	var arid: float = arid_weight(x, z)
	if arid > 0.6:
		var dune_w: float = smoothstep(0.6, 1.0, arid)
		var dune_big: float = maxf(_warp_noise.get_noise_2d(x * 0.9 + 500.0, z * 0.9), 0.0)
		var ripple: float = maxf(_warp_noise.get_noise_2d(x * 2.2, z * 2.2), 0.0)
		h += dune_w * (dune_big * 2.4 + ripple * 1.2)
	# ALTIPLANOS por TERRAZAS: la montaña se escalona en dos mesetas
	# habitables (9 m y ~15 m) antes de la cumbre — perfiles de mesa, no rampa.
	if h > 9.0:
		var over: float = h - 9.0
		h = 9.0 + over * 0.5 + smoothstep(2.0, 6.0, over) * 4.0
	# ACANTILADOS (encargo del agente de sistemas): donde el ruido de
	# farallón manda, la costa NO se funde hacia el fondo — cae en vertical.
	var cliff: float = smoothstep(0.3, 0.55, _cliff_noise.get_noise_2d(x, z))
	var carve: float = river_mask(x, z)
	var sea: float = sea_mask(x, z)
	var river_only: float = maxf(carve - sea, 0.0)
	h = lerpf(h, WATER_LEVEL - 0.9, smoothstep(0.18, 0.55, river_only))
	var sea_drop: float = lerpf(
		smoothstep(0.3, 0.85, sea), smoothstep(0.55, 0.68, sea), cliff
	)
	# El alzado del farallón SOLO existe en la franja costera (sin esta
	# puerta, un río interior con ruido de farallón flotaba sobre el agua).
	var coast_gate: float = smoothstep(0.02, 0.3, sea)
	var cliff_base: float = h + cliff * coast_gate * (1.0 - sea_drop) * 3.5
	h = lerpf(cliff_base, WATER_LEVEL - 1.1, sea_drop)
	return clampf(h, -1.8, 26.0)


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


## Latitud climática -1.2..1.2 (negativo = frío, positivo = cálido): eje
## fijo por semilla + ondulación de frontera. Garantiza que el hielo y el
## desierto viven en puntas OPUESTAS del mapa (~300 m mínimo de separación).
func _climate_t(x: float, z: float) -> float:
	var t: float = (x * _climate_axis.x + z * _climate_axis.y) / map_half
	t += _climate_noise.get_noise_2d(x, z) * 0.35
	return clampf(t, -1.2, 1.2)


## Región fría 0..1 (tundra nevada). Se ATENÚA junto al mar — la costa es
## templada: la nieve vive tierra adentro, lejos del agua (orden del dueño).
func snow_weight(x: float, z: float) -> float:
	var cold: float = smoothstep(0.30, 0.62, -_climate_t(x, z))
	return cold * (1.0 - sea_mask(x, z))


## Banda de PLAYA 0..1: la franja de tierra pegada al mar (arena, palmeras).
## Nace donde la plataforma costera aún es tierra firme y muere mar adentro.
func beach_weight(x: float, z: float) -> float:
	var sea: float = sea_mask(x, z)
	return smoothstep(0.02, 0.10, sea) * (1.0 - smoothstep(0.28, 0.45, sea))


## Región árida 0..1 (sabana y desierto): el extremo cálido del eje.
func arid_weight(x: float, z: float) -> float:
	return smoothstep(0.30, 0.62, _climate_t(x, z))


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
