extends HFTestCase
## S2: oficios por utilidad — aptitud, velocidad por familia e histéresis
## anti-flapping (docs/S2_DESIGN.md §3–§7).


func _plain_data() -> CitizenData:
	var data: CitizenData = CitizenData.new()
	data.attrs = {&"str": 6, &"dex": 6, &"per": 6, &"gre": 6, &"dil": 6}
	# Baseline CON herramientas (la progresión de crafteo se testea aparte)
	data.has_tools = true
	return data


func test_aptitude_rewards_attributes_and_traits() -> void:
	var data: CitizenData = _plain_data()
	data.attrs[&"str"] = 8
	data.traits = [&"brazos_de_roble"]
	# str final 10: (0.7·10/6.5 + 0.3·6/6.5) × 1.25
	var expected: float = (0.7 * (10.0 / 6.5) + 0.3 * (6.0 / 6.5)) * 1.25
	assert_almost_eq(Professions.aptitude(data, &"lenador"), expected, 0.001)
	assert_true(
		Professions.aptitude(data, &"lenador") > Professions.aptitude(data, &"constructor"),
		"el hacha le llama más que el martillo"
	)


func test_work_factor_clamps_and_defaults() -> void:
	var data: CitizenData = _plain_data()
	assert_almost_eq(Professions.work_factor(data, &""), 1.0, 0.001, "sin familia: neutro")
	data.attrs = {&"str": 1, &"dex": 1, &"per": 1, &"gre": 1, &"dil": 1}
	data.traits = [&"flojera_de_brazos"]
	assert_almost_eq(Professions.work_factor(data, &"chop"), 0.6, 0.001, "suelo 0.6 con útiles")
	data.traits = [&"zancada_larga"]
	assert_almost_eq(Professions.work_factor(data, &"walk"), 1.12, 0.001, "andar: solo rasgos")


func test_no_tools_slows_manual_work() -> void:
	var data: CitizenData = _plain_data()
	var with_tools: float = Professions.work_factor(data, &"chop")
	data.has_tools = false
	assert_almost_eq(
		Professions.work_factor(data, &"chop"),
		clampf(with_tools * 0.75, 0.45, 1.6),
		0.001,
		"sin herramientas: talar a mano pelada cuesta un 25 %% más"
	)
	assert_almost_eq(
		Professions.work_factor(data, &"walk"), 1.0, 0.001, "andar no depende de herramientas"
	)


func test_demand_rules_multiple_lumberjacks() -> void:
	# Madera a cero: TODOS eligen leñador aunque sus aptitudes difieran
	var needs: Dictionary = {
		&"lenador": 1.0, &"agricultor": 0.05, &"constructor": 0.05, &"recolector": 0.35
	}
	var strong: CitizenData = _plain_data()
	strong.attrs[&"str"] = 9
	var green: CitizenData = _plain_data()
	green.attrs[&"gre"] = 9
	assert_eq(Professions.choose(strong, needs), &"lenador")
	assert_eq(Professions.choose(green, needs), &"lenador", "la demanda manda (orden del dueño)")


func test_hysteresis_prevents_flapping() -> void:
	var data: CitizenData = _plain_data()
	data.profession = &"lenador"
	# Necesidad de leña floja (0.30) contra recolector fijo (0.35): sin
	# histéresis cambiaría; con ×1.35 defiende su puesto
	var needs: Dictionary = {
		&"lenador": 0.30, &"agricultor": 0.05, &"constructor": 0.05, &"recolector": 0.35
	}
	assert_eq(Professions.choose(data, needs), &"lenador", "0.30×1.35 > 0.35")
	needs[&"lenador"] = 0.1
	assert_eq(Professions.choose(data, needs), &"recolector", "necesidad hundida: sí cambia")


func test_construction_pulls_builders() -> void:
	var data: CitizenData = _plain_data()
	data.profession = &"lenador"
	var needs: Dictionary = {
		&"lenador": 0.25, &"agricultor": 0.05, &"constructor": 1.0, &"recolector": 0.35
	}
	assert_eq(Professions.choose(data, needs), &"constructor", "la obra es urgencia máxima")


func test_each_profession_has_a_visible_tool() -> void:
	for profession: StringName in Professions.LIST:
		var prop: Node3D = ProfessionProp.build(profession)
		assert_true(prop != null, "%s lleva herramienta a la espalda" % profession)
		if prop != null:
			assert_true(prop.get_child_count() >= 1, "la herramienta tiene piezas")
			prop.free()
	assert_true(ProfessionProp.build(&"") == null, "sin oficio: sin herramienta")


func test_favored_kinds_map_to_board() -> void:
	assert_eq(Professions.favored_kinds(&"lenador"), [&"chop"] as Array[StringName])
	assert_eq(Professions.favored_kinds(&"constructor"), [&"build", &"supply"] as Array[StringName])
	assert_true(Professions.favored_kinds(&"").is_empty(), "sin oficio: sin preferencia")


func test_board_bonus_tips_within_priority_only() -> void:
	GameState.setup_new_game(31415)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var near: Node3D = Node3D.new()
	var far: Node3D = Node3D.new()
	tree.root.add_child(near)
	tree.root.add_child(far)
	near.global_position = Vector3(5.0, 0.0, 0.0)
	far.global_position = Vector3(30.0, 0.0, 0.0)
	var near_id: int = EntityRegistry.register(near, &"tree")
	var far_id: int = EntityRegistry.register(far, &"tree")
	# Misma prioridad: el bonus del oficio gana a la distancia
	TaskBoard.publish(&"haul", near_id, {}, 5)
	TaskBoard.publish(&"chop", far_id, {}, 5)
	var favored: Array[StringName] = [&"chop"]
	var picked: TaskBoard.Task = TaskBoard.best_task_for(1, Vector3.ZERO, [], -1, favored)
	assert_eq(picked.kind, &"chop", "dentro de la prioridad, manda el oficio")
	# Prioridad urgente: el oficio NO se salta el bloque de 1000
	TaskBoard.publish(&"haul", near_id, {}, 3)
	picked = TaskBoard.best_task_for(1, Vector3.ZERO, [], -1, favored)
	assert_eq(picked.kind, &"haul", "una urgencia (3) no se pierde por el oficio")
	near.free()
	far.free()
	EntityRegistry.clear()
	TaskBoard.clear()
	GameState.world_seed = 0
