class_name Citizen
extends CharacterBody3D
## Habitante autónomo. La IA decide en sim_tick; el movimiento corre en
## _physics_process con velocidad = move_speed × velocidad de simulación
## (nunca Engine.time_scale). RVO activo contra otros habitantes.

var entity_id: int = 0
var data: CitizenData
var visual: CitizenVisual
var state_machine: StateMachine
var local_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Necesidades 0–100, siempre "más = mejor" (100 hambre = saciado).
# En esta build solo hambre y energía afectan al comportamiento.
var hunger: float = 100.0
var energy: float = 100.0
var rest_need: float = 100.0
var safety: float = 100.0
var bond: float = 100.0

var speed_modifier: float = 1.0
var current_task_id: int = -1
var status_icon: StatusIcon
var carrying_type: StringName = &""
var carrying_amount: int = 0
var sleeping_indoors: bool = false

var _carry_visual: Node3D

var _moving: bool = false
var _last_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _coarse_anchor: Vector3 = Vector3.ZERO
var _coarse_timer: float = 0.0
var _cfg: SimConfig
var _critical_sent: bool = false
var _step_distance: float = 0.0

@onready var nav_agent: NavigationAgent3D = $NavAgent


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"citizen")
	local_rng.seed = hash([GameState.world_seed, "citizen", data.display_name])
	collision_layer = (1 << 1) | (1 << 7)
	collision_mask = 53
	add_to_group(&"citizens")
	add_to_group(&"persistent")
	add_to_group(&"selectable")
	_cfg = SimConfig.get_default()

	visual = CitizenVisual.new()
	visual.setup(data, local_rng.randi())
	add_child(visual)
	_add_blob_shadow()

	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.35
	# El navmesh queda hasta ~0.6 m por encima del origen (rasterizado con
	# cell_height 0.3): sin este offset la comprobación 3D de llegada al
	# waypoint nunca se cumple y el agente oscila en el sitio.
	nav_agent.path_height_offset = 0.6
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.35
	nav_agent.neighbor_distance = 2.5
	nav_agent.max_neighbors = 6
	nav_agent.max_speed = 12.0
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	state_machine = StateMachine.new(self)
	state_machine.add(StateIdle.new())
	state_machine.add(StateWander.new())
	state_machine.add(StateEat.new())
	state_machine.add(StateRest.new())
	state_machine.add(StateReturnToSettlement.new())
	state_machine.add(StateFindTask.new())
	state_machine.add(StateMoveToResource.new())
	state_machine.add(StateHarvest.new())
	state_machine.add(StateCarryResource.new())
	state_machine.add(StateDeliverResource.new())
	state_machine.add(StateSupply.new())
	state_machine.add(StateBuild.new())
	state_machine.add(StateFarm.new())
	state_machine.add(StateRecoverFromStuck.new())
	state_machine.change(&"Idle")

	status_icon = StatusIcon.new()
	status_icon.position = Vector3(0.0, 2.05, 0.0)
	add_child(status_icon)
	EventBus.citizen_state_changed.connect(_on_state_changed)

	_last_pos = global_position
	SimClock.sim_tick.connect(_on_sim_tick)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func _on_state_changed(changed_id: int, state: StringName) -> void:
	if changed_id == entity_id and status_icon != null:
		status_icon.show_for_state(state)


func _on_sim_tick(dt: float) -> void:
	# Durante un cambio de escena el nodo puede recibir ticks ya fuera del
	# árbol (sim_tick viene de un autoload): tocar navegación o grupos ahí
	# es use-after-free en release.
	if not is_inside_tree():
		return
	_decay_needs(dt)
	_check_interrupts()
	state_machine.tick(dt)
	_check_stuck(dt)


func _decay_needs(dt: float) -> void:
	var current: StringName = state_machine.current_name()
	var working: bool = current in [&"Harvest", &"Build", &"CarryResource", &"DeliverResource"]
	hunger = maxf(0.0, hunger - _cfg.hunger_per_sim_minute * dt / 60.0)
	if current != &"Rest":
		var rate: float = (
			_cfg.energy_per_sim_minute_working if working else _cfg.energy_per_sim_minute_idle
		)
		energy = maxf(0.0, energy - rate * dt / 60.0)
	_update_morale_needs(dt)
	# Sin comida y famélico: trabaja un 35 % más lento (§7.5). No hay muerte.
	speed_modifier = 0.65 if hunger < 10.0 else 1.0
	if hunger < 5.0 and not _critical_sent:
		_critical_sent = true
		EventBus.citizen_need_critical.emit(entity_id, &"hunger")
	elif hunger > 30.0:
		_critical_sent = false


