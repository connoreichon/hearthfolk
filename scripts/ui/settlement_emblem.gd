class_name SettlementEmblem
extends Control
## Emblema procedural del asentamiento: estandarte con el color de su
## bioma, ribete de brasa y un símbolo sencillo (ola, árbol, sol, monte,
## flor). Determinista por semilla — el mismo pueblo, el mismo escudo.

const BIOME_COLORS: Dictionary = {
	WorldGen.Biome.PRADERA: Color("#7FA05A"),
	WorldGen.Biome.BOSQUE: Color("#708455"),
	WorldGen.Biome.RIBERA: Color("#6E93A3"),
	WorldGen.Biome.COLINAS: Color("#8E8B84"),
	WorldGen.Biome.CLARO: Color("#9B85B5"),
	WorldGen.Biome.NIEVE: Color("#B8C6D2"),
	WorldGen.Biome.SABANA: Color("#C9A85C"),
}
const EMBER: Color = Color("#E8703A")

var biome: int = WorldGen.Biome.PRADERA
var emblem_seed: int = 0


func _init(which_biome: int = 0, seed_value: int = 0) -> void:
	biome = which_biome
	emblem_seed = seed_value
	custom_minimum_size = Vector2(26.0, 34.0)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var banner: PackedVector2Array = PackedVector2Array(
		[
			Vector2(1, 1),
			Vector2(w - 1, 1),
			Vector2(w - 1, h * 0.72),
			Vector2(w * 0.5, h - 1),
			Vector2(1, h * 0.72),
		]
	)
	var base: Color = BIOME_COLORS.get(biome, BIOME_COLORS[WorldGen.Biome.PRADERA])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = emblem_seed
	base = base.lightened(rng.randf_range(-0.06, 0.1))
	draw_colored_polygon(banner, base)
	var outline: PackedVector2Array = banner.duplicate()
	outline.append(banner[0])
	draw_polyline(outline, EMBER, 1.5)
	var cx: float = w * 0.5
	var cy: float = h * 0.4
	var ink: Color = Color(1.0, 0.96, 0.88, 0.92)
	match biome:
		WorldGen.Biome.RIBERA:
			for i: int in 2:
				var y: float = cy - 3.0 + float(i) * 6.0
				var wave: PackedVector2Array = PackedVector2Array()
				for s: int in 9:
					var x: float = cx - 8.0 + float(s) * 2.0
					wave.append(Vector2(x, y + sin(float(s) * 1.3) * 2.0))
				draw_polyline(wave, ink, 1.6)
		WorldGen.Biome.BOSQUE:
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(cx, cy - 7.0),
						Vector2(cx - 6.0, cy + 5.0),
						Vector2(cx + 6.0, cy + 5.0)
					]
				),
				ink
			)
			draw_rect(Rect2(cx - 1.2, cy + 5.0, 2.4, 4.0), ink)
		WorldGen.Biome.COLINAS:
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(cx - 8.0, cy + 6.0),
						Vector2(cx - 2.0, cy - 5.0),
						Vector2(cx + 3.0, cy + 6.0)
					]
				),
				ink
			)
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(cx + 0.0, cy + 6.0),
						Vector2(cx + 5.0, cy - 2.0),
						Vector2(cx + 9.0, cy + 6.0)
					]
				),
				ink
			)
		WorldGen.Biome.CLARO:
			for i: int in 5:
				var ang: float = TAU * float(i) / 5.0
				draw_circle(Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * 4.0, 2.2, ink)
			draw_circle(Vector2(cx, cy), 2.0, EMBER)
		_:
			draw_circle(Vector2(cx, cy), 5.5, ink)
			for i: int in 8:
				var ang: float = TAU * float(i) / 8.0
				var from: Vector2 = Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * 7.0
				var to: Vector2 = Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * 9.5
				draw_line(from, to, ink, 1.4)
