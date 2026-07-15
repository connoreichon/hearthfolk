class_name CottageGen
## Casa procedural por piezas (§10) con NIVELES (S7): choza humilde de bálago
## → cabaña de madera → casa de piedra. Variación por semilla dentro de cada
## nivel (ventana, tejado, banco, color). La puerta está siempre en +X local;
## la orientación la decide el emplazamiento. Las piezas nacen ocultas y la
## obra las revela por fases (cimientos/estructura/paredes/tejado).

const WALL_H: float = 2.6


## Devuelve {"root", "foundation", "frame", "walls", "roof", "window_light"}.
## style: choza · cottage_a/cottage_b (cabaña) · casa_piedra.
static func build(
	seed_value: int, half_x: float = 2.5, half_z: float = 2.0, style: StringName = &"cottage_a"
) -> Dictionary:
	var hx: float = half_x
	var hz: float = half_z
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: PaletteData = PaletteData.get_default()

	# --- Perfil del NIVEL (S7) ---
	var is_choza: bool = style == &"choza"
	var is_stone: bool = style == &"casa_piedra"
	var is_long: bool = style == &"cottage_b"
	var wall_h: float = 1.85 if is_choza else (2.95 if is_stone else WALL_H)
	var wood: Color = palette.wood if rng.randf() < 0.5 else palette.wood_light
	var wood_alt: Color = palette.wood_light if wood == palette.wood else palette.wood
	var wall_color: Color = palette.stone if is_stone else wood
	var corner_color: Color = wood_alt if is_choza else palette.stone
	var roof_color: Color = Color("#93702F").lerp(palette.dirt, 0.2) if is_choza else palette.roof
	var base_deg: float = 47.0 if is_choza else (33.0 if is_stone else (30.0 if is_long else 38.0))
	var roof_tilt: float = deg_to_rad(base_deg + rng.randf_range(-5.0, 5.0))
	var plank_rows: int = 3 if is_choza else (5 if is_stone else 4)
	var has_chimney: bool = is_stone or is_long
	# Orden de RNG idéntico al original (window antes que banco) para no
	# alterar el aspecto de las cabañas ya existentes.
	var window_wall: int = rng.randi_range(0, 2)
	var has_bench: bool = not is_choza and rng.randf() < 0.5

	var root: Node3D = Node3D.new()
	root.name = "Cottage"
	var result: Dictionary = {"root": root, "foundation": [], "frame": [], "walls": [], "roof": []}

	# --- Cimientos: 4 esquinas + 4 vigas base ---
	var corner_size: Vector3 = Vector3(0.22, 0.55, 0.22) if is_choza else Vector3(0.5, 0.4, 0.5)
	for corner: Vector2 in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		var stone: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(corner_size, 0.05), corner_color, "CornerStone"
		)
		stone.position = Vector3(corner.x, corner_size.y * 0.5, corner.y)
		_add_piece(root, result, "foundation", stone)
	for beam_z: float in [-hz, hz]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(hx * 2.0 - 0.3, 0.24, 0.3)), wood, "BaseBeamX"
		)
		beam.position = Vector3(0.0, 0.42, beam_z)
		_add_piece(root, result, "foundation", beam)
	for beam_x: float in [-hx, hx]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.3, 0.24, hz * 2.0 - 0.3)), wood, "BaseBeamZ"
		)
		beam.position = Vector3(beam_x, 0.42, 0.0)
		_add_piece(root, result, "foundation", beam)

	# --- Estructura: 4 postes + 4 vigas superiores + 2 pies del caballete ---
	for corner: Vector2 in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		var post: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.24, wall_h - 0.55, 0.24), 0.035), wood_alt, "Post"
		)
		post.position = Vector3(corner.x, 0.55 + (wall_h - 0.55) * 0.5, corner.y)
		_add_piece(root, result, "frame", post)
	for beam_z: float in [-hz, hz]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(hx * 2.0 + 0.2, 0.2, 0.24)), wood, "TopBeamX"
		)
		beam.position = Vector3(0.0, wall_h + 0.1, beam_z)
		_add_piece(root, result, "frame", beam)
	for beam_x: float in [-hx, hx]:
		var beam: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.24, 0.2, hz * 2.0 + 0.2)), wood, "TopBeamZ"
		)
		beam.position = Vector3(beam_x, wall_h + 0.1, 0.0)
		_add_piece(root, result, "frame", beam)
	var ridge_h: float = wall_h + tan(roof_tilt) * hz
	for gable_x: float in [-hx, hx]:
		var pole: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.2, ridge_h - wall_h, 0.2), 0.03), wood_alt, "GablePole"
		)
		pole.position = Vector3(gable_x, wall_h + (ridge_h - wall_h) * 0.5, 0.0)
		_add_piece(root, result, "frame", pole)

	# --- Paredes: tablones uno a uno (la puerta queda en +X) ---
	var row_h: float = (wall_h - 0.55) / float(plank_rows)
	var wall_thick: float = 0.18 if is_stone else 0.14
	for row: int in plank_rows:
		var y: float = 0.55 + row_h * (float(row) + 0.5)
		for wall_z: float in [-hz, hz]:
			var plank: MeshInstance3D = MeshLib.mesh_instance(
				MeshLib.plank(Vector3(hx * 2.0 - 0.3, row_h - 0.04, wall_thick)),
				wall_color,
				"WallX"
			)
			plank.position = Vector3(0.0, y, wall_z)
			_add_piece(root, result, "walls", plank)
		var back: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(wall_thick, row_h - 0.04, hz * 2.0 - 0.3)), wall_color, "WallBack"
		)
		back.position = Vector3(-hx, y, 0.0)
		_add_piece(root, result, "walls", back)
	# Pared frontal: dos franjas flanqueando la puerta
	for door_side: float in [-1.0, 1.0]:
		var strip: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(wall_thick, wall_h - 0.55, hz - 0.65)), wall_color, "WallFront"
		)
		strip.position = Vector3(hx, 0.55 + (wall_h - 0.55) * 0.5, door_side * (hz * 0.5 + 0.32))
		_add_piece(root, result, "walls", strip)

	# --- Tejado y acabado ---
	var ridge: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.plank(Vector3(hx * 2.0 + 0.5, 0.18, 0.18)), wood_alt, "Ridge"
	)
	ridge.position = Vector3(0.0, ridge_h, 0.0)
	_add_piece(root, result, "roof", ridge)
	var panel_len: float = sqrt(pow(hz + 0.35, 2.0) + pow(ridge_h - wall_h, 2.0)) + 0.2
	for roof_side: float in [-1.0, 1.0]:
		var panel: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(hx * 2.0 + 0.6, 0.12, panel_len)), roof_color, "RoofPanel"
		)
		panel.rotation.x = roof_side * roof_tilt
		var mid_z: float = roof_side * (hz + 0.35) * 0.5
		var mid_y: float = (ridge_h + wall_h) * 0.5 + 0.1
		panel.position = Vector3(0.0, mid_y, mid_z)
		_add_piece(root, result, "roof", panel)
	var door: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.plank(Vector3(0.1, 1.8, 0.95)), wood_alt, "Door"
	)
	door.position = Vector3(hx + 0.02, 0.55 + 0.9, 0.0)
	_add_piece(root, result, "roof", door)
	var window_positions: Array[Vector3] = [
		Vector3(0.0, 1.55, -hz - 0.02),
		Vector3(0.0, 1.55, hz + 0.02),
		Vector3(-hx - 0.02, 1.55, 0.0)
	]
	# La choza baja su ventana (paredes cortas)
	if is_choza:
		for i: int in window_positions.size():
			window_positions[i].y = 1.15
	var window: MeshInstance3D = MeshLib.mesh_instance(
		MeshLib.plank(Vector3(0.7, 0.7, 0.12)), palette.cart_cloth, "Window"
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
	if has_chimney:
		var chimney: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.beveled_box(Vector3(0.55, ridge_h + 0.7, 0.55), 0.05), palette.stone, "Chimney"
		)
		chimney.position = Vector3(-hx + 0.5, (ridge_h + 0.7) * 0.5, -hz + 0.45)
		_add_piece(root, result, "roof", chimney)
		var window2: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.7, 0.7, 0.12)), palette.cart_cloth, "Window2"
		)
		window2.position = Vector3(hx * 0.4, 1.55, hz + 0.02)
		_add_piece(root, result, "roof", window2)
	if has_bench:
		var bench: MeshInstance3D = MeshLib.mesh_instance(
			MeshLib.plank(Vector3(0.4, 0.45, 1.2)), wood, "Bench"
		)
		bench.position = Vector3(hx + 0.65, 0.22, hz * 0.62)
		_add_piece(root, result, "roof", bench)
	return result


static func _add_piece(
	root: Node3D, result: Dictionary, group: String, piece: MeshInstance3D
) -> void:
	piece.visible = false
	root.add_child(piece)
	(result[group] as Array).append(piece)
