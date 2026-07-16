class_name Rabbit
extends Node3D
## Conejo AMBIENTAL (pasada de fauna): salta por los prados y huye de los
## colonos. Solo visual — sin colisión, sin sim, sin guardado (la caza de
## verdad llega en S6 con AnimalEntity). Barato: duerme si la cámara está
## lejos y se mueve con saltitos parabólicos sobre el terreno.

const HOP_RANGE: float = 9.0
const FLEE_DISTANCE: float = 4.5
const SLEEP_DISTANCE: float = 90.0

var _home: Vector3
var _hop_from: Vector3
var _hop_to: Vector3
var _hop_t: float = -1.0
var _hop_time: float = 0.5
var _rest: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _body: Node3D


func _ready() -> void:
	_rng.seed = hash([get_instance_id(), "rabbit"])
	_home = global_position
	_rest = _rng.randf_range(0.5, 3.0)
	_body = _build_body()
	add_child(_body)


func _process(delta: float) -> void:
	# Dormido si la cámara anda lejos (barato en mapas gigantes)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(global_position) > SLEEP_DISTANCE:
		return
	if _hop_t >= 0.0:
		_hop_t += delta / _hop_time
		if _hop_t >= 1.0:
			_hop_t = -1.0
			global_position = _hop_to
			_rest = _rng.randf_range(0.8, 3.5)
		else:
			var flat: Vector3 = _hop_from.lerp(_hop_to, _hop_t)
			flat.y += sin(_hop_t * PI) * 0.55
			global_position = flat
		return
	_rest -= delta
	var threat: Vector3 = _nearest_citizen()
	if threat != Vector3.INF and threat.distance_to(global_position) < FLEE_DISTANCE:
		_start_hop(global_position + (global_position - threat).normalized() * 3.5, 0.32)
		return
	if _rest <= 0.0:
		var ang: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(1.2, 3.0)
		var target: Vector3 = global_position + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		if target.distance_to(_home) > HOP_RANGE:
			target = global_position.lerp(_home, 0.6)
		_start_hop(target, 0.5)


func _start_hop(target: Vector3, hop_time: float) -> void:
	if GameState.terrain == null:
		return
	target.y = GameState.terrain.get_height(target.x, target.z) + 0.03
	# Nunca saltar al agua
	if GameState.world_gen != null and GameState.world_gen.river_mask(target.x, target.z) > 0.2:
		_rest = 0.6
		return
	_hop_from = global_position
	_hop_to = target
	_hop_time = hop_time
	_hop_t = 0.0
	_body.look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)


func _nearest_citizen() -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_d: float = FLEE_DISTANCE * FLEE_DISTANCE
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var d: float = (node as Node3D).global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = (node as Node3D).global_position
	return best


func _build_body() -> Node3D:
	var body: Node3D = Node3D.new()
	body.name = "Body"
	var fur: Color = Color("#B49B7E") if _rng.randf() < 0.6 else Color("#8F8378")
	var trunk: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.16, 4, 7, 0.85), fur, "Trunk"
	)
	trunk.position = Vector3(0.0, 0.14, 0.0)
	trunk.scale = Vector3(0.9, 0.9, 1.25)
	body.add_child(trunk)
	var head: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.1, 4, 6, 0.95), fur.lightened(0.08), "Head"
	)
	head.position = Vector3(0.0, 0.24, 0.17)
	body.add_child(head)
	for side: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.035, 0.16, 0.05), 0.012), fur.darkened(0.06), "Ear"
		)
		ear.position = Vector3(side * 0.045, 0.38, 0.14)
		ear.rotation.x = deg_to_rad(-12.0)
		body.add_child(ear)
	var tail: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.05, 3, 5, 1.0), Color("#EDE6DA"), "Tail"
	)
	tail.position = Vector3(0.0, 0.16, -0.19)
	body.add_child(tail)
	return body