## Q4 — Moral: vínculo (compañía) y seguridad (fuego, techo, invierno).
func _update_morale_needs(dt: float) -> void:
	var per_min: float = dt / 60.0
	# Vínculo: compañía a menos de 6 m lo sube; la soledad lo baja despacio
	var company: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		if node == self:
			continue
		if (node as Node3D).global_position.distance_to(global_position) < 6.0:
			company = true
			break
	bond = clampf(bond + (2.5 if company else -1.6) * per_min, 0.0, 100.0)
	# Seguridad: de día sube; de noche depende de fuego/techo; invierno pica
	var delta_safety: float = 3.0
	if SimClock.is_night():
		if sleeping_indoors:
			delta_safety = 8.0
		else:
			var fire_dist: float = INF
			var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
			if not fires.is_empty():
				fire_dist = (fires[0] as Node3D).global_position.distance_to(global_position)
			if fire_dist > 8.0:
				delta_safety = -4.0
				if SimClock.get_season() == SimClock.Season.WINTER:
					delta_safety = -8.0
	elif SimClock.get_season() == SimClock.Season.WINTER and not sleeping_indoors:
		delta_safety = 1.0
	safety = clampf(safety + delta_safety * per_min, 0.0, 100.0)


## Moral 0..1 a partir de seguridad, vínculo y necesidades críticas.
func morale() -> float:
	var base: float = (safety * 0.5 + bond * 0.5) / 100.0
	if hunger < 25.0:
		base -= 0.15
	if energy < 20.0:
		base -= 0.15
	return clampf(base, 0.0, 1.0)


## La moral escala el trabajo entre 0.6 y 1.15 (Q4).
func effective_work_speed() -> float:
	return data.work_speed * lerpf(0.6, 1.15, morale())


func mood_text() -> String:
	var value: float = morale()
	if value > 0.75:
		return "Contento"
	if value > 0.45:
		return "Tranquilo"
	if value > 0.25:
		return "Inquieto"
	return "Desanimado"


## Prioridades (§7.3): comer y descansar interrumpen el trabajo; de noche
## solo se termina la tarea en curso (los ociosos vuelven al asentamiento).
func _check_interrupts() -> void:
	var current: StringName = state_machine.current_name()
	if current in [&"Eat", &"Rest", &"RecoverFromStuck"]:
		return
	if hunger < _cfg.hunger_threshold_eat and GameState.get_resource(&"food") > 0:
		drop_carry(true)
		abandon_task(&"yield")
		state_machine.change(&"Eat")
	elif energy < _cfg.energy_threshold_rest:
		drop_carry(true)
		abandon_task(&"yield")
		state_machine.change(&"Rest")
	elif SimClock.is_night() and current in [&"Idle", &"Wander", &"FindTask"]:
		state_machine.change(&"ReturnToSettlement")


func current_task() -> TaskBoard.Task:
	if current_task_id == -1:
		return null
	return TaskBoard.get_task(current_task_id)


func task_target() -> Node3D:
	var task: TaskBoard.Task = current_task()
	if task == null:
		return null
	return EntityRegistry.get_node_by_id(task.target_id) as Node3D


func abandon_task(reason: StringName) -> void:
	if current_task_id == -1:
		return
	TaskBoard.release(current_task_id, entity_id, reason)
	current_task_id = -1


func face_towards(point: Vector3) -> void:
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		visual.rotation.y = atan2(dir.x, dir.z)


## Apartarse del arco de caída de un árbol (§16).
func dodge_away(from: Vector3, fall_dir: Vector3) -> void:
	var side: Vector3 = fall_dir.cross(Vector3.UP).normalized()
	if local_rng.randf() < 0.5:
		side = -side
	move_to(global_position + side * 3.0 + (global_position - from).normalized() * 1.5)


## Teleport suave con fundido de escala (0.2 s).
func fade_teleport(point: Vector3) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 0.05, 0.1)
	tween.tween_callback(func() -> void: global_position = point)
	tween.tween_property(visual, "scale", Vector3.ONE * data.height_scale, 0.1)


## Coger un haz del suelo: desaparece del mundo y va a las manos (§8.4).
func pick_up(item: ResourceItem) -> void:
	carrying_type = item.resource_type
	carrying_amount = mini(item.amount, _cfg.carry_capacity)
	EventBus.resource_picked.emit(item.entity_id, entity_id)
	item.queue_free()
	_carry_visual = _build_carry_visual(carrying_amount)
	visual.hands_node().add_child(_carry_visual)
	visual.mode = &"carry"


