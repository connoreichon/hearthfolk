class_name CitizenVisual
extends Node3D
## Figura humana estilizada de primitivas biseladas (§5.3) + animación
## procedural (§5.4). Prohibido dejar cápsulas como resultado final.

const STEPS_PER_METER: float = 1.9
const LEG_SWING_DEG: float = 25.0
const ARM_SWING_DEG: float = 20.0
const LEAN_DEG: float = 3.0

var mode: StringName = &"idle"
## Estilo del trabajo en curso: &"chop" hachazo ancho · &"build" martilleo ·
## &"farm" azadonazo · &"plant" siembra agachado. Fijado por los estados.
var work_style: StringName = &"chop"

var _phase: float = 0.0
var _work_cycle: float = 0.85
var _hand_tool: Node3D
var _speed: float = 0.0
var _look_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _look_timer: float = 0.0
var _look_target: float = 0.0
var _base_hips_y: float = 0.62
var _work_t: float = 0.0

var _hips: Node3D
var _torso: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _chest: MeshInstance3D
var _waist: MeshInstance3D
var _leg_meshes: Array[MeshInstance3D] = []
var _arm_meshes: Array[MeshInstance3D] = []
var _loincloth: MeshInstance3D
var _belt: MeshInstance3D
var _hands_marker: Marker3D
var _back_mount: Marker3D
var _tool_prop: Node3D
var _tool_profession: StringName = &""
var _data: CitizenData
## Guardarropa por progreso (orden del dueño «empiezan casi sin ropa»):
## −1 sin aplicar · 0 taparrabos (pieles mínimas) · 1 túnica · 2 ropa entera.
var _wardrobe_tier: int = -1


func setup(data: CitizenData, look_seed: int) -> void:
	name = "Visual"
	_data = data
	_look_rng.seed = look_seed
	scale = Vector3.ONE * data.height_scale

	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0.0, _base_hips_y, 0.0)
	add_child(_hips)

	_leg_l = _limb_pivot("LegL", Vector3(-0.09, 0.0, 0.0))
	_leg_r = _limb_pivot("LegR", Vector3(0.09, 0.0, 0.0))
	_hips.add_child(_leg_l)
	_hips.add_child(_leg_r)
	_leg_meshes.clear()
	for leg: Node3D in [_leg_l, _leg_r]:
		var leg_mesh: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.14, 0.58, 0.17), 0.035), data.pants_color, "Mesh"
		)
		leg_mesh.position = Vector3(0.0, -0.29, 0.0)
		leg.add_child(leg_mesh)
		_leg_meshes.append(leg_mesh)

	_torso = Node3D.new()
	_torso.name = "Torso"
	_hips.add_child(_torso)
	_waist = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.3, 0.22, 0.19), 0.035), data.pants_color, "Waist"
	)
	_waist.position = Vector3(0.0, 0.1, 0.0)
	_torso.add_child(_waist)
	_chest = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.36, 0.34, 0.21), 0.045), data.shirt_color, "Chest"
	)
	_chest.position = Vector3(0.0, 0.35, 0.0)
	_torso.add_child(_chest)
	# Taparrabos de pieles (guardarropa 0) y cinturón (guardarropa 2)
	_loincloth = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.32, 0.2, 0.22), 0.04), Color("#7A5A3C"), "Loincloth"
	)
	_loincloth.position = Vector3(0.0, 0.02, 0.0)
	_loincloth.visible = false
	_torso.add_child(_loincloth)
	_belt = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.37, 0.06, 0.22), 0.02), Color("#4A382A"), "Belt"
	)
	_belt.position = Vector3(0.0, 0.2, 0.0)
	_belt.visible = false
	_torso.add_child(_belt)

	_arm_l = _limb_pivot("ArmL", Vector3(-0.235, 0.46, 0.0))
	_arm_r = _limb_pivot("ArmR", Vector3(0.235, 0.46, 0.0))
	_torso.add_child(_arm_l)
	_torso.add_child(_arm_r)
	_arm_meshes.clear()
	for arm: Node3D in [_arm_l, _arm_r]:
		var arm_mesh: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.1, 0.44, 0.12), 0.03), data.shirt_color, "Mesh"
		)
		arm_mesh.position = Vector3(0.0, -0.2, 0.0)
		arm.add_child(arm_mesh)
		_arm_meshes.append(arm_mesh)
		var hand: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.085, 0.085, 0.085), 0.02), data.skin_color, "Hand"
		)
		hand.position = Vector3(0.0, -0.46, 0.0)
		arm.add_child(hand)

	var neck: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.cylinder(0.05, 0.05, 0.08, 7), data.skin_color, "Neck"
	)
	neck.position = Vector3(0.0, 0.52, 0.0)
	_torso.add_child(neck)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 0.6, 0.0)
	_torso.add_child(_head)
	var face: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.155, 6, 9, 1.12), data.skin_color, "Face"
	)
	face.position = Vector3(0.0, 0.15, 0.0)
	_head.add_child(face)
	var hair_cap: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.low_sphere(0.165, 5, 9, 0.62), data.hair_color, "HairCap"
	)
	hair_cap.position = Vector3(0.0, 0.24, -0.015)
	_head.add_child(hair_cap)
	var fringe: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.beveled_box(Vector3(0.2, 0.06, 0.05), 0.015), data.hair_color, "Fringe"
	)
	fringe.position = Vector3(0.0, 0.26, 0.13)
	_head.add_child(fringe)
	# Ojos: dos puntitos oscuros — la cara deja de ser una bola muda
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.032, 0.04, 0.02), 0.008), Color("#2A211B"), "Eye"
		)
		eye.position = Vector3(side * 0.055, 0.16, 0.135)
		_head.add_child(eye)

	_hands_marker = Marker3D.new()
	_hands_marker.name = "Hands"
	_hands_marker.position = Vector3(0.0, 0.25, 0.28)
	_torso.add_child(_hands_marker)

	# Soporte a la espalda para la herramienta de oficio (§S2 «verlo todo»)
	_back_mount = Marker3D.new()
	_back_mount.name = "BackMount"
	_back_mount.position = Vector3(0.0, 0.34, -0.16)
	_torso.add_child(_back_mount)
	set_profession(data.profession)


