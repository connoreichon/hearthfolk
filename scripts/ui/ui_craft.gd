class_name UiCraft
## Identidad propia de la UI (Build 004): paneles de MADERA TALLADA con
## remaches de bronce y filo de brasa, generados en CPU — sin depender de
## assets externos. Un solo estilo para todo el juego: HUD, siembra, menús.

const TILE: int = 96
const MARGIN: int = 26

static var _panel_box: StyleBoxTexture
static var _panel_warm_box: StyleBoxTexture
static var _button_boxes: Dictionary = {}


## Panel estándar: tablilla de madera oscura, bisel y remaches.
static func panel() -> StyleBoxTexture:
	if _panel_box == null:
		_panel_box = _make_box(_paint_panel(false))
	return _panel_box


## Panel cálido (títulos, momentos): igual pero con el filo de brasa vivo.
static func panel_warm() -> StyleBoxTexture:
	if _panel_warm_box == null:
		_panel_warm_box = _make_box(_paint_panel(true))
	return _panel_warm_box


## Botón por estado: &"normal", &"hover", &"pressed", &"disabled".
static func button(state: StringName) -> StyleBoxTexture:
	if not _button_boxes.has(state):
		_button_boxes[state] = _make_box(_paint_button(state), 10)
	return _button_boxes[state]


## Aplica los cuatro estados a un Button (atajo para toda la UI).
static func style_button(target: Button) -> void:
	target.add_theme_stylebox_override(&"normal", button(&"normal"))
	target.add_theme_stylebox_override(&"hover", button(&"hover"))
	target.add_theme_stylebox_override(&"pressed", button(&"pressed"))
	target.add_theme_stylebox_override(&"disabled", button(&"disabled"))
	target.add_theme_color_override(&"font_color", Color("#F3EEE4"))
	target.add_theme_color_override(&"font_hover_color", Color("#FFD38A"))
	target.add_theme_color_override(&"font_pressed_color", Color("#E8C9A0"))
	target.add_theme_color_override(&"font_disabled_color", Color("#8A8378"))


## El janitor de los tests limpia estos caches estáticos.
static func release_caches() -> void:
	_panel_box = null
	_panel_warm_box = null
	_button_boxes.clear()


static func _make_box(img: Image, content_margin: float = 14.0) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(img)
	box.texture_margin_left = MARGIN
	box.texture_margin_right = MARGIN
	box.texture_margin_top = MARGIN
	box.texture_margin_bottom = MARGIN
	box.content_margin_left = content_margin + 4.0
	box.content_margin_right = content_margin + 4.0
	box.content_margin_top = content_margin - 2.0
	box.content_margin_bottom = content_margin - 2.0
	return box


## Madera pintada a mano en código: vetas onduladas, bisel tallado, marco
## casi negro, remaches de bronce y (opcional) filo interior de brasa.
static func _paint_panel(warm: bool) -> Image:
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var dark: Color = Color("#2A2119")
	var wood: Color = Color("#3B2F23")
	var wood_light: Color = Color("#4A3B2B")
	var ember: Color = Color("#E8703A")
	var bronze: Color = Color("#8A6B3D")
	for y: int in TILE:
		for x: int in TILE:
			var fx: float = float(x)
			var fy: float = float(y)
			var edge: float = minf(minf(fx, fy), minf(float(TILE - 1) - fx, float(TILE - 1) - fy))
			var color: Color
			if edge < 2.0:
				# Marco exterior: casi negro, canto duro
				color = Color("#16100B")
			elif edge < 4.0:
				# Filo: de brasa (cálido) o bronce apagado (estándar)
				color = ember.darkened(0.15) if warm else bronze.darkened(0.35)
				color.a = 0.98
			elif edge < 6.0:
				# Bisel interior oscuro: la tabla se hunde tras el marco
				color = dark
			else:
				# Cuerpo de madera con vetas onduladas (deterministas)
				var wave: float = (
					sin(fy * 0.55 + sin(fx * 0.11) * 2.1) + sin(fy * 0.23 + fx * 0.035 + 1.7) * 0.5
				)
				var grain: float = 0.5 + wave * 0.24
				color = wood.lerp(wood_light, clampf(grain, 0.0, 1.0))
				# Poro fino: microvariación por hash de píxel
				var h: float = fposmod(sin(fx * 12.9898 + fy * 78.233) * 43758.5453, 1.0)
				color = color.darkened(h * 0.06)
				color.a = 0.96
			img.set_pixel(x, y, color)
	# Remaches de bronce en las cuatro esquinas (dentro del margen 9-patch)
	for corner: Vector2i in [
		Vector2i(11, 11),
		Vector2i(TILE - 12, 11),
		Vector2i(11, TILE - 12),
		Vector2i(TILE - 12, TILE - 12)
	]:
		_paint_rivet(img, corner, bronze)
	return img


static func _paint_rivet(img: Image, at: Vector2i, bronze: Color) -> void:
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var d: float = Vector2(dx, dy).length()
			if d > 3.2:
				continue
			var px: int = at.x + dx
			var py: int = at.y + dy
			if px < 0 or py < 0 or px >= TILE or py >= TILE:
				continue
			var shine: float = clampf(1.0 - (Vector2(dx + 1, dy + 1).length() / 3.0), 0.0, 1.0)
			var color: Color = bronze.darkened(0.35).lerp(bronze.lightened(0.35), shine)
			if d > 2.5:
				color = Color("#16100B")
			img.set_pixel(px, py, color)


static func _paint_button(state: StringName) -> Image:
	var img: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var wood: Color = Color("#4A3B2B")
	var wood_hi: Color = Color("#5C4934")
	match state:
		&"hover":
			wood = Color("#54432F")
			wood_hi = Color("#6A5539")
		&"pressed":
			wood = Color("#332818")
			wood_hi = Color("#3E3220")
		&"disabled":
			wood = Color("#332E27")
			wood_hi = Color("#3B362E")
	var border: Color = Color("#E8703A") if state == &"hover" else Color("#16100B")
	for y: int in TILE:
		for x: int in TILE:
			var fx: float = float(x)
			var fy: float = float(y)
			var edge: float = minf(minf(fx, fy), minf(float(TILE - 1) - fx, float(TILE - 1) - fy))
			var color: Color
			if edge < 2.0:
				color = border
			elif edge < 4.0:
				# Bisel: luz arriba-izquierda, sombra abajo-derecha (relieve)
				var lit: bool = fx < float(TILE) * 0.5 or fy < float(TILE) * 0.5
				if state == &"pressed":
					lit = not lit
				color = wood_hi.lightened(0.18) if lit else Color("#241C12")
			else:
				var wave: float = sin(fy * 0.62 + sin(fx * 0.13) * 1.8)
				color = wood.lerp(wood_hi, 0.5 + wave * 0.22)
				var h: float = fposmod(sin(fx * 12.9898 + fy * 78.233) * 43758.5453, 1.0)
				color = color.darkened(h * 0.05)
			img.set_pixel(x, y, color)
	return img
