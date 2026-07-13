class_name ConstructionSite
extends StaticBody3D
## Obra por fases (§10). Publica demanda de material, acepta entregas,
## acumula trabajo y muestra piezas progresivamente. Al terminar se
## convierte en edificio habitable (2 plazas para dormir).

const BUILD_RATE: float = 1.6
const MAX_BUILDERS: int = 2
const SLEEP_SLOTS: int = 2

var entity_id: int = 0
var building_seed: int = 0
var recipe: BuildingRecipe
var phase_index: int = 0
var work_progress: float = 0.0
var delivered_total: int = 0
var completed: bool = false
var stalled: bool = false

var _pieces: Dictionary = {}
var _shown: Dictionary = {}
var _window_light: OmniLight3D
var _stakes: Node3D
var _supply_tasks: Array[int] = []
var _build_tasks: Array[int] = []
var _sleepers: Array[int] = []


static func place(
	parent: Node3D, at: Vector3, yaw: float, seed_value: int, preset_id: int = 0
) -> ConstructionSite:
	var site: ConstructionSite = ConstructionSite.new()
	site.name = "ConstructionSite"
	site.building_seed = seed_value
	site.recipe = load("res://data/buildings/cottage_a.tres")
	site.collision_layer = (1 << 4) | (1 << 7)
	site.collision_mask = 0
	if preset_id != 0:
		site.entity_id = preset_id
		EntityRegistry.register_with_id(site, &"construction_site", preset_id)
	parent.add_child(site)
	site.global_position = at
	site.rotation.y = yaw
	return site


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"construction_site")
	add_to_group(&"construction_sites")
	add_to_group(&"persistent")
	add_to_group(&"selectable")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(recipe.footprint.x + 0.4, 2.6, recipe.footprint.y + 0.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.3, 0.0)
	add_child(shape)
	var gen: Dictionary = CottageGen.build(building_seed)
	add_child(gen["root"])
	_pieces = {1: gen["foundation"], 2: gen["frame"], 3: gen["walls"], 4: gen["roof"]}
	_shown = {1: 0, 2: 0, 3: 0, 4: 0}
	_window_light = gen["window_light"]
	_stakes = _build_stakes()
	add_child(_stakes)
	SimClock.sim_tick.connect(_on_sim_tick)
	EventBus.construction_started.emit(entity_id)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func missing_material() -> int:
	return maxi(0, recipe.total_wood_cost() - delivered_total - _pending_supply())


func receive_material(_type: StringName, amount: int) -> void:
	var space: int = recipe.total_wood_cost() - delivered_total
	var accepted: int = mini(amount, space)
	delivered_total += accepted
	if accepted < amount:
		GameState.add_resource(&"wood", amount - accepted)


func can_work_now() -> bool:
	if completed:
		return false
	if phase_index < 1:
		return false
	return delivered_total >= recipe.cumulative_cost(phase_index)


## Aplica unidades de trabajo; muestra piezas con pop conforme avanza.
func apply_work(units: float) -> void:
	if completed or not can_work_now():
		return
	var phase: BuildingPhase = recipe.phases[phase_index - 1]
	work_progress += units
	var fraction: float = clampf(work_progress / phase.work_units, 0.0, 1.0)
	_reveal_pieces(phase_index, fraction)
	if work_progress >= phase.work_units:
		work_progress = 0.0
		_reveal_pieces(phase_index, 1.0)
		phase_index += 1
		if phase_index > recipe.phases.size():
			_complete()
		else:
			EventBus.construction_phase_advanced.emit(entity_id, phase_index)
			EventBus.toast.emit(
				"%s: fase «%s»" % [recipe.display_name, current_phase_name()], &"info"
			)


func current_phase_name() -> String:
	if completed:
		return "Terminada"
	if phase_index == 0:
		return "Plano"
	return recipe.phases[phase_index - 1].display_name


func work_remaining_in_phase() -> float:
	if completed or phase_index < 1:
		return 0.0
	return maxf(0.0, recipe.phases[phase_index - 1].work_units - work_progress)


func progress_fraction() -> float:
	if completed:
		return 1.0
	var total_work: float = 0.0
	var done_work: float = 0.0
	for i: int in recipe.phases.size():
		var phase: BuildingPhase = recipe.phases[i]
		total_work += phase.work_units
		if i + 1 < phase_index:
			done_work += phase.work_units
		elif i + 1 == phase_index:
			done_work += work_progress
	return done_work / total_work if total_work > 0.0 else 0.0


