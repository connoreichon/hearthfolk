class_name WeatherSystem
extends Node3D
## METEOROLOGÍA VIVA (Build 004, orden del dueño): nubes que NO se ven
## pero cuya SOMBRA cruza el valle (quads con forma de nube en modo
## SHADOWS_ONLY), frentes de LLUVIA aleatorios que nacen en las zonas
## húmedas y mueren en las secas, y NIEVE cayendo donde el clima es muy
## frío. La humedad emerge del clima: llueve en bosques y tundra, poco en
## la sabana, casi nunca en el desierto — biomas y tiempo, una sola lógica.

## Frentes de lluvia simultáneos como mucho.
const MAX_FRONTS: int = 2
## Nubes ambientales SIEMPRE vagando (sin lluvia): el cielo vive.
const AMBIENT_CLOUDS: int = 4
const CLOUD_ALTITUDE: float = 58.0

## Silueta de nube compartida (blobby, generada una vez).
static var _cloud_tex: ImageTexture

## {center: Vector2, radius: float, drift: Vector2, life: float,
##  clouds: Array[Node3D], snowy: bool}
var _fronts: Array[Dictionary] = []
var _ambient: Array[Node3D] = []
var _spawn_timer: float = 40.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _moisture_noise: FastNoiseLite = FastNoiseLite.new()
var _wind: Vector2 = Vector2(1.0, 0.35)
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _day_night: DayNight


func _ready() -> void:
	_rng.seed = GameState.derive_seed(["weather"])
	_moisture_noise.seed = GameState.derive_seed(["moisture"])
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture_noise.frequency = 0.0016
	_wind = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.2, 3.6)
	for _i: int in AMBIENT_CLOUDS:
		var cloud: Node3D = _make_cloud(_rng.randf_range(0.5, 0.8))
		cloud.position = Vector3(
			_rng.randf_range(-400.0, 400.0), CLOUD_ALTITUDE, _rng.randf_range(-400.0, 400.0)
		)
		add_child(cloud)
		_ambient.append(cloud)
	_rain = _make_precipitation(false)
	add_child(_rain)
	_snow = _make_precipitation(true)
	add_child(_snow)
	SimClock.sim_tick.connect(_on_sim_tick)


func set_day_night(day_night: DayNight) -> void:
	_day_night = day_night


## Humedad del punto 0..1: emerge del CLIMA (los biomas y la lluvia
## comparten lógica): el desierto casi nunca ve llover, el bosque sí.
func moisture(x: float, z: float) -> float:
	var world_gen: WorldGen = GameState.world_gen
	var base: float = 0.5 + _moisture_noise.get_noise_2d(x, z) * 0.5
	if world_gen != null:
		base *= 1.0 - world_gen.arid_weight(x, z) * 0.85
	return clampf(base, 0.0, 1.0)


func _on_sim_tick(dt: float) -> void:
	if not is_inside_tree():
		return
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_timer = _rng.randf_range(70.0, 200.0)
		_try_spawn_front()
	for i: int in range(_fronts.size() - 1, -1, -1):
		var front: Dictionary = _fronts[i]
		front["life"] = float(front["life"]) - dt
		front["center"] = (front["center"] as Vector2) + _wind * dt * 0.8
		for cloud: Node3D in front["clouds"]:
			cloud.position.x += _wind.x * dt * 0.8
			cloud.position.z += _wind.y * dt * 0.8
		if float(front["life"]) <= 0.0:
			for cloud: Node3D in front["clouds"]:
				cloud.queue_free()
			_fronts.remove_at(i)


func _process(delta: float) -> void:
	# Nubes ambientales: derivan con el viento y dan la vuelta al valle
	var half: float = 512.0
	if GameState.world_gen != null:
		half = GameState.world_gen.map_half
	for cloud: Node3D in _ambient:
		cloud.position.x += _wind.x * delta * 0.55
		cloud.position.z += _wind.y * delta * 0.55
		if absf(cloud.position.x) > half + 120.0 or absf(cloud.position.z) > half + 120.0:
			cloud.position.x = -signf(_wind.x) * (half + 100.0)
			cloud.position.z = _rng.randf_range(-half, half)
	_update_precipitation()


## La lluvia/nieve se RENDERIZA solo alrededor de la cámara (el estado del
## frente es lógico): si la cámara está bajo un frente, cae agua — o copos
## si la zona es de clima muy frío.
func _update_precipitation() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var cam_pos: Vector3 = cam.global_position
	var under: Dictionary = {}
	for front: Dictionary in _fronts:
		var center: Vector2 = front["center"]
		if Vector2(cam_pos.x, cam_pos.z).distance_to(center) < float(front["radius"]):
			under = front
			break
	var raining: bool = not under.is_empty() and not bool(under.get("snowy", false))
	var snowing: bool = not under.is_empty() and bool(under.get("snowy", false))
	_rain.emitting = raining
	_snow.emitting = snowing
	var anchor: Vector3 = Vector3(cam_pos.x, cam_pos.y + 22.0, cam_pos.z)
	_rain.global_position = anchor
	_snow.global_position = anchor
	if _day_night != null:
		_day_night.weather_dim = 0.22 if not under.is_empty() else 0.0


