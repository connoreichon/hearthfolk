class_name SettlerGen
## Colonos procedurales (Q3): nombre, colores y proporciones por semilla.

const NAME_START: Array[String] = [
	"Bel",
	"Dor",
	"El",
	"Fen",
	"Gal",
	"Is",
	"Lor",
	"Mar",
	"Nes",
	"Or",
	"Ru",
	"Sal",
	"Tam",
	"Ul",
	"Ver",
	"Yol",
]
const NAME_END: Array[String] = [
	"a",
	"en",
	"ia",
	"in",
	"or",
	"ric",
	"sa",
	"ton",
	"wen",
	"yn",
	"mo",
	"ette",
]
const SHIRTS: Array[String] = [
	"#536F86",
	"#A75F55",
	"#70834D",
	"#8B6B92",
	"#8A794A",
	"#5E8577",
	"#9B6A3F",
	"#6A6F93",
]
const PANTS: Array[String] = ["#4A4038", "#55483E", "#4E4A45", "#514442", "#3E3B36"]
const HAIRS: Array[String] = ["#3B2C22", "#2E2620", "#4A3826", "#241D18", "#6B4A2E", "#8C8378"]
const SKINS: Array[String] = ["#D8A984", "#C99578", "#E0B48F", "#B98B69", "#A87A5C"]


static func generate(rng: RandomNumberGenerator) -> CitizenData:
	var data: CitizenData = CitizenData.new()
	data.display_name = (
		NAME_START[rng.randi_range(0, NAME_START.size() - 1)]
		+ NAME_END[rng.randi_range(0, NAME_END.size() - 1)]
	)
	data.shirt_color = Color(SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)])
	data.pants_color = Color(PANTS[rng.randi_range(0, PANTS.size() - 1)])
	data.hair_color = Color(HAIRS[rng.randi_range(0, HAIRS.size() - 1)])
	data.skin_color = Color(SKINS[rng.randi_range(0, SKINS.size() - 1)])
	data.height_scale = rng.randf_range(0.9, 1.08)
	data.move_speed = rng.randf_range(2.4, 2.8)
	data.work_speed = rng.randf_range(0.9, 1.1)
	return data


## Reconstruir la apariencia desde un guardado (los colonos no tienen .tres).
static func data_from_save(d: Dictionary) -> CitizenData:
	var data: CitizenData = CitizenData.new()
	data.display_name = String(d.get("name", "Colono"))
	data.shirt_color = Color(String(d.get("shirt", "#536F86")))
	data.pants_color = Color(String(d.get("pants", "#4A4038")))
	data.hair_color = Color(String(d.get("hair", "#3B2C22")))
	data.skin_color = Color(String(d.get("skin", "#D8A984")))
	data.height_scale = float(d.get("height", 1.0))
	data.move_speed = float(d.get("move_speed", 2.6))
	data.work_speed = float(d.get("work_speed", 1.0))
	return data