func claim_sleep_slot(citizen_id: int) -> bool:
	if not completed or _sleepers.size() >= SLEEP_SLOTS:
		return false
	if citizen_id in _sleepers:
		return true
	_sleepers.append(citizen_id)
	return true


func release_sleep_slot(citizen_id: int) -> void:
	_sleepers.erase(citizen_id)


func door_position() -> Vector3:
	return global_position + global_basis.x * (recipe.footprint.x * 0.5 + 1.2)


func _process(_delta: float) -> void:
	if _window_light == null:
		return
	var lit: bool = completed and not _sleepers.is_empty() and SimClock.get_phase() >= 2
	var target: float = 1.6 if lit else 0.0
	if absf(_window_light.light_energy - target) > 0.01:
		_window_light.light_energy = lerpf(_window_light.light_energy, target, 0.1)


func _on_sim_tick(_dt: float) -> void:
	if completed:
		return
	_manage_supply_tasks()
	_manage_build_tasks()
	_update_stalled()
	if phase_index == 0 and delivered_total >= recipe.cumulative_cost(1):
		phase_index = 1
		EventBus.construction_phase_advanced.emit(entity_id, phase_index)
		EventBus.toast.emit("La obra de la cabaña arranca: cimientos", &"info")


func _pending_supply() -> int:
	var total: int = 0
	for task_id: int in _supply_tasks:
		var task: TaskBoard.Task = TaskBoard.get_task(task_id)
		if task != null:
			total += int(task.payload.get("amount", 0))
	return total


func _manage_supply_tasks() -> void:
	_supply_tasks = _supply_tasks.filter(
		func(task_id: int) -> bool: return TaskBoard.get_task(task_id) != null
	)
	var missing: int = recipe.total_wood_cost() - delivered_total - _pending_supply()
	while missing > 0:
		var amount: int = mini(2, missing)
		var task_id: int = TaskBoard.publish(
			&"supply", entity_id, {"site_id": entity_id, "amount": amount}, 4
		)
		_supply_tasks.append(task_id)
		missing -= amount
	# Si llegó madera del suelo directamente, sobran tareas de suministro
	while missing < 0 and not _supply_tasks.is_empty():
		var cancelled: bool = false
		for task_id: int in _supply_tasks:
			var task: TaskBoard.Task = TaskBoard.get_task(task_id)
			if task != null and task.claimed_by == -1:
				missing += int(task.payload.get("amount", 0))
				TaskBoard.cancel(task_id, &"oversupplied")
				_supply_tasks.erase(task_id)
				cancelled = true
				break
		if not cancelled:
			break


func _manage_build_tasks() -> void:
	_build_tasks = _build_tasks.filter(
		func(task_id: int) -> bool: return TaskBoard.get_task(task_id) != null
	)
	if can_work_now():
		while _build_tasks.size() < MAX_BUILDERS:
			_build_tasks.append(TaskBoard.publish(&"build", entity_id, {"site_id": entity_id}, 6))
	else:
		for task_id: int in _build_tasks:
			var task: TaskBoard.Task = TaskBoard.get_task(task_id)
			if task != null and task.claimed_by == -1:
				TaskBoard.cancel(task_id, &"no_material")
		_build_tasks = _build_tasks.filter(
			func(task_id: int) -> bool: return TaskBoard.get_task(task_id) != null
		)


func _update_stalled() -> void:
	var needs_material: bool = (
		phase_index >= 1 and not completed and delivered_total < recipe.cumulative_cost(phase_index)
	)
	var world_has_wood: bool = (
		GameState.get_resource(&"wood") > 0
		or not get_tree().get_nodes_in_group(&"resources").is_empty()
	)
	var now_stalled: bool = needs_material and not world_has_wood
	if now_stalled and not stalled:
		stalled = true
		var missing: int = recipe.cumulative_cost(phase_index) - delivered_total
		EventBus.construction_stalled.emit(entity_id, {"wood": missing})
		EventBus.toast.emit(
			"Obra parada: faltan %d de madera y no queda en el mundo" % missing, &"warn"
		)
	elif not now_stalled:
		stalled = false


