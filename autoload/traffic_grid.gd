extends Node
## Rejilla de tráfico (S3): acumula las pisadas de los colonos y las expone
## como textura al shader del terreno, que pinta senda de tierra donde se
## camina. Los caminos EMERGEN por el uso y se difuminan si se abandonan —
## no se pregeneran (docs/S3_DESIGN.md). Determinista NO (depende del vivir).

## 1 m por texel (mapa 1024 m): sendas finas de pie, no autopistas.
const RESOLUTION: int = 1024
const STAMP_CENTER: float = 0.02
const STAMP_NEIGHBOUR: float = 0.008
## Decaimiento diario: la ruta usada se mantiene, la abandonada se difumina.
const DAILY_DECAY: float = 0.96
## Subida a GPU como mucho cada medio segundo real (no en cada pisada).
const UPLOAD_INTERVAL: float = 0.5

var _image: Image
var _texture: ImageTexture
var _map_half: float = 512.0
var _dirty: bool = false
var _upload_cooldown: float = 0.0
var _active: bool = false


func _ready() -> void:
	SimClock.day_changed.connect(_on_day_changed)


## Arranca (o reinicia) la rejilla para un mundo de mitad `map_half` metros y
## la enchufa al material compartido del terreno. Idempotente por partida.
func setup(map_half: float) -> void:
	_map_half = map_half
	_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF)
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_texture = ImageTexture.create_from_image(_image)
	_active = true
	_dirty = false
	_upload_cooldown = 0.0
	var material: ShaderMaterial = MapGenerator.terrain_material(PaletteData.get_default())
	material.set_shader_parameter(&"traffic_tex", _texture)
	material.set_shader_parameter(&"map_extent", _map_half * 2.0)


## Una pisada en (x,z) del mundo: pincel pequeño sumado a la rejilla.
func stamp(world_pos: Vector3) -> void:
	if not _active:
		return
	var u: int = int((world_pos.x / (_map_half * 2.0) + 0.5) * float(RESOLUTION))
	var v: int = int((world_pos.z / (_map_half * 2.0) + 0.5) * float(RESOLUTION))
	if u < 1 or v < 1 or u >= RESOLUTION - 1 or v >= RESOLUTION - 1:
		return
	_add(u, v, STAMP_CENTER)
	_add(u - 1, v, STAMP_NEIGHBOUR)
	_add(u + 1, v, STAMP_NEIGHBOUR)
	_add(u, v - 1, STAMP_NEIGHBOUR)
	_add(u, v + 1, STAMP_NEIGHBOUR)
	_dirty = true


func _add(u: int, v: int, amount: float) -> void:
	var current: float = _image.get_pixel(u, v).r
	_image.set_pixel(u, v, Color(minf(1.0, current + amount), 0.0, 0.0, 1.0))


func _process(delta: float) -> void:
	if not _active:
		return
	_upload_cooldown -= delta
	if _dirty and _upload_cooldown <= 0.0:
		_texture.update(_image)
		_dirty = false
		_upload_cooldown = UPLOAD_INTERVAL


## Difuminado diario de las sendas no usadas (docs/S3_DESIGN.md). Sobre el
## array de floats crudo, no píxel a píxel: un solo barrido barato, sin tirón.
func _on_day_changed(_day: int) -> void:
	if not _active:
		return
	var floats: PackedFloat32Array = _image.get_data().to_float32_array()
	for i: int in floats.size():
		floats[i] *= DAILY_DECAY
	_image.set_data(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF, floats.to_byte_array())
	_dirty = true


func reset() -> void:
	if _image != null:
		_image.fill(Color(0.0, 0.0, 0.0, 1.0))
		if _texture != null:
			_texture.update(_image)
	_active = false
