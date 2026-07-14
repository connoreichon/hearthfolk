class_name SeasonController
extends Node
## Estaciones (Q1): tintes globales de shader con transición suave, nieve
## en invierno, crecimiento de árboles jóvenes en primavera y siembra
## natural de brotes en otoño.

const MAX_TREES: int = 70

# Por estación: [tinte hoja (a = fuerza), tinte hierba, nieve]
const SEASON_LOOKS: Array = [
	[Color(0.47, 0.6, 0.33, 0.0), Color(1.0, 1.0, 1.0, 0.0), 0.0],
	[Color(0.55, 0.62, 0.28, 0.22), Color(0.62, 0.64, 0.32, 0.18), 0.0],
	[Color(0.82, 0.45, 0.18, 0.75), Color(0.72, 0.56, 0.26, 0.42), 0.0],
	[Color(0.62, 0.65, 0.58, 0.5), Color(0.75, 0.76, 0.74, 0.3), 1.0],
]

var _leaf_from: Color = Color(1, 1, 1, 0)
var _leaf_to: Color = Color(1, 1, 1, 0)
var _grass_from: Color = Color(1, 1, 1, 0)
var _grass_to: Color = Color(1, 1, 1, 0)
var _snow_from: float = 0.0
var _snow_to: float = 0.0
var _blend: float = 1.0

# Espejos locales: global_shader_parameter_get es solo-editor en runtime
var _leaf_current: Color = Color(1, 1, 1, 0)
var _grass_current: Color = Color(1, 1, 1, 0)
var _snow_current: float = 0.0


func _ready() -> void:
	SimClock.season_changed.connect(_on_season_changed)
	EventBus.game_loaded.connect(func(_slot: int) -> void: _apply_instant(SimClock.get_season()))
	_apply_instant(SimClock.get_season())


func _process(delta: float) -> void:
	if _blend >= 1.0:
		return
	_blend = minf(1.0, _blend + delta * 0.12)
	_set_params(
		_leaf_from.lerp(_leaf_to, _blend),
		_grass_from.lerp(_grass_to, _blend),
		lerpf(_snow_from, _snow_to, _blend)
	)


func snow_level() -> float:
	return _snow_current


func _set_params(leaf: Color, grass: Color, snow: float) -> void:
	_leaf_current = leaf
	_grass_current = grass
	_snow_current = snow
	RenderingServer.global_shader_parameter_set(&"season_leaf_tint", leaf)
	RenderingServer.global_shader_parameter_set(&"season_grass_tint", grass)
	RenderingServer.global_shader_parameter_set(&"snow_amount", snow)


func _apply_instant(season: int) -> void:
	var look: Array = SEASON_LOOKS[season]
	_set_params(look[0], look[1], float(look[2]))
	_blend = 1.0


func _on_season_changed(season: int) -> void:
	var look: Array = SEASON_LOOKS[season]
	_leaf_from = _leaf_current
	_grass_from = _grass_current
	_snow_from = _snow_current
	_leaf_to = look[0]
	_grass_to = look[1]
	_snow_to = float(look[2])
	_blend = 0.0
	match season:
		SimClock.Season.SPRING:
			_grow_young_trees()
			EventBus.toast.emit("Llega la primavera: los brotes crecen", &"info")
		SimClock.Season.SUMMER:
			EventBus.toast.emit("Verano: días luminosos", &"info")
		SimClock.Season.AUTUMN:
			_seed_saplings()
			EventBus.toast.emit("Otoño: el bosque siembra brotes nuevos", &"info")
		SimClock.Season.WINTER:
			EventBus.toast.emit("Invierno: la nieve cubre la colina", &"warn")


## Los árboles jóvenes se hacen adultos al llegar la primavera.
func _grow_young_trees() -> void:
	var grown: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree != null and tree.young and not tree.felled:
			tree.grow_up()
			grown += 1
	if grown > 0:
		EventBus.toast.emit("%d árboles jóvenes se han hecho adultos" % grown, &"success")


## En otoño, los adultos sueltan semilla: brotes nuevos cerca (repoblación).
func _seed_saplings() -> void:
	var trees: Array[Node] = get_tree().get_nodes_in_group(&"trees")
	if trees.size() >= MAX_TREES:
		return
	var worlds: Array[Node] = get_tree().get_nodes_in_group(&"world")
	if worlds.is_empty() or GameState.terrain == null:
		return
	var parent: Node3D = (worlds[0] as Node).get_node("NavigationRegion3D") as Node3D
	var planted: int = 0
	for node: Node in trees:
		if planted >= 4 or trees.size() + planted >= MAX_TREES:
			break
		var tree: TreeEntity = node as TreeEntity
		if tree == null or tree.young or tree.felled:
			continue
		if GameState.rng.randf() > 0.18:
			continue
		var ang: float = GameState.rng.randf() * TAU
		var dist: float = GameState.rng.randf_range(3.5, 7.0)
		var pos: Vector3 = tree.global_position + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		if not GameState.terrain.is_inside(pos.x, pos.z, 4.0):
			continue
		if pos.x < -44.0 or Vector2(pos.x, pos.z).length() < 9.0:
			continue
		if GameState.terrain.get_slope_deg(pos.x, pos.z) > 20.0:
			continue
		var sapling: TreeEntity = TreeEntity.create(GameState.rng.randi(), true)
		parent.add_child(sapling)
		pos.y = GameState.terrain.get_height(pos.x, pos.z)
		sapling.global_position = pos
		sapling.rotation.y = GameState.rng.randf() * TAU
		sapling.scale = Vector3.ONE * 0.9
		planted += 1
