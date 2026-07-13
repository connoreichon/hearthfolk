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

var _moving: bool = false
var _last_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _cfg: SimConfig
var _critical_sent: bool = false

@onready var nav_agent: NavigationAgent3D = $NavAgent


func _ready() -> void:
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
	state_machine.change(&"Idle")

	_last_pos = global_position
	SimClock.sim_tick.connect(_on_sim_tick)


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func _on_sim_tick(dt: float) -> void:
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
	# Sin comida y famélico: trabaja un 35 % más lento (§7.5). No hay muerte.
	speed_modifier = 0.65 if hunger < 10.0 else 1.0
	if hunger < 5.0 and not _critical_sent:
		_critical_sent = true
		EventBus.citizen_need_critical.emit(entity_id, &"hunger")
	elif hunger > 30.0:
		_critical_sent = false


## Prioridades (§7.3): comer y descansar interrumpen; la noche recoge a todos.
func _check_interrupts() -> void:
	var current: StringName = state_machine.current_name()
	if current in [&"Eat", &"Rest", &"RecoverFromStuck"]:
		return
	if hunger < _cfg.hunger_threshold_eat and GameState.get_resource(&"food") > 0:
		state_machine.change(&"Eat")
	elif energy < _cfg.energy_threshold_rest:
		state_machine.change(&"Rest")
	elif SimClock.is_night() and current != &"ReturnToSettlement":
		state_machine.change(&"ReturnToSettlement")


func find_storage() -> Node3D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"storage")
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D


## Punto de descanso repartido en círculo alrededor de la fogata.
func rest_spot() -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		center = (fires[0] as Node3D).global_position
	var ang: float = float(entity_id % 8) * TAU / 8.0 + 0.4
	var spot: Vector3 = center + Vector3(cos(ang) * 2.3, 0.0, sin(ang) * 2.3)
	if GameState.terrain != null:
		spot.y = GameState.terrain.get_height(spot.x, spot.z)
	return spot


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
	if horizontal > 0.2:
		var yaw: float = atan2(velocity.x, velocity.z)
		visual.rotation.y = lerp_angle(
			visual.rotation.y, yaw, 1.0 - exp(-10.0 * get_physics_process_delta_time())
		)


func move_to(point: Vector3) -> void:
	nav_agent.target_position = point
	_moving = true


func stop_moving() -> void:
	_moving = false
	velocity = Vector3.ZERO
	nav_agent.velocity = Vector3.ZERO
	visual.set_motion(0.0)


func nav_finished() -> bool:
	return not _moving or nav_agent.is_navigation_finished()


## Detección de bloqueo (§7.4): sin avanzar 0.05 m durante stuck_seconds.
func _check_stuck(dt: float) -> void:
	if not _moving:
		_stuck_timer = 0.0
		_last_pos = global_position
		return
	if global_position.distance_to(_last_pos) > 0.05:
		_last_pos = global_position
		_stuck_timer = 0.0
		return
	_stuck_timer += dt
	if _stuck_timer >= _cfg.stuck_seconds:
		_stuck_timer = 0.0
		EventBus.citizen_stuck.emit(entity_id, global_position)
		_recover_from_stuck()


func _recover_from_stuck() -> void:
	var map: RID = get_world_3d().navigation_map
	var ang: float = local_rng.randf() * TAU
	var radius: float = local_rng.randf_range(2.0, 4.0)
	var side_step: Vector3 = global_position + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
	var safe_point: Vector3 = NavigationServer3D.map_get_closest_point(map, side_step)
	global_position = global_position.lerp(safe_point, 0.15)
	state_machine.on_stuck()


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
	}


func load_data(d: Dictionary) -> void:
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	hunger = float(d.get("hunger", 100.0))
	energy = float(d.get("energy", 100.0))
	rest_need = float(d.get("rest", 100.0))
	safety = float(d.get("safety", 100.0))
	bond = float(d.get("bond", 100.0))


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