func set_motion(horizontal_speed: float) -> void:
	_speed = horizontal_speed


func hands_node() -> Marker3D:
	return _hands_marker


## Guardarropa por progreso del asentamiento (orden del dueño): los colonos
## EMPIEZAN casi sin ropa y se visten conforme su aldea crece.
## 0 = taparrabos de pieles (torso y piernas desnudos) · 1 = túnica sencilla
## (piernas desnudas) · 2 = ropa entera con cinturón. Idempotente.
func set_wardrobe(tier: int, biome_tint: Color = Color(0, 0, 0, 0)) -> void:
	if _data == null or tier == _wardrobe_tier:
		return
	_wardrobe_tier = tier
	var skin: Color = _data.skin_color
	var pelt: Color = Color("#7A5A3C")
	# Ropa teñida por el BIOMA del hogar (aldeas del mismo bioma visten
	# parecido, biomas lejanos distinto — orden del dueño). El color
	# personal aporta variedad dentro del mismo paño.
	var shirt: Color = _data.shirt_color
	if biome_tint.a > 0.0:
		shirt = _data.shirt_color.lerp(biome_tint, 0.55)
	match tier:
		0:
			_chest.material_override = MeshLib.matte(skin)
			_waist.material_override = MeshLib.matte(pelt)
			for mesh: MeshInstance3D in _arm_meshes + _leg_meshes:
				mesh.material_override = MeshLib.matte(skin)
			_loincloth.visible = true
			_belt.visible = false
		1:
			_chest.material_override = MeshLib.matte(shirt)
			_waist.material_override = MeshLib.matte(shirt.darkened(0.15))
			for mesh: MeshInstance3D in _arm_meshes:
				mesh.material_override = MeshLib.matte(shirt)
			for mesh: MeshInstance3D in _leg_meshes:
				mesh.material_override = MeshLib.matte(skin)
			_loincloth.visible = false
			_belt.visible = false
		_:
			_chest.material_override = MeshLib.matte(shirt)
			_waist.material_override = MeshLib.matte(_data.pants_color)
			for mesh: MeshInstance3D in _arm_meshes:
				mesh.material_override = MeshLib.matte(shirt)
			for mesh: MeshInstance3D in _leg_meshes:
				mesh.material_override = MeshLib.matte(_data.pants_color)
			_loincloth.visible = false
			_belt.visible = true


