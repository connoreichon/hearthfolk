class_name OptionsPanel
extends PanelContainer
## Panel de opciones reutilizable (menú principal y pausa): volúmenes,
## pantalla completa y vsync. Persiste vía Settings.

signal closed


func _ready() -> void:
	var palette: PaletteData = PaletteData.get_default()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette.ui_panel, 0.96)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	add_theme_stylebox_override(&"panel", style)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)

	var title: Label = Label.new()
	title.text = "Opciones"
	title.add_theme_color_override(&"font_color", palette.accent)
	title.add_theme_font_size_override(&"font_size", 24)
	box.add_child(title)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 6)
	box.add_child(grid)
	for bus: String in Settings.AUDIO_BUSES:
		var label: Label = Label.new()
		label.text = "Volumen %s" % bus
		label.add_theme_color_override(&"font_color", palette.ui_text)
		grid.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.get_volume(bus)
		slider.custom_minimum_size = Vector2(220.0, 20.0)
		slider.value_changed.connect(func(value: float) -> void: Settings.set_volume(bus, value))
		grid.add_child(slider)

	var fullscreen: CheckBox = CheckBox.new()
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = Settings.is_fullscreen()
	fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	box.add_child(fullscreen)

	var vsync: CheckBox = CheckBox.new()
	vsync.text = "Sincronía vertical (VSync)"
	vsync.button_pressed = Settings.is_vsync()
	vsync.toggled.connect(func(on: bool) -> void: Settings.set_vsync(on))
	box.add_child(vsync)

	var back: Button = Button.new()
	back.text = "Volver"
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)
