class_name CottageGen
## Cabaña procedural por piezas (§10). Variación por semilla: ventana (3
## opciones), inclinación del tejado (±6°), banco opcional (50 %), color
## secundario de madera. La puerta está siempre en +X local; la orientación
## de la casa la decide el emplazamiento (4 opciones).

const WALL_H: float = 2.6

# Se fijan por build() según la receta (A: 5×4, B: 6×3.6)
static var _hx: float = 2.5
static var _hz: float = 2.0


## Devuelve {"root", "foundation", "frame", "walls", "roof", "window_light"}.
## style: &"cottage_a" clásica · &"cottage_b" casa larga con chimenea.
static func build(
	seed_value: int, half_x: float = 2.5, half_z: float = 2.0, style: StringName = &"cottage_a"
) -> Dictionary:
	_hx = half_x
	_hz = half_z
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()
	var wood: Color = palette.wood if rng.randf() < 0.5 else palette.wood_light
	var wood_alt: Color = palette.wood_light if wood == palette.wood else palette.wood
	var roof_tilt: float = deg_to_rad(
		(30.0 if style == &"cottage_b" else 38.0) + rng.randf_range(-6.0, 6.0)
	)
	var window_wall: int = rng.randi_range(0, 2)
	var has_bench: bool = rng.randf() < 0.5

	var root: Node3D = Node3D.new()
	root.name = "Cottage"
	var result: Dictionary = {"root": root, "foundation": [], "frame": [], "walls": [], "roof": []}

	# --- Cimientos: 4 piedras de esquina + 4 vigas base ---
	for corner: Vector2 in [
		Vector2(-_hx, -_hz),
		Vector2(_hx, -_hz),
		Vector2(_hx, _hz),
		Vector2(-_hx, _hz),
	]:
		var stone: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.5, 0.4, 0.5), 0.05), palette.stone, "CornerStone"
		)
		stone.position = Vector3(corner.x, 0.2, corner.y)
		_add_piece(root, result, "foundation", stone)
	for beam_z: float in [-_hz, _hz]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(_hx * 2.0 - 0.3, 0.24, 0.3)), wood, "BaseBeamX"
		)
		beam.position = Vector3(0.0, 0.42, beam_z)
		_add_piece(root, result, "foundation", beam)
	for beam_x: float in [-_hx, _hx]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.3, 0.24, _hz * 2.0 - 0.3)), wood, "BaseBeamZ"
		)
		beam.position = Vector3(beam_x, 0.42, 0.0)
		_add_piece(root, result, "foundation", beam)

	# --- Estructura: 4 postes + 4 vigas superiores + 2 pies del caballete ---
	for corner: Vector2 in [
		Vector2(-_hx, -_hz),
		Vector2(_hx, -_hz),
		Vector2(_hx, _hz),
		Vector2(-_hx, _hz),
	]:
		var post: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.24, WALL_H - 0.55, 0.24), 0.035), wood_alt, "Post"
		)
		post.position = Vector3(corner.x, 0.55 + (WALL_H - 0.55) * 0.5, corner.y)
		_add_piece(root, result, "frame", post)
	for beam_z: float in [-_hz, _hz]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(_hx * 2.0 + 0.2, 0.2, 0.24)), wood, "TopBeamX"
		)
		beam.position = Vector3(0.0, WALL_H + 0.1, beam_z)
		_add_piece(root, result, "frame", beam)
	for beam_x: float in [-_hx, _hx]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.24, 0.2, _hz * 2.0 + 0.2)), wood, "TopBeamZ"
		)
		beam.position = Vector3(beam_x, WALL_H + 0.1, 0.0)
		_add_piece(root, result, "frame", beam)
	var ridge_h: float = WALL_H + tan(roof_tilt) * _hz
	for gable_x: float in [-_hx, _hx]:
		var pole: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.2, ridge_h - WALL_H, 0.2), 0.03), wood_alt, "GablePole"
		)
		pole.position = Vector3(gable_x, WALL_H + (ridge_h - WALL_H) * 0.5, 0.0)
		_add_piece(root, result, "frame", pole)

	# --- Paredes: tablones uno a uno (la puerta queda en +X) ---
	var plank_rows: int = 4
	var row_h: float = (WALL_H - 0.55) / float(plank_rows)
	for row: int in plank_rows:
		var y: float = 0.55 + row_h * (float(row) + 0.5)
		for wall_z: float in [-_hz, _hz]:
			var plank: MeshInstance3D = MeshLib.mesh_instance(
				MeshLib.plank(Vector3(_hx * 2.0 - 0.3, row_h - 0.04, 0.14)), wood, "WallX"
			)
			plank.position = Vector3(0.0, y, wall_z)
			_add_piece(root, result, "walls", plank)
		var back: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.14, row_h - 0.04, _hz * 2.0 - 0.3)), wood, "WallBack"
		)
		back.position = Vector3(-_hx, y, 0.0)
		_add_piece(root, result, "walls", back)
	# Pared frontal: dos franjas flanqueando la puerta
	for door_side: float in [-1.0, 1.0]:
		var strip: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.14, WALL_H - 0.55, _hz - 0.65)), wood, "WallFront"
		)
		strip.position = Vector3(_hx, 0.55 + (WALL_H - 0.55) * 0.5, door_side * (_hz * 0.5 + 0.32))
		_add_piece(root, result, "walls", strip)

	# --- Tejado y acabado ---
	var ridge: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.plank(Vector3(_hx * 2.0 + 0.5, 0.18, 0.18)), wood_alt, "Ridge"
	)
	ridge.position = Vector3(0.0, ridge_h, 0.0)
	_add_piece(root, result, "roof", ridge)
	var panel_len: float = sqrt(pow(_hz + 0.35, 2.0) + pow(ridge_h - WALL_H, 2.0)) + 0.2
	for roof_side: float in [-1.0, 1.0]:
		var panel: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(_hx * 2.0 + 0.6, 0.12, panel_len)), palette.roof, "RoofPanel"
		)
		panel.rotation.x = roof_side * roof_tilt
		var mid_z: float = roof_side * (_hz + 0.35) * 0.5
		var mid_y: float = (ridge_h + WALL_H) * 0.5 + 0.1
		panel.position = Vector3(0.0, mid_y, mid_z)
		_add_piece(root, result, "roof", panel)
	var door: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.plank(Vector3(0.1, 1.8, 0.95)), wood_alt, "Door"
	)
	door.position = Vector3(_hx + 0.02, 0.55 + 0.9, 0.0)
	_add_piece(root, result, "roof", door)
	var window_positions: Array[Vector3] = [
		Vector3(0.0, 1.55, -_hz - 0.02),
		Vector3(0.0, 1.55, _hz + 0.02),
		Vector3(-_hx - 0.02, 1.55, 0.0),
	]
	var window: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.plank(Vector3(0.7, 0.7, 0.12) if window_wall == 2 else Vector3(0.7, 0.7, 0.12)),
		palette.cart_cloth,
		"Window"
	)
	if window_wall == 2:
		window.rotation.y = PI * 0.5
	window.position = window_positions[window_wall]
	_add_piece(root, result, "roof", window)
	var window_light: OmniLight3D = OmniLight3D.new()
	window_light.name = "WindowLight"
	window_light.light_color = palette.warm_light
	window_light.omni_range = 5.0
	window_light.light_energy = 0.0
	window_light.position = window_positions[window_wall] + Vector3(0.0, 0.2, 0.0)
	root.add_child(window_light)
	result["window_light"] = window_light
	if style == &"cottage_b":
		# Casa larga: chimenea de piedra trasera + segunda ventana frontal
		var chimney: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.55, ridge_h + 0.7, 0.55), 0.05), palette.stone, "Chimney"
		)
		chimney.position = Vector3(-_hx + 0.5, (ridge_h + 0.7) * 0.5, -_hz + 0.45)
		_add_piece(root, result, "roof", chimney)
		var window2: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.7, 0.7, 0.12)), palette.cart_cloth, "Window2"
		)
		window2.position = Vector3(_hx * 0.4, 1.55, _hz + 0.02)
		_add_piece(root, result, "roof", window2)
	if has_bench:
		var bench: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.4, 0.45, 1.2)), wood, "Bench"
		)
		bench.position = Vector3(_hx + 0.65, 0.22, _hz * 0.62)
		_add_piece(root, result, "roof", bench)
	return result


static func _add_piece(
	root: Node3D, result: Dictionary, group: String, piece: MeshInstance3D
) -> void:
	piece.visible = false
	root.add_child(piece)
	(result[group] as Array).append(piece)