## Cargar madera tomada del almacén (sin item físico de por medio).
func load_carry(type: StringName, amount: int) -> void:
	carrying_type = type
	carrying_amount = amount
	_carry_visual = _build_carry_visual(amount)
	visual.hands_node().add_child(_carry_visual)
	visual.mode = &"carry"


## Depositar la carga en el destino (inventario global o obra).
func deliver_carry(destination: Node3D) -> void:
	if carrying_amount <= 0:
		return
	var dest_id: int = 0
	if destination != null and destination.get(&"entity_id") != null:
		dest_id = int(destination.get(&"entity_id"))
	if destination != null and destination.has_method(&"receive_material"):
		destination.call(&"receive_material", carrying_type, carrying_amount)
	else:
		GameState.add_resource(carrying_type, carrying_amount)
	EventBus.resource_delivered.emit(carrying_type, carrying_amount, dest_id)
	_clear_carry()


## Soltar la carga al suelo (interrupciones): vuelve a ser un item físico.
func drop_carry(spawn_on_ground: bool) -> void:
	if carrying_amount <= 0:
		return
	if spawn_on_ground:
		var item: ResourceItem = ResourceItem.create(
			carrying_type, carrying_amount, local_rng.randi()
		)
		get_parent().add_child(item)
		var pos: Vector3 = global_position + visual.basis.z * 0.5
		if GameState.terrain != null:
			pos.y = GameState.terrain.get_height(pos.x, pos.z)
		item.global_position = pos
	_clear_carry()


func _clear_carry() -> void:
	carrying_type = &""
	carrying_amount = 0
	if _carry_visual != null and is_instance_valid(_carry_visual):
		_carry_visual.queue_free()
	_carry_visual = null
	if visual.mode == &"carry":
		visual.mode = &"idle"


func _build_carry_visual(amount: int) -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var bundle: Node3D = Node3D.new()
	bundle.name = "CarryBundle"
	for log_i: int in amount:
		var wood_log: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.log_cylinder(0.08, 0.6, 7), palette.wood_light, "Log%d" % log_i
		)
		wood_log.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		wood_log.position = Vector3(0.3, float(log_i) * 0.17, 0.0)
		bundle.add_child(wood_log)
	return bundle


func find_storage() -> Node3D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"storage")
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D


## Punto de descanso repartido en círculo alrededor de la fogata.
## El snap al navmesh puede caer en una ISLA-esquirla entre los agujeros
## de la fogata y el carro (visto en el soak 002: reachable=false y el
## agente congelado): se valida con ruta real y se rota de hueco si el
## propio está aislado. Último recurso: descansar donde se está.
func rest_spot() -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		center = (fires[0] as Node3D).global_position
	if not is_inside_tree():
		return center + Vector3(2.3, 0.0, 0.0)
	var world_3d: World3D = get_world_3d()
	var map: RID = world_3d.navigation_map
	var base_slot: int = entity_id % 8
	for i: int in 8:
		var ang: float = float((base_slot + i) % 8) * TAU / 8.0 + 0.4
		var spot: Vector3 = center + Vector3(cos(ang) * 2.3, 0.0, sin(ang) * 2.3)
		if GameState.terrain != null:
			spot.y = GameState.terrain.get_height(spot.x, spot.z)
		var snapped_spot: Vector3 = NavigationServer3D.map_get_closest_point(map, spot)
		if NavUtil.is_reachable(world_3d, global_position, snapped_spot, 1.5):
			return snapped_spot
	return global_position


func _physics_process(_delta: float) -> void:
	if SimClock.speed == SimClock.Speed.PAUSED:
		visual.set_motion(0.0)
		return
	if not _moving:
		return
	if nav_agent.is_navigation_finished():
		stop_moving()
		return
	var next: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = next - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target_speed: float = data.move_speed * float(SimClock.speed) * speed_modifier
	nav_agent.velocity = dir.normalized() * target_speed


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _moving or SimClock.speed == SimClock.Speed.PAUSED:
		return
	velocity = Vector3(safe_velocity.x, -3.0, safe_velocity.z)
	move_and_slide()
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	visual.set_motion(horizontal)
	_step_distance += horizontal * get_physics_process_delta_time()
	if _step_distance > 1.1:
		_step_distance = 0.0
		AudioDirector.play_footstep(global_position)
	if horizontal > 0.2:
		var yaw: float = atan2(velocity.x, velocity.z)
		visual.rotation.y = lerp_angle(
			visual.rotation.y, yaw, 1.0 - exp(-10.0 * get_physics_process_delta_time())
		)


func move_to(point: Vector3) -> void:
	nav_agent.target_position = point
	_moving = true