## Coloca (o retira) la herramienta del oficio a la espalda. Idempotente:
## no reconstruye si el oficio no cambió (se llama cada vez que el panel
## refresca, pero el prop solo se rehace al cambiar de verdad de oficio).
func set_profession(profession: StringName) -> void:
	if _back_mount == null or profession == _tool_profession:
		return
	_tool_profession = profession
	if _tool_prop != null and is_instance_valid(_tool_prop):
		_tool_prop.queue_free()
		_tool_prop = null
	# Sin herramientas talladas no hay nada que colgarse a la espalda
	# (progresión del dueño: primero se las craftean junto a la hoguera).
	if _data != null and not _data.has_tools:
		return
	var prop: Node3D = ProfessionProp.build(profession)
	if prop == null:
		return
	if profession == &"recolector":
		# El cesto cuelga bajo y recto sobre los riñones
		prop.position = Vector3(0.0, -0.14, -0.04)
		prop.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
	else:
		# Hachas, azadas y mazas cruzan la espalda en diagonal
		prop.position = Vector3(0.03, -0.02, -0.02)
		prop.rotation = Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(24.0))
	_back_mount.add_child(prop)
	_tool_prop = prop


## El colono acaba de tallar sus herramientas: cuelga la de su oficio.
func refresh_tool() -> void:
	_tool_profession = &" "
	set_profession(_data.profession if _data != null else &"")


## SACA la herramienta: de la espalda a la mano derecha, con un toque de
## resorte. Colgada del brazo, GOLPEA con él en _animate_work — se VE usar
## el hacha, la maza, la azada o la pala (orden del dueño).
func equip_tool() -> void:
	if _data == null or not _data.has_tools or _hand_tool != null or _arm_r == null:
		return
	var prop: Node3D = ProfessionProp.build(_data.profession)
	if prop == null:
		return
	if _tool_prop != null and is_instance_valid(_tool_prop):
		_tool_prop.visible = false
	# Empuñadura: el mango sigue el eje del brazo; la cabeza mira al frente
	prop.position = Vector3(0.02, -0.5, 0.05)
	prop.rotation_degrees = Vector3(100.0, 0.0, 0.0)
	_arm_r.add_child(prop)
	prop.scale = Vector3.ONE * 0.55
	var tween: Tween = prop.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(prop, "scale", Vector3.ONE, 0.16)
	_hand_tool = prop


## GUARDA la herramienta: fuera de la mano, de vuelta a la espalda.
func stow_tool() -> void:
	if _hand_tool != null:
		if is_instance_valid(_hand_tool):
			_hand_tool.queue_free()
		_hand_tool = null
	if _tool_prop != null and is_instance_valid(_tool_prop):
		_tool_prop.visible = true


## Estilo y compás del trabajo: cada oficio golpea distinto, y el ciclo se
## sincroniza con el golpe real (la tala baja el hacha cuando muerde).
func set_work_style(style: StringName, cycle_seconds: float = 0.85) -> void:
	work_style = style
	_work_cycle = clampf(cycle_seconds, 0.35, 2.4)
	_work_t = 0.0


func _process(delta: float) -> void:
	if _speed > 0.1:
		_animate_walk(delta)
	else:
		match mode:
			&"work":
				_animate_work(delta)
			&"rest":
				_animate_rest(delta)
				return
			&"eat":
				_animate_eat(delta)
			_:
				_animate_idle(delta)
	# Volver de tumbado si no está descansando
	rotation.x = lerp_angle(rotation.x, 0.0, 1.0 - exp(-5.0 * delta))


func _animate_walk(delta: float) -> void:
	_phase += delta * _speed * STEPS_PER_METER * TAU * 0.5
	var swing: float = sin(_phase)
	var k: float = 1.0 - exp(-14.0 * delta)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, deg_to_rad(LEG_SWING_DEG) * swing, k)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, -deg_to_rad(LEG_SWING_DEG) * swing, k)
	if mode != &"carry":
		_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, -deg_to_rad(ARM_SWING_DEG) * swing, k)
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, deg_to_rad(ARM_SWING_DEG) * swing, k)
	else:
		_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, deg_to_rad(-58.0), k)
		_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, deg_to_rad(-58.0), k)
	_hips.position.y = _base_hips_y + absf(sin(_phase)) * 0.035
	var lean: float = LEAN_DEG if mode != &"carry" else -LEAN_DEG * 1.6
	_torso.rotation.x = lerp_angle(_torso.rotation.x, deg_to_rad(lean), k)
	_head.rotation.y = lerp_angle(_head.rotation.y, 0.0, k)


