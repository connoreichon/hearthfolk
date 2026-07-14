extends HFTestCase
## Regresión del primer bug cazado por el probador humano: al pulsar
## «Nueva partida» el subpanel debe VERSE (panel Y contenido visibles).

var _menu: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.world_seed = 0
	EntityRegistry.clear()
	TaskBoard.clear()
	SimClock.set_speed(0)
	_menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_menu)


func after_each() -> void:
	_menu.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.pending_new_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_new_game_panel_becomes_fully_visible() -> void:
	for _f: int in 5:
		await _tree_scene.process_frame
	var root_panel: PanelContainer = _menu._panel_of(_menu._root_box)
	var new_panel: PanelContainer = _menu._panel_of(_menu._new_box)
	var load_panel: PanelContainer = _menu._panel_of(_menu._load_box)
	assert_true(root_panel.visible, "el menú raíz arranca visible")
	assert_false(new_panel.visible, "el subpanel de nueva partida arranca oculto")

	_menu._show_new_game()
	assert_false(root_panel.visible, "raíz se oculta")
	assert_true(new_panel.visible, "panel de nueva partida visible")
	assert_true(
		_menu._new_box.is_visible_in_tree(),
		"el CONTENIDO del panel también es visible (el bug del probador)"
	)

	_menu._show_root()
	_menu._show_load()
	assert_true(load_panel.visible and _menu._load_box.is_visible_in_tree())
	_menu._show_root()
	assert_true(root_panel.visible)


func test_start_new_game_sets_pending_state() -> void:
	for _f: int in 5:
		await _tree_scene.process_frame
	_menu._show_new_game()
	_menu._pick_slot(3)
	_menu._seed_edit.text = "4242"
	_menu._prepare_new_game_state()
	assert_eq(GameState.pending_new_seed, 4242, "semilla pendiente fijada")
	assert_eq(SaveManager.active_slot, 3, "slot activo fijado")
	SaveManager.active_slot = 1
