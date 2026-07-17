class_name SettlementNames
## Topónimos automáticos (orden del dueño): cada asentamiento nace con un
## nombre evocador, determinista por semilla y con sabor de su bioma.

const ROOTS_BY_BIOME: Dictionary = {
	WorldGen.Biome.PRADERA: ["Vega", "Prado", "Llanada", "Campos", "Herbal"],
	WorldGen.Biome.BOSQUE: ["Umbría", "Fronda", "Robledal", "Espesura", "Boscaje"],
	WorldGen.Biome.RIBERA: ["Vado", "Juncal", "Remanso", "Ribera", "Orillas"],
	WorldGen.Biome.COLINAS: ["Otero", "Loma", "Alcor", "Cerro", "Peñas"],
	WorldGen.Biome.CLARO: ["Claro", "Floresta", "Abejar", "Rosal", "Lirio"],
	WorldGen.Biome.NIEVE: ["Ventisca", "Escarcha", "Nevero", "Carámbano", "Invernal"],
	WorldGen.Biome.SABANA: ["Solana", "Arenal", "Espejismo", "Secarral", "Oasis"],
	WorldGen.Biome.PLAYA: ["Cala", "Marea", "Salitre", "Conchal", "Bahía"],
	WorldGen.Biome.DESIERTO: ["Duna", "Calima", "Erial", "Sequío", "Miraje"],
}

const SUFFIXES: Array[String] = [
	"del Alba",
	"de las Brasas",
	"del Hogar",
	"del Rocío",
	"de la Niebla",
	"del Viento",
	"del Silencio",
	"de la Chispa",
	"de la Luna",
	"del Cuervo",
	"del Verano",
	"de los Diez",
]


static func generate(seed_value: int, biome: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var roots: Array = ROOTS_BY_BIOME.get(biome, ROOTS_BY_BIOME[WorldGen.Biome.PRADERA])
	var root: String = roots[rng.randi_range(0, roots.size() - 1)]
	var suffix: String = SUFFIXES[rng.randi_range(0, SUFFIXES.size() - 1)]
	return "%s %s" % [root, suffix]