func _animate_idle(delta: float) -> void:
	var k: float = 1.0 - exp(-6.0 * delta)
	_phase = 0.0
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, 0.0, k)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, 0.0, k)
	_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, 0.0, k)
	_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, 0.0, k)
	_torso.rotation.x = lerp_angle(_torso.rotation.x, 0.0, k)
	_hips.position.y = lerpf(_hips.position.y, _base_hips_y, k)
	# Respiración: escala sutil del pecho (delta real, cosmético)
	_work_t += delta
	_chest.scale = Vector3.ONE * (1.0 + sin(_work_t * 2.2) * 0.015)
	# Micro-mirada cada 2–5 s
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = _look_rng.randf_range(2.0, 5.0)
		_look_target = _look_rng.randf_range(-0.5, 0.5)
	_head.rotation.y = lerp_angle(_head.rotation.y, _look_target, k * 0.6)


## Trabajar: cada oficio tiene SU gesto (orden del dueño: que se vea usar
## la herramienta). El ciclo lo marca el estado (sincronía con el golpe).
func _animate_work(delta: float) -> void:
	_work_t += delta
	var cycle: float = fmod(_work_t, _work_cycle) / _work_cycle
	match work_style:
		&"build":
			# Martilleo corto y seco, de arriba abajo
			_swing_arms(cycle, -55.0, 8.0, 0.55, 10.0)
		&"farm":
			# Azadonazo: arco medio con la espalda doblada
			_swing_arms(cycle, -75.0, 18.0, 0.65, 20.0)
		&"plant":
			# Sembrar: casi en cuclillas, manos suaves hacia la tierra
			var k: float = 1.0 - exp(-6.0 * delta)
			var dip: float = sin(cycle * TAU) * 8.0
			_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, deg_to_rad(-38.0 + dip), k)
			_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, deg_to_rad(-42.0 - dip), k)
			_torso.rotation.x = lerp_angle(_torso.rotation.x, deg_to_rad(26.0), k)
			_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, deg_to_rad(38.0), k)
			_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, deg_to_rad(30.0), k)
			_hips.position.y = lerpf(_hips.position.y, _base_hips_y * 0.72, k)
			return
		_:
			# Hachazo ancho: el gesto clásico del leñador
			_swing_arms(cycle, -95.0, 10.0, 0.7, 12.0)
	_hips.position.y = _base_hips_y


## Arco de golpeo: la mano de la HERRAMIENTA lleva la fuerza; la otra
## acompaña a medias (más humano que dos brazos clavados en espejo).
func _swing_arms(cycle: float, from_deg: float, to_deg: float, hit_at: float, lean: float) -> void:
	var arc: float
	if cycle < hit_at:
		arc = lerpf(from_deg, to_deg, ease(cycle / hit_at, 0.6))
	else:
		arc = lerpf(to_deg, from_deg, (cycle - hit_at) / (1.0 - hit_at))
	_arm_r.rotation.x = deg_to_rad(arc)
	_arm_l.rotation.x = deg_to_rad(arc * 0.45 - 8.0)
	_torso.rotation.x = deg_to_rad(lean + arc * 0.08)
	var squash: float = 1.0 - (0.06 if absf(cycle - hit_at) < 0.06 else 0.0)
	_hips.scale = Vector3(1.0, squash, 1.0)


## Dormir: tumbado, respiración lenta (§5.4).
func _animate_rest(delta: float) -> void:
	var k: float = 1.0 - exp(-4.0 * delta)
	rotation.x = lerp_angle(rotation.x, deg_to_rad(-84.0), k)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, deg_to_rad(6.0), k)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, deg_to_rad(-4.0), k)
	_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, deg_to_rad(12.0), k)
	_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, deg_to_rad(-10.0), k)
	_torso.rotation.x = lerp_angle(_torso.rotation.x, 0.0, k)
	_hips.position.y = lerpf(_hips.position.y, _base_hips_y * 0.55, k)
	_work_t += delta
	_chest.scale = Vector3.ONE * (1.0 + sin(_work_t * 1.1) * 0.025)


## Comer: sentado, mano hacia la cara en bucle.
func _animate_eat(delta: float) -> void:
	var k: float = 1.0 - exp(-6.0 * delta)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, deg_to_rad(82.0), k)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, deg_to_rad(78.0), k)
	_hips.position.y = lerpf(_hips.position.y, _base_hips_y * 0.55, k)
	_work_t += delta
	var chew: float = deg_to_rad(-95.0 + sin(_work_t * 4.0) * 18.0)
	_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, chew, k)
	_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, deg_to_rad(-20.0), k)
	_torso.rotation.x = lerp_angle(_torso.rotation.x, deg_to_rad(6.0), k)


func _limb_pivot(pivot_name: String, offset: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = pivot_name
	pivot.position = offset
	return pivot
