class_name TreeEntity
extends StaticBody3D
## Árbol persistente. Adulto: talable (hp 10, rinde 6 de madera en 3 haces).
## Joven: decorativo, no talable. Obstáculo de navegación dinámico
## (NavigationObstacle3D, no horneado: al caer no hay que rehornear).

const MAX_HP: int = 10
const WOOD_UNITS: int = 6
const LEAN_MAX_DEG: float = 6.0
const FALL_SECONDS: float = 1.2
const FADE_SECONDS: float = 0.6

static var _outline_hover: ShaderMaterial
static var _outline_marked: ShaderMaterial
static var _outline_invalid: ShaderMaterial

var entity_id: int = 0
var visual_seed: int = 0
var young: bool = false
var hp: int = MAX_HP
var marked: bool = false
var felled: bool = false

var _visual: Node3D
var _axe_marker: Node3D
var _tooltip: Label3D


static func create(seed_value: int, is_young: bool) -> TreeEntity:
	var tree: TreeEntity = TreeEntity.new()
	tree.name = "TreeYoung" if is_young else "Tree"
	tree.visual_seed = seed_value
	tree.young = is_young
	tree.collision_layer = (1 << 2) | (1 << 7)
	tree.collision_mask = 0
	tree._visual = TreeGen.build_visual(seed_value, is_young)
	tree.add_child(tree._visual)
	tree.add_child(TreeGen.trunk_collision_shape(is_young))
	var obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	obstacle.name = "NavObstacle"
	obstacle.radius = 0.5 if not is_young else 0.28
	obstacle.avoidance_enabled = true
	tree.add_child(obstacle)
	tree.add_to_group(&"trees")
	tree.add_to_group(&"persistent")
	tree.add_to_group(&"selectable")
	return tree


func _ready() -> void:
	if entity_id == 0:
		entity_id = EntityRegistry.register(self, &"tree")


func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)


func choppable() -> bool:
	return not young and not felled


func set_marked(value: bool) -> void:
	if felled or young or marked == value:
		return
	marked = value
	_apply_overlay(_marked_material() if marked else null)
	if marked:
		if _axe_marker == null:
			_axe_marker = _build_axe_marker()
			add_child(_axe_marker)
		_axe_marker.visible = true
		EventBus.tree_marked.emit(entity_id)
	else:
		if _axe_marker != null:
			_axe_marker.visible = false
		EventBus.tree_unmarked.emit(entity_id)


func set_hovered(value: bool, valid: bool = true) -> void:
	if felled:
		return
	if value:
		if not valid:
			_apply_overlay(_invalid_material())
			_show_tooltip("Demasiado joven")
		elif not marked:
			_apply_overlay(_hover_material())
	else:
		_apply_overlay(_marked_material() if marked else null)
		_hide_tooltip()


## Un golpe de hacha. Devuelve true si el árbol ha caído con este golpe.
func take_hit() -> bool:
	if felled:
		return false
	hp -= 1
	var lean: float = deg_to_rad(LEAN_MAX_DEG) * (1.0 - float(hp) / float(MAX_HP))
	_visual.rotation.x = lean
	_spawn_splinters()
	AudioDirector.play_at(&"chop", global_position, -4.0)
	if hp <= 0:
		_fall()
		return true
	return false


func _fall() -> void:
	felled = true
	set_marked(false)
	_apply_overlay(null)
	_hide_tooltip()
	collision_layer = 0
	var obstacle: NavigationObstacle3D = get_node_or_null("NavObstacle")
	if obstacle != null:
		obstacle.queue_free()
	var dir: Vector3 = _safe_fall_direction()
	EventBus.tree_felled.emit(entity_id, global_position, WOOD_UNITS)
	_animate_fall(dir)


## Sector de 360° con menos entidades en 5 m; nunca hacia un habitante
## ni hacia una obra (§8.1). Además avisa para que se aparten (§16).
func _safe_fall_direction() -> Vector3:
	var best_dir: Vector3 = Vector3.FORWARD
	var best_score: float = INF
	for sector: int in 8:
		var ang: float = TAU * float(sector) / 8.0
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var score: float = 0.0
		for node: Node in get_tree().get_nodes_in_group(&"citizens"):
			score += _sector_penalty(node as Node3D, dir, 100.0)
		for node: Node in get_tree().get_nodes_in_group(&"construction_sites"):
			score += _sector_penalty(node as Node3D, dir, 50.0)
		for node: Node in get_tree().get_nodes_in_group(&"trees"):
			if node != self:
				score += _sector_penalty(node as Node3D, dir, 1.0)
		if score < best_score:
			best_score = score
			best_dir = dir
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		var to_citizen: Vector3 = citizen.global_position - global_position
		to_citizen.y = 0.0
		if to_citizen.length() < 5.0 and to_citizen.normalized().dot(best_dir) > 0.6:
			citizen.dodge_away(global_position, best_dir)
	return best_dir


func _sector_penalty(node: Node3D, dir: Vector3, weight: float) -> float:
	if node == null:
		return 0.0
	var offset: Vector3 = node.global_position - global_position
	offset.y = 0.0
	var dist: float = offset.length()
	if dist > 5.0 or dist < 0.01:
		return 0.0
	var alignment: float = offset.normalized().dot(dir)
	if alignment <= 0.3:
		return 0.0
	return weight * alignment * (5.0 - dist)


