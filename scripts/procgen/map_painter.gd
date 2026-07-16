class_name MapPainter
## Mapa 2D del valle pintado en CPU desde WorldGen (siembra de bandas y
## futuros minimapas). No depende de shaders, sombras ni GPU: lo que pinta
## es SIEMPRE legible — agua azul, playas, praderas, bosques, nieve.

const SNOW_LINE: float = 8.0
const ROCK_LINE: float = 5.0


static func paint(world_gen: WorldGen, size: int = 512) -> Image:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var palette: PaletteData = PaletteData.get_default()
	var half: float = world_gen.map_half
	var step: float = half * 2.0 / float(size)
	var deep: Color = palette.water.darkened(0.35)
	var shore: Color = palette.water.lightened(0.18)
	var sand: Color = Color("#D3BC8B")
	var meadow: Color = palette.grass_light.lightened(0.1)
	var forest: Color = palette.grass.darkened(0.28)
	var hills: Color = palette.dirt_light.lerp(palette.grass, 0.45)
	var rock: Color = palette.stone
	var snow: Color = Color("#E9EDEF")
	for py: int in size:
		var wz: float = -half + (float(py) + 0.5) * step
		# La luz rasante compara con la altura del PÍXEL SIGUIENTE de la
		# fila: arrastrarla evita recalcular height() dos veces por píxel.
		var h: float = world_gen.height(-half + 0.5 * step, wz)
		for px: int in size:
			var wx: float = -half + (float(px) + 0.5) * step
			var h_next: float = world_gen.height(wx + step, wz)
			var color: Color
			if h < WorldGen.WATER_LEVEL:
				var depth: float = clampf((WorldGen.WATER_LEVEL - h) / 1.25, 0.0, 1.0)
				color = shore.lerp(deep, depth)
			elif h < WorldGen.WATER_LEVEL + 0.4:
				color = sand
			elif h > SNOW_LINE:
				color = snow
			elif h > ROCK_LINE:
				var toward_snow: float = clampf((h - ROCK_LINE) / (SNOW_LINE - ROCK_LINE), 0.0, 1.0)
				color = rock.lerp(snow, toward_snow * 0.5)
			else:
				color = meadow.lerp(forest, world_gen.forest_weight(wx, wz))
				color = color.lerp(hills, world_gen.highland_weight(wx, wz) * 0.55)
			# Relieve de un vistazo: luz rasante barata (pendiente hacia el este)
			var slope: float = clampf((h - h_next) * 0.16, -0.14, 0.14)
			color = color.lightened(slope) if slope > 0.0 else color.darkened(-slope)
			img.set_pixel(px, py, color)
			h = h_next
	return img