func _try_spawn_front() -> void:
	if _fronts.size() >= MAX_FRONTS or GameState.world_gen == null:
		return
	var world_gen: WorldGen = GameState.world_gen
	var half: float = world_gen.map_half - 60.0
	# Nace donde la humedad manda: 12 sondeos, gana el más húmedo (si ni el
	# mejor llega a 0.35, hoy no llueve — las zonas secas lo son de verdad)
	var best: Vector2 = Vector2.ZERO
	var best_moisture: float = 0.0
	for _i: int in 12:
		var probe: Vector2 = Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
		var wet: float = moisture(probe.x, probe.y)
		if wet > best_moisture:
			best_moisture = wet
			best = probe
	if best_moisture < 0.35:
		return
	var snowy: bool = world_gen.snow_weight(best.x, best.y) > 0.45
	var front: Dictionary = {
		"center": best,
		"radius": _rng.randf_range(85.0, 150.0),
		"life": _rng.randf_range(80.0, 170.0),
		"snowy": snowy,
		"clouds": [] as Array[Node3D],
	}
	# El frente trae su séquito de nubes densas (sombras que pasan)
	for _i: int in 5:
		var cloud: Node3D = _make_cloud(_rng.randf_range(0.9, 1.3))
		cloud.position = Vector3(
			best.x + _rng.randf_range(-60.0, 60.0),
			CLOUD_ALTITUDE + _rng.randf_range(-6.0, 6.0),
			best.y + _rng.randf_range(-60.0, 60.0)
		)
		add_child(cloud)
		(front["clouds"] as Array[Node3D]).append(cloud)
	_fronts.append(front)
	EventBus.toast.emit(
		"Nieva sobre la tundra" if snowy else "Un frente de lluvia cruza el valle", &"info"
	)


## Nube INVISIBLE que solo proyecta sombra (orden del dueño: «que no se
## vean pero que se vea la sombra cuando pasa»). Quad con forma blobby y
## alpha scissor: la sombra tiene silueta de nube de verdad.
func _make_cloud(size_scale: float) -> Node3D:
	var cloud: MeshInstance3D = MeshInstance3D.new()
	cloud.name = "CloudShadow"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(120.0, 90.0) * size_scale
	quad.orientation = PlaneMesh.FACE_Y
	cloud.mesh = quad
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _cloud_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud.material_override = mat
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	cloud.rotation.y = _rng.randf() * TAU
	return cloud


## Silueta blobby determinista (metaballs suaves sobre un lienzo alpha).
static func _cloud_texture() -> ImageTexture:
	if _cloud_tex != null:
		return _cloud_tex
	var size: int = 96
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var blob_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	blob_rng.seed = 4242
	var blobs: Array[Vector3] = []
	for _i: int in 7:
		blobs.append(
			Vector3(
				blob_rng.randf_range(24.0, 72.0),
				blob_rng.randf_range(34.0, 62.0),
				blob_rng.randf_range(14.0, 24.0)
			)
		)
	for y: int in size:
		for x: int in size:
			var field: float = 0.0
			for blob: Vector3 in blobs:
				var d: float = Vector2(x - blob.x, y - blob.y).length()
				field += clampf(1.0 - d / blob.z, 0.0, 1.0)
			var a: float = 1.0 if field > 0.55 else 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_cloud_tex = ImageTexture.create_from_image(img)
	return _cloud_tex


func _make_precipitation(snowy: bool) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Snowfall" if snowy else "Rainfall"
	particles.emitting = false
	particles.amount = 900 if not snowy else 700
	particles.lifetime = 1.6 if not snowy else 4.5
	particles.visibility_aabb = AABB(Vector3(-40.0, -30.0, -40.0), Vector3(80.0, 60.0, 80.0))
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(34.0, 1.0, 34.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 3.0 if not snowy else 14.0
	mat.initial_velocity_min = 16.0 if not snowy else 1.4
	mat.initial_velocity_max = 20.0 if not snowy else 2.4
	mat.gravity = Vector3(0.0, -9.0 if not snowy else -0.6, 0.0)
	if snowy:
		mat.turbulence_enabled = true
		mat.turbulence_noise_strength = 0.5
		mat.turbulence_noise_scale = 3.0
	particles.process_material = mat
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.03, 0.5) if not snowy else Vector2(0.14, 0.14)
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.albedo_color = (
		Color(0.72, 0.8, 0.9, 0.32) if not snowy else Color(0.96, 0.97, 1.0, 0.85)
	)
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh
	return particles