## Acercarse a una entidad sin chocar con ella: objetivo desplazado
## stand_off metros hacia el habitante y pegado al navmesh.
func move_to_near(point: Vector3, stand_off: float) -> void:
	var dir: Vector3 = global_position - point
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var approach: Vector3 = point + dir.normalized() * stand_off
	var map: RID = get_world_3d().navigation_map
	move_to(NavigationServer3D.map_get_closest_point(map, approach))


func stop_moving() -> void:
	_moving = false
	velocity = Vector3.ZERO
	nav_agent.velocity = Vector3.ZERO
	visual.set_motion(0.0)


func nav_finished() -> bool:
	return not _moving or nav_agent.is_navigation_finished()


func is_moving() -> bool:
	return _moving


## Detección de bloqueo (§7.4) con ANCLA de radio 0.35 m: el micro-temblor
## del RVO (>5 cm por tick) engañaba al detector original y la escalera de
## recuperación nunca se disparaba (cazado en el soak 002: habitantes
## vibrando eternamente junto a la fogata sin "estar quietos").
func _check_stuck(dt: float) -> void:
	if not _moving:
		_stuck_timer = 0.0
		_coarse_timer = 0.0
		_last_pos = global_position
		_coarse_anchor = global_position
		return
	if global_position.distance_to(_last_pos) > 0.35:
		_last_pos = global_position
		_stuck_timer = 0.0
	else:
		_stuck_timer += dt
		if _stuck_timer >= _cfg.stuck_seconds:
			_stuck_timer = 0.0
			_last_pos = global_position
			EventBus.citizen_stuck.emit(entity_id, global_position)
			state_machine.on_stuck()
	# Detector GRUESO (soak 002): órbitas del RVO que saltan >0.35 m pero no
	# progresan. Sin progreso real en 10 s de sim → teleport suave al camino
	# (escalera §7.4 paso c, aplicada sin piedad: nada se atasca >15 s).
	if global_position.distance_to(_coarse_anchor) > 1.2:
		_coarse_anchor = global_position
		_coarse_timer = 0.0
	else:
		_coarse_timer += dt
		if _coarse_timer >= 10.0:
			_coarse_timer = 0.0
			_coarse_anchor = global_position
			_force_unstick()


## Desatasco garantizado: al siguiente waypoint del camino; si no hay
## camino, hacia el objetivo pegado al navmesh; si no, se suelta la tarea.
func _force_unstick() -> void:
	EventBus.citizen_stuck.emit(entity_id, global_position)
	var map: RID = get_world_3d().navigation_map
	var next: Vector3 = nav_agent.get_next_path_position()
	if next.distance_to(global_position) < 0.4:
		var toward: Vector3 = global_position.lerp(nav_agent.target_position, 0.35)
		next = NavigationServer3D.map_get_closest_point(map, toward)
	if next.distance_to(global_position) < 0.4:
		abandon_task(&"stuck")
		state_machine.change(&"Idle")
		return
	fade_teleport(NavigationServer3D.map_get_closest_point(map, next))


func entity_kind() -> StringName:
	return &"citizen"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"name": data.display_name,
		"pos": [global_position.x, global_position.y, global_position.z],
		"state": String(state_machine.current_name()),
		"hunger": hunger,
		"energy": energy,
		"rest": rest_need,
		"safety": safety,
		"bond": bond,
		"carry_type": String(carrying_type),
		"carry_amount": carrying_amount,
		"shirt": data.shirt_color.to_html(false),
		"pants": data.pants_color.to_html(false),
		"hair": data.hair_color.to_html(false),
		"skin": data.skin_color.to_html(false),
		"height": data.height_scale,
		"move_speed": data.move_speed,
		"work_speed": data.work_speed,
	}


func load_data(d: Dictionary) -> void:
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	hunger = float(d.get("hunger", 100.0))
	energy = float(d.get("energy", 100.0))
	rest_need = float(d.get("rest", 100.0))
	safety = float(d.get("safety", 100.0))
	bond = float(d.get("bond", 100.0))
	var carry_amount: int = int(d.get("carry_amount", 0))
	if carry_amount > 0:
		carrying_type = StringName(String(d.get("carry_type", "wood")))
		carrying_amount = carry_amount
		_carry_visual = _build_carry_visual(carrying_amount)
		visual.hands_node().add_child(_carry_visual)


func _add_blob_shadow() -> void:
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.name = "BlobShadow"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.85, 0.85)
	blob.mesh = quad
	blob.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	blob.position = Vector3(0.0, 0.04, 0.0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.12, 0.1, 0.32)
	blob.material_override = mat
	add_child(blob)
