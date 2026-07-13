class_name PaletteData
extends Resource
## Paleta única del juego (§5.1). Prohibido #FFFFFF y #000000 puros.

static var _instance: PaletteData

@export var grass: Color = Color("#779A55")
@export var grass_light: Color = Color("#94B86A")
@export var dirt: Color = Color("#9B7048")
@export var dirt_light: Color = Color("#B68A5D")
@export var wood: Color = Color("#795238")
@export var wood_light: Color = Color("#A06F47")
@export var stone: Color = Color("#737879")
@export var roof: Color = Color("#A9503E")
@export var cart_cloth: Color = Color("#D9C59C")
@export var water: Color = Color("#5C91A6")
@export var warm_light: Color = Color("#FFD38A")
@export var night: Color = Color("#28364B")
@export var ui_panel: Color = Color("#292B2C")
@export var ui_text: Color = Color("#F3EEE4")
@export var accent: Color = Color("#D9B45B")


static func get_default() -> PaletteData:
	if _instance == null:
		_instance = load("res://data/config/palette.tres") as PaletteData
	return _instance
