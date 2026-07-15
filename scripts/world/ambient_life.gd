class_name AmbientLife
extends Node3D
## Ambiente vivo (S3): luciérnagas al anochecer y hojas al viento en otoño,
## siguiendo a la cámara para que allá donde mire el jugador el valle esté
## VIVO. Todo GPU y barato: cero coste en el tick de simulación.

var _fireflies: GPUParticles3D
var _leaves: GPUParticles3D
var _rig: Node3D


func _ready() -> void:
	_fireflies = _make_fireflies()
	add_child(_fireflies)
	_leaves = _make_leaves()
	add_child(_leaves)


func _process(_delta: float) -> void:
	if _rig == null:
		var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
		if rigs.is_empty():
			return
		_rig = rigs[0] as Node3D
	# Los emisores siguen el punto que mira la cámara (pivote pegado al suelo)
	var focus: Vector3 = _rig.global_position
	_fireflies.global_position = focus + Vector3(0.0, 0.6, 0.0)
	_leaves.global_position = focus + Vector3(0.0, 9.0, 0.0)
	# Luciérnagas solo de anochecer/noche; hojas solo en otoño y de día
	var night: bool = SimClock.get_phase() >= SimClock.Phase.DUSK
	_fireflies.emitting = night
	var autumn: bool = SimClock.get_season() == SimClock.Season.AUTUMN
	_leaves.emitting = autumn and not night


func _make_fireflies() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Fireflies"
	particles.amount = 70
	particles.lifetime = 6.0
	particles.preprocess = 3.0
	particles.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 10, 60))
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(28.0, 3.5, 28.0)
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 180.0
	proc.gravity = Vector3.ZERO
	proc.initial_velocity_min = 0.15
	proc.initial_velocity_max = 0.5
	proc.scale_min = 0.5
	proc.scale_max = 1.2
	# Parpadeo: la escala oscila en el ciclo de vida (curva sencilla)
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(0.6, 0.2))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_tex: CurveTexture = CurveTexture.new()
	curve_tex.curve = curve
	proc.scale_curve = curve_tex
	particles.process_material = proc
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color("#EAE06A")
	mat.emission_enabled = true
	mat.emission = Color("#F4EC7E")
	mat.emission_energy_multiplier = 3.0
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.emitting = false
	return particles


func _make_leaves() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Leaves"
	particles.amount = 40
	particles.lifetime = 7.0
	particles.preprocess = 4.0
	particles.visibility_aabb = AABB(Vector3(-32, -14, -32), Vector3(64, 20, 64))
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(30.0, 0.5, 30.0)
	proc.direction = Vector3(0.3, -1.0, 0.1)
	proc.spread = 25.0
	proc.gravity = Vector3(0.4, -0.9, 0.2)
	proc.initial_velocity_min = 0.4
	proc.initial_velocity_max = 1.0
	proc.angular_velocity_min = -90.0
	proc.angular_velocity_max = 90.0
	proc.scale_min = 0.7
	proc.scale_max = 1.3
	particles.process_material = proc
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.16, 0.11)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color("#C08A3E")
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.emitting = false
	return particles