func _animate_fall(dir: Vector3) -> void:
	var yaw: float = atan2(dir.x, dir.z)
	_visual.rotation.y = -yaw
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_visual, "rotation:x", deg_to_rad(84.0), FALL_SECONDS * 0.75)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_visual, "rotation:x", deg_to_rad(88.0), FALL_SECONDS * 0.25)
	tween.tween_callback(_on_fall_impact.bind(dir))


func _on_fall_impact(dir: Vector3) -> void:
	_spawn_dust(global_position + dir * 2.2)
	var fade: Tween = create_tween()
	fade.tween_interval(0.25)
	fade.tween_property(_visual, "scale", Vector3.ONE * 0.02, FADE_SECONDS)
	fade.tween_callback(_spawn_wood_and_stump.bind(dir))


func _spawn_wood_and_stump(dir: Vector3) -> void:
	var parent: Node = get_parent()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = visual_seed + 77
	var impact: Vector3 = global_position + dir * 2.0
	for _bundle_i: int in 3:
		var item: ResourceItem = ResourceItem.create(&"wood", 2, rng.randi())
		var offset: Vector3 = Vector3(rng.randf_range(-1.1, 1.1), 0.0, rng.randf_range(-1.1, 1.1))
		var pos: Vector3 = impact + offset
		if GameState.terrain != null:
			pos.y = GameState.terrain.get_height(pos.x, pos.z)
		parent.add_child(item)
		item.global_position = pos
		item.rotation.y = rng.randf() * TAU
		_pop_in(item)
	var stump: StumpEntity = StumpEntity.create(visual_seed)
	parent.add_child(stump)
	stump.global_position = global_position
	queue_free()


func _pop_in(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.6
	var tween: Tween = node.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector3.ONE, 0.2)


func _spawn_splinters() -> void:
	_one_shot_particles(
		global_position + Vector3(0.0, 1.0, 0.0), PaletteData.get_default().wood_light, 8, 0.5
	)


func _spawn_dust(at: Vector3) -> void:
	_one_shot_particles(at + Vector3(0.0, 0.3, 0.0), PaletteData.get_default().dirt_light, 16, 0.9)


func _one_shot_particles(at: Vector3, color: Color, count: int, life: float) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 1.0
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 60.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 2.6
	proc.gravity = Vector3(0.0, -6.0, 0.0)
	proc.scale_min = 0.04
	proc.scale_max = 0.1
	proc.color = color
	particles.process_material = proc
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	quad.material = mat
	particles.draw_pass_1 = quad
	get_parent().add_child(particles)
	particles.global_position = at
	particles.emitting = true
	var cleanup: Tween = particles.create_tween()
	cleanup.tween_interval(life + 0.4)
	cleanup.tween_callback(particles.queue_free)


func _apply_overlay(mat: Material) -> void:
	for child: Node in _visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_overlay = mat


func _build_axe_marker() -> Node3D:
	var palette: PaletteData = PaletteData.get_default()
	var marker: Node3D = Node3D.new()
	marker.name = "AxeMarker"
	marker.position = Vector3(0.0, 4.1, 0.0)
	var handle: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.035, 0.03, 0.5, 6), palette.wood_light, "Handle"
	)
	handle.position = Vector3(0.0, -0.25, 0.0)
	marker.add_child(handle)
	var head: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.26, 0.14, 0.05), 0.02), palette.accent, "Head"
	)
	head.position = Vector3(0.09, 0.16, 0.0)
	marker.add_child(head)
	var bob: Tween = marker.create_tween().set_loops()
	bob.tween_property(marker, "position:y", 4.35, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(marker, "position:y", 4.1, 0.9).set_trans(Tween.TRANS_SINE)
	var spin: Tween = marker.create_tween().set_loops()
	spin.tween_property(marker, "rotation:y", TAU, 4.0).from(0.0)
	return marker


func _show_tooltip(text: String) -> void:
	if _tooltip == null:
		_tooltip = Label3D.new()
		_tooltip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tooltip.font_size = 44
		_tooltip.outline_size = 10
		_tooltip.modulate = PaletteData.get_default().ui_text
		_tooltip.outline_modulate = PaletteData.get_default().ui_panel
		_tooltip.position = Vector3(0.0, 2.2, 0.0)
		add_child(_tooltip)
	_tooltip.text = text
	_tooltip.visible = true


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false


static func _hover_material() -> ShaderMaterial:
	if _outline_hover == null:
		_outline_hover = _make_outline(PaletteData.get_default().ui_text)
	return _outline_hover


static func _marked_material() -> ShaderMaterial:
	if _outline_marked == null:
		_outline_marked = _make_outline(PaletteData.get_default().accent)
	return _outline_marked


static func _invalid_material() -> ShaderMaterial:
	if _outline_invalid == null:
		_outline_invalid = _make_outline(PaletteData.get_default().roof)
	return _outline_invalid


static func _make_outline(color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/outline.gdshader")
	mat.set_shader_parameter(&"outline_color", color)
	mat.set_shader_parameter(&"width", 0.04)
	return mat


func entity_kind() -> StringName:
	return &"tree"


func save_data() -> Dictionary:
	return {
		"id": entity_id,
		"seed": visual_seed,
		"young": young,
		"hp": hp,
		"marked": marked,
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot_y": rotation.y,
		"scale": scale.x,
	}


func load_data(d: Dictionary) -> void:
	visual_seed = int(d.get("seed", 0))
	young = bool(d.get("young", false))
	hp = int(d.get("hp", MAX_HP))
	marked = false
	var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(d.get("rot_y", 0.0))
	scale = Vector3.ONE * float(d.get("scale", 1.0))
	if bool(d.get("marked", false)):
		set_marked(true)