func _reveal_pieces(phase: int, fraction: float) -> void:
	var pieces: Array = _pieces.get(phase, [])
	var target: int = int(floor(fraction * float(pieces.size())))
	if fraction >= 1.0:
		target = pieces.size()
	while _shown[phase] < target:
		var piece: MeshInstance3D = pieces[_shown[phase]]
		piece.visible = true
		piece.scale = Vector3.ONE * 0.9
		var pop: Tween = piece.create_tween()
		pop.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		pop.tween_property(piece, "scale", Vector3.ONE, 0.15)
		_spawn_sawdust(piece.global_position)
		AudioDirector.play_at(&"hammer", piece.global_position, -8.0)
		_shown[phase] += 1


func _complete(announce: bool = true) -> void:
	completed = true
	stalled = false
	phase_index = recipe.phases.size() + 1
	if _stakes != null:
		_stakes.queue_free()
		_stakes = null
	add_to_group(&"buildings")
	if announce:
		EventBus.construction_completed.emit(entity_id)
		EventBus.toast.emit("¡Cabaña terminada!", &"success")


func debug_complete() -> void:
	delivered_total = recipe.total_wood_cost()
	if phase_index == 0:
		phase_index = 1
	while not completed:
		apply_work(recipe.phases[phase_index - 1].work_units + 0.1)


func _build_stakes() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var stakes: Node3D = Node3D.new()
	stakes.name = "Stakes"
	var hx: float = recipe.footprint.x * 0.5
	var hz: float = recipe.footprint.y * 0.5
	var corners: Array[Vector3] = [
		Vector3(-hx, 0.0, -hz),
		Vector3(hx, 0.0, -hz),
		Vector3(hx, 0.0, hz),
		Vector3(-hx, 0.0, hz),
	]
	for corner: Vector3 in corners:
		var stake: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.cylinder(0.05, 0.03, 0.7, 6), palette.wood_light, "Stake"
		)
		stake.position = corner
		stakes.add_child(stake)
	for i: int in corners.size():
		var from: Vector3 = corners[i] + Vector3(0.0, 0.55, 0.0)
		var to: Vector3 = corners[(i + 1) % corners.size()] + Vector3(0.0, 0.55, 0.0)
		var rope: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.cylinder(0.02, 0.02, from.distance_to(to), 5), palette.cart_cloth, "Rope"
		)
		stakes.add_child(rope)
		# El cilindro crece en +Y local: orientarlo del poste al siguiente
		rope.position = from
		var dir: Vector3 = (to - from).normalized()
		var axis: Vector3 = Vector3.UP.cross(dir)
		if axis.length() > 0.001:
			rope.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	return stakes


func _spawn_sawdust(at: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 70.0
	proc.initial_velocity_min = 0.6
	proc.initial_velocity_max = 1.6
	proc.gravity = Vector3(0.0, -5.0, 0.0)
	proc.scale_min = 0.03
	proc.scale_max = 0.08
	proc.color = PaletteData.get_default().wood_light
	particles.process_material = proc
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = PaletteData.get_default().wood_light
	quad.material = mat
	particles.draw_pass_1 = quad
	get_parent().add_child(particles)
	particles.global_position = at
	particles.emitting = true
	var cleanup: Tween = particles.create_tween()
	cleanup.tween_interval(1.2)
	cleanup.tween_callback(particles.queue_free)


func entity_kind() -> StringName:
	return &"construction_site"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"seed": building_seed,
		"phase": phase_index,
		"work": work_progress,
		"delivered": delivered_total,
		"completed": completed,
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot_y": rotation.y,
	}


func load_data(d: Dictionary) -> void:
	building_seed = int(d.get("seed", 0))
	phase_index = int(d.get("phase", 0))
	work_progress = float(d.get("work", 0.0))
	delivered_total = int(d.get("delivered", 0))
	completed = bool(d.get("completed", false))
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(d.get("rot_y", 0.0))
	# Reconstruir visibilidad de piezas desde el estado
	for phase: int in range(1, recipe.phases.size() + 1):
		if completed or phase < phase_index:
			_reveal_pieces(phase, 1.0)
		elif phase == phase_index:
			_reveal_pieces(phase, work_progress / recipe.phases[phase - 1].work_units)
	if completed:
		_complete(false)
