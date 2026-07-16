class_name StateCraft
extends CitizenState
## Tallar las PRIMERAS herramientas rudimentarias (orden del dueño): el
## colono se sienta junto a su hoguera y talla hacha y azada con cantos y
## ramas del entorno (tiempo, no inventario — es material suelto). Al
## terminar, su herramienta de oficio aparece a la espalda y trabaja más
## rápido. Minas, picos y metales llegan en Build 004.

const CRAFT_SECONDS: float = 7.0
const TIMEOUT: float = 40.0

var _crafting: bool = false
var _timer: float = 0.0
var _timeout: float = 0.0


func state_name() -> StringName:
	return &"Craft"


func enter() -> void:
	_crafting = false
	_timeout = TIMEOUT
	if citizen.data.has_tools:
		citizen.state_machine.change(&"FindTask")
		return
	var camp: CampEntity = citizen.home_camp()
	if camp == null:
		citizen.state_machine.change(&"Idle")
		return
	citizen.visual.mode = &"walk"
	citizen.move_to_near(camp.global_position, 2.6)


func tick(dt: float) -> void:
	_timeout -= dt
	if _timeout <= 0.0:
		citizen.state_machine.change(&"Idle")
		return
	if not _crafting:
		var camp: CampEntity = citizen.home_camp()
		var close: bool = (
			camp != null and citizen.global_position.distance_to(camp.global_position) < 3.6
		)
		if not citizen.nav_finished() and not close:
			return
		citizen.stop_moving()
		if camp != null:
			citizen.face_towards(camp.global_position)
		citizen.visual.mode = &"work"
		_crafting = true
		_timer = CRAFT_SECONDS
		return
	_timer -= dt
	if _timer > 0.0:
		return
	citizen.data.has_tools = true
	citizen.visual.refresh_tool()
	EventBus.toast.emit(
		"%s talla sus primeras herramientas de piedra" % citizen.data.display_name, &"info"
	)
	citizen.state_machine.change(&"FindTask")


func exit() -> void:
	citizen.visual.mode = &"idle"


func on_stuck() -> void:
	citizen.state_machine.change(&"RecoverFromStuck")
