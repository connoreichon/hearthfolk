class_name BandPlacer
extends Node
## Siembra de bandas (S0, Build 003 · rediseño Build 004): al empezar
## partida, el jugador reparte a sus colonos SOBRE UN MAPA 2D del valle
## (pintado en CPU desde WorldGen — siempre legible, da igual GPU o
## sombras). Clic en tierra firme = fundar una banda. Validación mínima —
## dentro del mapa, sin agua, pendiente razonable, lejos de otros
## campamentos — y CERO chequeos de acceso: cada banda se las apaña donde
## su gente decida plantar la hoguera.

const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")
const MIN_CAMP_DISTANCE: float = 12.0
const MAX_SLOPE_DEG: float = 22.0

const BIOME_NAMES: Dictionary = {
	WorldGen.Biome.PRADERA: "Pradera",
	WorldGen.Biome.BOSQUE: "Bosque Umbrío",
	WorldGen.Biome.RIBERA: "Ribera de Juncos",
	WorldGen.Biome.COLINAS: "Colinas de Piedra",
	WorldGen.Biome.CLARO: "Claro Florido",
}

var remaining: int = 10
var group_size: int = 4

var _band_counter: int = 0
var _world: WorldRoot
var _tools: ToolManager
var _hud: CanvasLayer
var _rig: CameraRig
var _map_view: MapView
var _group_label: Label
var _remaining_label: Label
var _cursor_label: Label
var _last_camp_pos: Vector3 = Vector3.ZERO


func setup(world: WorldRoot, tools: ToolManager, hud: CanvasLayer) -> void:
	_world = world
	_tools = tools
	_hud = hud


func _ready() -> void:
	remaining = maxi(1, GameState.pending_settlers)
	group_size = clampi(4, 1, remaining)
	var rigs: Array[Node] = get_tree().get_nodes_in_group(&"camera_rig")
	if not rigs.is_empty():
		_rig = rigs[0] as CameraRig
		# VISTA DE ÁGUILA de fondo: ambiente del valle real tras el mapa.
		_rig.set_overview(true)
	# Mientras se siembra, las herramientas y el HUD esperan su turno.
	if _tools != null:
		_tools.set_process_input(false)
		_tools.set_process_unhandled_input(false)
	if _hud != null:
		_hud.visible = false
	_build_ui()
	_refresh_labels()


