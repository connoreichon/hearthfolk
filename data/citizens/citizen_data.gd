class_name CitizenData
extends Resource
## Datos de un habitante (§3). Colores y parámetros editables por .tres.

@export var display_name: String = "Elian"
@export var shirt_color: Color = Color("#536F86")
@export var pants_color: Color = Color("#4A4038")
@export var hair_color: Color = Color("#3B2C22")
@export var skin_color: Color = Color("#D8A984")
@export var height_scale: float = 1.0
@export var move_speed: float = 2.6
@export var work_speed: float = 1.0
## S2 — rasgos de nacimiento y oficio. Vacíos = se tiran en Citizen._ready
## (determinista por semilla de mundo + nombre); así los .tres artesanales
## y los guardados antiguos ganan rasgos sin migración.
@export var attrs: Dictionary = {}
@export var traits: Array[StringName] = []
@export var profession: StringName = &""
## Progresión de herramientas (orden del dueño): nacen SIN nada y se
## tallan sus primeras herramientas rudimentarias junto a la hoguera.
## Sin herramientas el trabajo cuesta más. (Minas y metales: Build 004.)
@export var has_tools: bool = false
