class_name FarmField
extends StaticBody3D
## Huerto (Q2): rejilla de parcelas 1.25 m. Ciclo por parcela:
## tierra → plantada → brote → madura → cosecha (2 de comida al suelo).
## En invierno nada crece ni se planta; lo maduro aguanta.

enum Plot { BARREN = 0, PLANTED = 1, SPROUT = 2, MATURE = 3 }

const PLOT_SIZE: float = 1.25
const WORK_SECONDS: float = 2.0

var entity_id: int = 0
var rect: Rect2 = Rect2()
var plots: Array[int] = []
var timers: Array[float] = []

var _cols: int = 0
var _rows: int = 0
var _crop_nodes: Array = []
var _plant_tasks: Dictionary = {}
var _harvest_tasks: Dictionary = {}


static func place(parent: Node3D, zone_rect: Rect2, preset_id: int = 0) -> FarmField:
	var field: FarmField = FarmField.new()
	field.name = "FarmField"
	field.rect = zone_rect
	field.collision_layer = 1 << 7
	field.collision_mask = 0
	if preset_id != 0:
		field.entity_id = preset_id
		EntityRegistry.register_with_id(field, &"farm", preset_id)
	parent.add_child(field)
	var center: Vector2 = zone_rect.get_center()
	var y: float = 0.0
	if GameState.terrain != null:
		y = GameState.terrain.get_height(center.x, center.y)
	field.global_position = Vector3(center.x, y, center.y)
	return field


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"farm")
	add_to_group(&"farms")
	add_to_group(&"persistent")
	add_to_group(&"selectable")
	_cols = maxi(1, int(rect.size.x / PLOT_SIZE))
	_rows = maxi(1, int(rect.size.y / PLOT_SIZE))
	if plots.is_empty():
		plots.resize(_cols * _rows)
		plots.fill(Plot.BARREN)
		timers.resize(_cols * _rows)
		timers.fill(0.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(rect.size.x, 0.25, rect.size.y)
	shape.shape = box
	shape.position = Vector3(0.0, 0.12, 0.0)
	add_child(shape)
	_build_visuals()
	SimClock.sim_tick.connect(_on_sim_tick)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func plot_count() -> int:
	return _cols * _rows


func plot_position(index: int) -> Vector3:
	@warning_ignore("integer_division")
	var row: int = index / _cols
	var col: int = index % _cols
	var local: Vector3 = Vector3(
		(float(col) + 0.5) * PLOT_SIZE - rect.size.x * 0.5,
		0.0,
		(float(row) + 0.5) * PLOT_SIZE - rect.size.y * 0.5
	)
	var world: Vector3 = global_position + global_basis * local
	if GameState.terrain != null:
		world.y = GameState.terrain.get_height(world.x, world.z)
	return world


func count_by_state(state: int) -> int:
	var total: int = 0
	for plot: int in plots:
		if plot == state:
			total += 1
	return total


## Helada (evento Q5): los brotes vuelven a recién plantados. Devuelve cuántos.
func regress_sprouts() -> int:
	var regressed: int = 0
	for i: int in plots.size():
		if plots[i] == Plot.SPROUT:
			plots[i] = Plot.PLANTED
			timers[i] = 0.0
			_refresh_plot_visual(i)
			regressed += 1
	return regressed


## El habitante planta la parcela (tarea farm_plant completada).
func apply_plant(index: int) -> void:
	if index < 0 or index >= plots.size() or plots[index] != Plot.BARREN:
		return
	plots[index] = Plot.PLANTED
	timers[index] = 0.0
	_refresh_plot_visual(index)


## El habitante cosecha: la parcela vuelve a tierra y brota comida física.
func apply_harvest(index: int) -> void:
	if index < 0 or index >= plots.size() or plots[index] != Plot.MATURE:
		return
	plots[index] = Plot.BARREN
	timers[index] = 0.0
	_refresh_plot_visual(index)
	var item: ResourceItem = ResourceItem.create(
		&"food", SimConfig.get_default().crop_yield, GameState.rng.randi()
	)
	get_parent().add_child(item)
	var pos: Vector3 = plot_position(index)
	item.global_position = pos + Vector3(0.35, 0.0, 0.2)
	AudioDirector.play_at(&"pickup_wood", pos, -8.0)


func _on_sim_tick(dt: float) -> void:
	var winter: bool = SimClock.get_season() == SimClock.Season.WINTER
	var growth: float = dt
	if SimClock.get_season() == SimClock.Season.AUTUMN:
		growth = dt * 0.6
	var stage_seconds: float = SimConfig.get_default().crop_stage_seconds
	for i: int in plots.size():
		if winter:
			break
		if plots[i] == Plot.PLANTED or plots[i] == Plot.SPROUT:
			timers[i] += growth
			if timers[i] >= stage_seconds:
				timers[i] = 0.0
				plots[i] += 1
				_refresh_plot_visual(i)
	_manage_tasks(winter)


func _manage_tasks(winter: bool) -> void:
	for i: int in plots.size():
		var plant_task: TaskBoard.Task = TaskBoard.get_task(int(_plant_tasks.get(i, -1)))
		var harvest_task: TaskBoard.Task = TaskBoard.get_task(int(_harvest_tasks.get(i, -1)))
		if plots[i] == Plot.BARREN and not winter and plant_task == null:
			_plant_tasks[i] = TaskBoard.publish(&"farm_plant", entity_id, {"plot": i}, 5)
		elif plots[i] != Plot.BARREN and plant_task != null and plant_task.claimed_by == -1:
			TaskBoard.cancel(plant_task.id, &"plot_busy")
		if winter and plant_task != null and plant_task.claimed_by == -1:
			TaskBoard.cancel(plant_task.id, &"winter")
		if plots[i] == Plot.MATURE and harvest_task == null:
			_harvest_tasks[i] = TaskBoard.publish(&"farm_harvest", entity_id, {"plot": i}, 3)
		elif plots[i] != Plot.MATURE and harvest_task != null and harvest_task.claimed_by == -1:
			TaskBoard.cancel(harvest_task.id, &"not_mature")


func _build_visuals() -> void:
	var palette: PaletteData = PaletteData.get_default()
	for i: int in plot_count():
		@warning_ignore("integer_division")
		var row: int = i / _cols
		var col: int = i % _cols
		var local: Vector3 = Vector3(
			(float(col) + 0.5) * PLOT_SIZE - rect.size.x * 0.5,
			0.06,
			(float(row) + 0.5) * PLOT_SIZE - rect.size.y * 0.5
		)
		var soil: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(PLOT_SIZE - 0.18, 0.12, PLOT_SIZE - 0.18), 0.03),
			palette.dirt,
			"Soil%d" % i
		)
		soil.position = local
		add_child(soil)
		var mound: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.low_sphere(0.16, 4, 7, 0.5), palette.dirt_light, "Mound%d" % i
		)
		mound.position = local + Vector3(0.0, 0.1, 0.0)
		add_child(mound)
		var sprout: Node3D = Node3D.new()
		sprout.name = "Sprout%d" % i
		var stem: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.cylinder(0.025, 0.02, 0.3, 5), palette.grass, "Stem"
		)
		sprout.add_child(stem)
		var leaf: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.low_sphere(0.09, 4, 6, 0.7), palette.grass_light, "Leaf"
		)
		leaf.position = Vector3(0.0, 0.3, 0.0)
		sprout.add_child(leaf)
		sprout.position = local + Vector3(0.0, 0.06, 0.0)
		add_child(sprout)
		var crop: Node3D = Node3D.new()
		crop.name = "Crop%d" % i
		var bushel: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.cylinder(0.16, 0.1, 0.5, 7), palette.accent, "Bushel"
		)
		crop.add_child(bushel)
		var top: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.low_sphere(0.17, 4, 7, 0.65), palette.warm_light, "Top"
		)
		top.position = Vector3(0.0, 0.52, 0.0)
		crop.add_child(top)
		crop.position = local + Vector3(0.0, 0.06, 0.0)
		add_child(crop)
		_crop_nodes.append([mound, sprout, crop])
		_refresh_plot_visual(i)


func _refresh_plot_visual(index: int) -> void:
	if index >= _crop_nodes.size():
		return
	var nodes: Array = _crop_nodes[index]
	(nodes[0] as Node3D).visible = plots[index] == Plot.PLANTED
	(nodes[1] as Node3D).visible = plots[index] == Plot.SPROUT
	(nodes[2] as Node3D).visible = plots[index] == Plot.MATURE


func entity_kind() -> StringName:
	return &"farm"


func save_data() -> Dictionary:
	var timer_list: Array = []
	for t: float in timers:
		timer_list.append(t)
	var plot_list: Array = []
	for p: int in plots:
		plot_list.append(p)
	return {
		"id": entity_id,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"plots": plot_list,
		"timers": timer_list,
	}


func load_data(d: Dictionary) -> void:
	var saved_plots: Array = d.get("plots", [])
	var saved_timers: Array = d.get("timers", [])
	for i: int in mini(plots.size(), saved_plots.size()):
		plots[i] = int(saved_plots[i])
		timers[i] = float(saved_timers[i]) if i < saved_timers.size() else 0.0
		_refresh_plot_visual(i)
