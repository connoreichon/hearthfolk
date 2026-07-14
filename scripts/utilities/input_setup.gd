class_name InputSetup
## Registro del mapa de entrada por código (una sola fuente de verdad).
## Velocidades: Espacio/1/2/3. Herramientas: T tala, R zona, C demoler, I info.


static func setup() -> void:
	_add_key(&"camera_forward", KEY_W)
	_add_key(&"camera_back", KEY_S)
	_add_key(&"camera_left", KEY_A)
	_add_key(&"camera_right", KEY_D)
	_add_key(&"camera_rotate_left", KEY_Q)
	_add_key(&"camera_rotate_right", KEY_E)
	_add_key(&"camera_focus", KEY_F)
	_add_key(&"sim_pause", KEY_SPACE)
	_add_key(&"sim_speed_1", KEY_1)
	_add_key(&"sim_speed_2", KEY_2)
	_add_key(&"sim_speed_3", KEY_3)
	_add_key(&"tool_cancel", KEY_ESCAPE)
	_add_key(&"tool_chop", KEY_T)
	_add_key(&"tool_zone", KEY_R)
	_add_key(&"tool_farm", KEY_H)
	_add_key(&"tool_demolish", KEY_C)
	_add_key(&"tool_info", KEY_I)
	_add_key(&"save_game", KEY_F5)
	_add_key(&"load_game", KEY_F9)
	_add_mouse(&"camera_pan", MOUSE_BUTTON_MIDDLE)


static func _add_key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


static func _add_mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
