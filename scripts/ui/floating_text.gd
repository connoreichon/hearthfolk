class_name FloatingText
## M1 (game feel): numerito que brota, sube y se desvanece — «+2 madera»
## sobre el carro, «+1 comida» sobre el huerto. Nada ocurre en silencio.


static func spawn(parent: Node, world_pos: Vector3, text: String, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label: Label3D = Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.011
	label.font_size = 42
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color(0.12, 0.12, 0.1, 0.85)
	parent.add_child(label)
	label.global_position = world_pos + Vector3(0.0, 1.6, 0.0)
	var rise: Tween = label.create_tween()
	rise.set_parallel(true)
	rise.tween_property(
		label, "global_position", label.global_position + Vector3(0.0, 1.1, 0.0), 0.9
	)
	rise.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	rise.chain().tween_callback(label.queue_free)
