extends HFTestCase
## El minitutorial orgánico: avanza al HACER cada acción, salta pistas ya
## hechas por cuenta del jugador y no quema el paso de velocidad con el
## speed_changed del arranque. Sin persistencia (persist=false) para no
## marcar como visto el tutorial real del usuario.

var _guide: TutorialGuide
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	_guide = TutorialGuide.new()
	_guide.force_run = true
	_guide.persist = false
	_tree_scene.root.add_child(_guide)


func after_each() -> void:
	_guide.free()


func test_steps_complete_in_order() -> void:
	assert_eq(_guide.current_step_key(), "camera", "arranca pidiendo mover la cámara")
	_guide._complete("camera")
	assert_eq(_guide.current_step_key(), "chop", "tras la cámara pide talar")
	_guide._on_tree_marked(1)
	assert_eq(_guide.current_step_key(), "zone", "tras talar pide la zona de casa")
	_guide._on_zone_confirmed(2, Rect2(), &"residential")
	assert_eq(_guide.current_step_key(), "farm", "tras la zona pide el huerto")
	_guide._complete("farm")
	assert_eq(_guide.current_step_key(), "speed", "última pista: velocidad")
	_guide._on_speed_changed(2)
	assert_eq(_guide.current_step_key(), "", "tutorial terminado")


func test_early_actions_skip_their_hint() -> void:
	# El jugador tala y dibuja zona ANTES de que el tutorial se lo pida.
	_guide._on_tree_marked(1)
	_guide._on_zone_confirmed(2, Rect2(), &"residential")
	assert_eq(_guide.current_step_key(), "camera", "sigue en cámara")
	_guide._complete("camera")
	assert_eq(_guide.current_step_key(), "farm", "salta tala y zona ya hechas")


func test_startup_speed_change_does_not_burn_last_step() -> void:
	_guide._on_speed_changed(4)
	assert_eq(_guide.current_step_key(), "camera", "ignora el speed del arranque")
	_guide._complete("camera")
	_guide._complete("chop")
	_guide._complete("zone")
	_guide._complete("farm")
	assert_eq(_guide.current_step_key(), "speed", "velocidad sigue pendiente")
	_guide._on_speed_changed(1)
	assert_eq(_guide.current_step_key(), "", "y se completa al cambiarla de verdad")
