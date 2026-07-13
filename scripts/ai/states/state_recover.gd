class_name StateRecoverFromStuck
extends CitizenState
## Recuperación de bloqueo (§7.4): reintento → apartarse → teleport suave.

var _attempt: int = 0
var _wait: float = 0.0


func state_name() -> StringName:
	return &"RecoverFromStuck"


func enter() -> void:
	_attempt += 1
	_wait = 0.5
	var map: RID = citizen.get_world_3d().navigation_map
	match _attempt:
		1:
			# (a) reintentar la ruta actual
			var target: Node3D = citizen.task_target()
			if target != null:
				citizen.move_to(target.global_position)
			else:
				_side_step(map)
		2:
			# (b) apartarse a un punto navegable a 2–4 m
			_side_step(map)
		_:
			# (c) teleport suave al punto navegable más cercano + soltar tarea
			var safe: Vector3 = NavigationServer3D.map_get_closest_point(
				map, citizen.global_position
			)
			citizen.fade_teleport(safe)
			citizen.abandon_task(&"stuck")
			_attempt = 0


func tick(dt: float) -> void:
	_wait -= dt
	if _wait > 0.0:
		return
	if citizen.current_task_id != -1:
		citizen.state_machine.change(&"MoveToResource")
	else:
		citizen.state_machine.change(&"FindTask")


func on_stuck() -> void:
	enter()


func _side_step(map: RID) -> void:
	var ang: float = citizen.local_rng.randf() * TAU
	var radius: float = citizen.local_rng.randf_range(2.0, 4.0)
	var side: Vector3 = citizen.global_position + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
	citizen.move_to(NavigationServer3D.map_get_closest_point(map, side))