func _build_ui() -> void:
	var palette: PaletteData = PaletteData.get_default()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 55
	add_child(layer)

	# ---- EL MAPA DEL VALLE (el corazón de la siembra) ----
	var vp_size: Vector2 = _world.get_viewport().get_visible_rect().size
	var map_side: float = minf(vp_size.y * 0.64, vp_size.x * 0.52)
	var map_panel: PanelContainer = PanelContainer.new()
	var map_style: StyleBoxFlat = StyleBoxFlat.new()
	map_style.bg_color = Color(palette.ui_panel, 0.94)
	map_style.border_color = palette.accent
	map_style.set_border_width_all(2)
	map_style.set_corner_radius_all(12)
	map_style.content_margin_left = 12.0
	map_style.content_margin_right = 12.0
	map_style.content_margin_top = 8.0
	map_style.content_margin_bottom = 12.0
	map_panel.add_theme_stylebox_override(&"panel", map_style)
	map_panel.anchor_left = 0.5
	map_panel.anchor_right = 0.5
	map_panel.anchor_top = 0.0
	map_panel.anchor_bottom = 0.0
	map_panel.offset_top = vp_size.y * 0.045
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	map_panel.grow_vertical = Control.GROW_DIRECTION_END
	layer.add_child(map_panel)
	var map_box: VBoxContainer = VBoxContainer.new()
	map_box.add_theme_constant_override(&"separation", 6)
	map_panel.add_child(map_box)
	var map_title: Label = Label.new()
	map_title.text = "El valle — mapa %d" % GameState.world_seed
	map_title.add_theme_color_override(&"font_color", Color(palette.ui_text, 0.85))
	map_title.add_theme_font_size_override(&"font_size", 15)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_box.add_child(map_title)
	# En headless (tests/soaks) nadie mira el mapa: pintarlo mini y seguir.
	var map_px: int = 64 if DisplayServer.get_name() == "headless" else 512
	var image: Image = MapPainter.paint(GameState.world_gen, map_px)
	_map_view = MapView.new(self, ImageTexture.create_from_image(image))
	_map_view.custom_minimum_size = Vector2(map_side, map_side)
	map_box.add_child(_map_view)

	# ---- Panel inferior: grupo, restantes e instrucciones ----
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette.ui_panel, 0.94)
	style.border_color = palette.accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -158.0
	panel.offset_bottom = -18.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Reparte a tu gente por el valle"
	title.add_theme_color_override(&"font_color", palette.accent)
	title.add_theme_font_size_override(&"font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint: Label = Label.new()
	hint.text = (
		"Clic en el mapa: asentar un grupo · Mayús+clic: todos juntos\n"
		+ "La distancia entre aldeas escribirá su historia: vecinas… o mundos aparte"
	)
	hint.add_theme_color_override(&"font_color", Color(palette.ui_text, 0.8))
	hint.add_theme_font_size_override(&"font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override(&"separation", 14)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(controls)
	var minus: Button = Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(44.0, 36.0)
	minus.focus_mode = Control.FOCUS_NONE
	minus.pressed.connect(_change_group.bind(-1))
	controls.add_child(minus)
	_group_label = Label.new()
	_group_label.add_theme_color_override(&"font_color", palette.ui_text)
	_group_label.add_theme_font_size_override(&"font_size", 18)
	controls.add_child(_group_label)
	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(44.0, 36.0)
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(_change_group.bind(1))
	controls.add_child(plus)
	_remaining_label = Label.new()
	_remaining_label.add_theme_color_override(&"font_color", palette.accent)
	_remaining_label.add_theme_font_size_override(&"font_size", 18)
	controls.add_child(_remaining_label)
	# Etiqueta que sigue al cursor: bioma y validez del punto. Contorno
	# oscuro: sin él, el verde sobre la pradera del mapa era invisible.
	_cursor_label = Label.new()
	_cursor_label.add_theme_font_size_override(&"font_size", 14)
	_cursor_label.add_theme_constant_override(&"outline_size", 5)
	_cursor_label.add_theme_color_override(&"font_outline_color", palette.ui_panel)
	_cursor_label.visible = false
	layer.add_child(_cursor_label)


func _change_group(delta: int) -> void:
	group_size = clampi(group_size + delta, 1, remaining)
	_refresh_labels()
	if _map_view != null:
		_map_view.queue_redraw()


func _refresh_labels() -> void:
	var dots: String = ""
	for _i: int in group_size:
		dots += "●"
	_group_label.text = "Grupo: %s" % dots
	_remaining_label.text = "Por asentar: %d" % remaining


## Píxel del mapa → punto del mundo (el mapa cubre map_half×2 centrado en 0).
func map_to_world(px: Vector2, view_size: Vector2) -> Vector3:
	var half: float = GameState.world_gen.map_half
	var wx: float = (px.x / view_size.x * 2.0 - 1.0) * half
	var wz: float = (px.y / view_size.y * 2.0 - 1.0) * half
	return Vector3(wx, GameState.world_gen.height(wx, wz), wz)


## El ratón pasea por el mapa: anillo de puntería + etiqueta de bioma.
func on_map_hover(px: Vector2) -> void:
	var point: Vector3 = map_to_world(px, _map_view.size)
	var reason: String = _validity_reason(point)
	var valid: bool = reason.is_empty()
	_map_view.cursor_px = px
	_map_view.cursor_valid = valid
	_map_view.queue_redraw()
	var palette: PaletteData = PaletteData.get_default()
	var biome_name: String = String(
		BIOME_NAMES.get(GameState.world_gen.biome(point.x, point.z), "")
	)
	_cursor_label.text = (
		"%s — clic para asentar" % biome_name if valid else "%s — %s" % [biome_name, reason]
	)
	_cursor_label.add_theme_color_override(
		&"font_color", palette.grass_light if valid else palette.roof
	)
	# Junto al cursor, sin salirse por el borde derecho de la ventana
	var pos: Vector2 = _map_view.get_global_mouse_position() + Vector2(18.0, 14.0)
	var vp: Vector2 = _world.get_viewport().get_visible_rect().size
	pos.x = minf(pos.x, vp.x - _cursor_label.get_minimum_size().x - 8.0)
	_cursor_label.position = pos
	_cursor_label.visible = true


## Clic en el mapa: si el punto vale, ahí nace una banda.
func on_map_click(px: Vector2, everyone: bool) -> void:
	# Guard de re-entrada: con input acumulado, un segundo clic del mismo
	# flush llegaría tras _finish() (queue_free es diferido) y sembraría
	# colonos de más sobre pending_settlers.
	if remaining <= 0:
		return
	var point: Vector3 = map_to_world(px, _map_view.size)
	if not _is_valid(point):
		AudioDirector.play_ui(&"ui_error")
		return
	var count: int = remaining if everyone else group_size
	_map_view.markers.append(px)
	AudioDirector.play_ui(&"ui_confirm")
	drop_band(point, count)
	if remaining > 0 and is_instance_valid(_map_view):
		# El punto recién fundado ya no vale (a <12 m de sí mismo): refrescar
		# anillo y etiqueta sin esperar a que el ratón se mueva.
		on_map_hover(px)


func _is_valid(point: Vector3) -> bool:
	return _validity_reason(point).is_empty()


## Vacío = válido; si no, el motivo en palabras del juego (para el cursor).
## El campamento necesita un CLARO seco: se valida el centro y un anillo
## de 3,5 m (la hoguera, el montón y los petates tienen que caber).
func _validity_reason(point: Vector3) -> String:
	var terrain: TerrainData = GameState.terrain
	if terrain == null or not terrain.is_inside(point.x, point.z, 3.0):
		return "fuera del valle"
	if not CampEntity.clearing_is_dry(GameState.world_gen, point.x, point.z):
		return "demasiado cerca del agua"
	for i: int in 5:
		var probe: Vector3 = point
		if i > 0:
			var ang: float = TAU * float(i - 1) / 4.0
			probe = point + Vector3(cos(ang) * 3.5, 0.0, sin(ang) * 3.5)
		if terrain.get_slope_deg(probe.x, probe.z) > MAX_SLOPE_DEG:
			return "cuesta demasiado empinada"
	for node: Node in get_tree().get_nodes_in_group(&"camps"):
		var d: float = (node as Node3D).global_position.distance_to(point)
		if d < MIN_CAMP_DISTANCE:
			return "demasiado cerca de otra aldea"
	return ""


## Suelta una banda de `count` colonos alrededor de un punto válido.
func drop_band(point: Vector3, count: int) -> void:
	_band_counter += 1
	var camp: CampEntity = _world.found_camp(point, _band_counter)
	EventBus.band_placed.emit(_band_counter, camp.global_position)
	var terrain: TerrainData = GameState.terrain
	for i: int in count:
		var citizen: Citizen = CITIZEN_SCENE.instantiate()
		citizen.data = SettlerGen.generate(GameState.rng)
		citizen.band_id = _band_counter
		_world.add_child(citizen)
		var ang: float = TAU * float(i) / float(count) + 0.6
		var radius: float = 2.6 + 0.5 * float(i % 2)
		var pos: Vector3 = point + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		pos.y = terrain.get_height(pos.x, pos.z) + 0.05
		citizen.global_position = pos
		citizen.visual.rotation.y = ang + PI * 0.5
	_last_camp_pos = camp.global_position
	remaining -= count
	if remaining <= 0:
		_finish()
	else:
		group_size = clampi(group_size, 1, remaining)
		_refresh_labels()


## Reparto automático 4+4+2 para tests y repros (--autoplace / --newgame):
## tres rincones separados del mapa gigante, con búsqueda en espiral.
func autoplace_default() -> void:
	var anchors: Array[Vector3] = [
		Vector3(0.0, 0.0, 6.0), Vector3(-230.0, 0.0, -170.0), Vector3(210.0, 0.0, 190.0)
	]
	var splits: Array[int] = [4, 4, 2]
	for i: int in anchors.size():
		if remaining <= 0:
			break
		var target: Vector3 = _find_valid_near(anchors[i])
		if target == Vector3.INF:
			continue
		drop_band(target, mini(splits[i], remaining))
	# Si quedó gente sin sitio (mapa hostil), al centro con los primeros.
	while remaining > 0:
		var fallback: Vector3 = _find_valid_near(Vector3(6.0, 0.0, -6.0))
		if fallback == Vector3.INF:
			push_error("BandPlacer: sin punto válido para el resto de colonos")
			_finish()
			return
		drop_band(fallback, remaining)


func _find_valid_near(anchor: Vector3, ring_step: float = 3.0, rings: int = 8) -> Vector3:
	var terrain: TerrainData = GameState.terrain
	for ring: int in rings:
		for step: int in 8:
			var ang: float = TAU * float(step) / 8.0
			var candidate: Vector3 = (
				anchor
				+ Vector3(
					cos(ang) * float(ring) * ring_step, 0.0, sin(ang) * float(ring) * ring_step
				)
			)
			candidate.y = terrain.get_height(candidate.x, candidate.z)
			if _is_valid(candidate):
				return candidate
	return Vector3.INF


func _finish() -> void:
	GameState.placement_pending = false
	_world._bake_navmesh()
	# La partida arranca DE MAÑANA: la siembra se congela a mediodía por
	# legibilidad, pero el primer día del pueblo se juega entero.
	SimClock.reset(1, 0.25)
	SimClock.set_speed(SimClock.Speed.NORMAL)
	if _tools != null:
		_tools.set_process_input(true)
		_tools.set_process_unhandled_input(true)
	if _hud != null:
		_hud.visible = true
	# Remate: la cámara aparece YA plantada sobre la última aldea fundada,
	# a zoom de juego — nada de tweens desde el águila que acaban en el agua.
	if _rig != null:
		_rig.snap_to(_last_camp_pos)
	EventBus.placement_finished.emit()
	EventBus.toast.emit("Tu gente está en camino: enciende sus historias", &"success")
	queue_free()


## Vista del mapa: textura del valle + marcadores de bandas + puntería.
class MapView:
	extends Control

	var placer: BandPlacer
	var map_texture: Texture2D
	var cursor_px: Vector2 = Vector2(-1000.0, -1000.0)
	var cursor_valid: bool = false
	## Píxeles del mapa donde ya arde una hoguera (una por banda soltada).
	var markers: Array[Vector2] = []

	func _init(owner_placer: BandPlacer, texture: Texture2D) -> void:
		placer = owner_placer
		map_texture = texture
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		draw_texture_rect(map_texture, Rect2(Vector2.ZERO, size), false)
		for marker: Vector2 in markers:
			# Hoguera recién prendida: brasa sagrada sobre el pergamino
			draw_circle(marker, 7.0, Color("#2A2119"))
			draw_circle(marker, 5.0, Color("#E8703A"))
			draw_circle(marker + Vector2(0.0, -1.2), 2.0, Color("#FFD38A"))
		if cursor_px.x > -100.0:
			var palette: PaletteData = PaletteData.get_default()
			var color: Color = palette.grass_light if cursor_valid else palette.roof
			var radius: float = 7.0 + 1.6 * float(placer.group_size)
			draw_arc(cursor_px, radius, 0.0, TAU, 40, color, 2.5, true)
			draw_circle(cursor_px, 2.2, color)

	func _gui_input(event: InputEvent) -> void:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion != null:
			placer.on_map_hover(motion.position)
			return
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			placer.on_map_click(click.position, click.shift_pressed)
			accept_event()

	func _mouse_exit_reset() -> void:
		cursor_px = Vector2(-1000.0, -1000.0)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_mouse_exit_reset()
			if is_instance_valid(placer) and placer._cursor_label != null:
				placer._cursor_label.visible = false
