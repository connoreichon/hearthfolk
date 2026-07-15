class_name TraitCatalog
## Catálogo de rasgos de nacimiento (§S2, docs/S2_DESIGN.md).
## GRANDE por diseño: cada build activa más entradas. `hereditary` existe
## desde el día uno para que la genética (Build 004) se enchufe sin migrar.
## Familias de trabajo v1: chop, build, farm, haul, forage, walk.

const VIRTUD: int = 0
const DEFECTO: int = 1

## id → {nombre, detalle, tipo, hereditary, activo, attr_mod, work_mod}
const CATALOG: Dictionary = {
	# --- Activos v1 (mecánica real) ---
	&"brazos_de_roble":
	{
		"nombre": "Brazos de roble",
		"detalle": "El hacha parece pesarle menos que a nadie.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": true,
		"attr_mod": {&"str": 2},
		"work_mod": {&"chop": 1.25},
	},
	&"manos_de_jardinero":
	{
		"nombre": "Manos de jardinero",
		"detalle": "Lo que planta, brota; lo que cuida, florece.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": true,
		"attr_mod": {&"gre": 2},
		"work_mod": {&"farm": 1.25},
	},
	&"ojo_avizor":
	{
		"nombre": "Ojo avizor",
		"detalle": "Ve la baya madura donde otros ven matorral.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": true,
		"attr_mod": {&"per": 2},
		"work_mod": {&"forage": 1.3},
	},
	&"pulso_de_cantero":
	{
		"nombre": "Pulso de cantero",
		"detalle": "Sus junturas no dejan pasar ni el viento.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": true,
		"attr_mod": {&"dex": 2},
		"work_mod": {&"build": 1.25},
	},
	&"zancada_larga":
	{
		"nombre": "Zancada larga",
		"detalle": "Llega antes que su propia sombra.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": true,
		"attr_mod": {},
		"work_mod": {&"walk": 1.12},
	},
	&"espalda_de_mula":
	{
		"nombre": "Espalda de mula",
		"detalle": "Carga sin quejarse lo que otros ni levantan.",
		"tipo": VIRTUD,
		"hereditary": false,
		"activo": true,
		"attr_mod": {},
		"work_mod": {&"haul": 1.3},
	},
	&"madrugador":
	{
		"nombre": "Madrugador",
		"detalle": "El primero en pie cuando el fuego aún dormita.",
		"tipo": VIRTUD,
		"hereditary": false,
		"activo": true,
		"attr_mod": {&"dil": 1},
		"work_mod": {},
	},
	&"manos_de_madera":
	{
		"nombre": "Manos de madera",
		"detalle": "Torpe con lo fino; temible con lo bruto.",
		"tipo": DEFECTO,
		"hereditary": true,
		"activo": true,
		"attr_mod": {&"dex": -2},
		"work_mod": {&"build": 0.8, &"chop": 1.1},
	},
	&"flojera_de_brazos":
	{
		"nombre": "Flojera de brazos",
		"detalle": "El hacha le devuelve cada golpe con intereses.",
		"tipo": DEFECTO,
		"hereditary": true,
		"activo": true,
		"attr_mod": {&"str": -2},
		"work_mod": {&"chop": 0.8},
	},
	&"pies_planos":
	{
		"nombre": "Pies planos",
		"detalle": "Cada legua le cuesta legua y media.",
		"tipo": DEFECTO,
		"hereditary": false,
		"activo": true,
		"attr_mod": {},
		"work_mod": {&"walk": 0.88},
	},
	&"distraido":
	{
		"nombre": "Distraído",
		"detalle": "Capaz de perderse entre la hoguera y el carro.",
		"tipo": DEFECTO,
		"hereditary": false,
		"activo": true,
		"attr_mod": {&"per": -2},
		"work_mod": {&"forage": 0.75},
	},
	&"mal_de_espalda":
	{
		"nombre": "Mal de espalda",
		"detalle": "Los fardos le pasan factura al tercer paso.",
		"tipo": DEFECTO,
		"hereditary": false,
		"activo": true,
		"attr_mod": {},
		"work_mod": {&"haul": 0.75},
	},
	# --- Definidos, sin mecánica todavía (builds siguientes) ---
	&"buena_mano_al_timon":
	{
		"nombre": "Buena mano al timón",
		"detalle": "El agua le obedece como a pocos.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"voz_de_pastor":
	{
		"nombre": "Voz de pastor",
		"detalle": "Los animales acuden cuando llama.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"paciencia_de_pescador":
	{
		"nombre": "Paciencia de pescador",
		"detalle": "Sabe esperar a que el río decida.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"levadura_en_las_venas":
	{
		"nombre": "Levadura en las venas",
		"detalle": "Su pan se huele desde tres casas.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"miedo_al_agua":
	{
		"nombre": "Miedo al agua",
		"detalle": "Ni el puente le quita el sudor frío.",
		"tipo": DEFECTO,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"alma_creativa":
	{
		"nombre": "Alma creativa",
		"detalle": "Donde otros apilan piedras, ve un tótem.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"punteria_de_lince":
	{
		"nombre": "Puntería de lince",
		"detalle": "Lo que mira, lo alcanza.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"torpe_con_el_arma":
	{
		"nombre": "Torpe con el arma",
		"detalle": "Mejor no ponerle una lanza cerca.",
		"tipo": DEFECTO,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"sangre_friolera":
	{
		"nombre": "Sangre friolera",
		"detalle": "El invierno se le mete en los huesos.",
		"tipo": DEFECTO,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"piel_del_desierto":
	{
		"nombre": "Piel del desierto",
		"detalle": "El sol de mediodía no le arranca ni una queja.",
		"tipo": VIRTUD,
		"hereditary": true,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"memoria_de_anciano":
	{
		"nombre": "Memoria de anciano",
		"detalle": "Recuerda inviernos que nadie más vivió.",
		"tipo": VIRTUD,
		"hereditary": false,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
	&"duerme_poco":
	{
		"nombre": "Duerme poco",
		"detalle": "La noche le rinde como a otros la mañana.",
		"tipo": VIRTUD,
		"hereditary": false,
		"activo": false,
		"attr_mod": {},
		"work_mod": {},
	},
}

const ATTR_KEYS: Array[StringName] = [&"str", &"dex", &"per", &"gre", &"dil"]


static func entry(id: StringName) -> Dictionary:
	return CATALOG.get(id, {})


static func active_of_type(tipo: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CATALOG:
		var e: Dictionary = CATALOG[id]
		if bool(e["activo"]) and int(e["tipo"]) == tipo:
			out.append(id)
	return out


## Reparto al nacer (§S2_DESIGN 2): 1 virtud garantizada, 70 % de un
## defecto, 20 % de segunda virtud. Solo rasgos ACTIVOS. Sin repetidos.
static func roll_traits(rng: RandomNumberGenerator) -> Array[StringName]:
	var virtues: Array[StringName] = active_of_type(VIRTUD)
	var defects: Array[StringName] = active_of_type(DEFECTO)
	var out: Array[StringName] = []
	out.append(virtues[rng.randi_range(0, virtues.size() - 1)])
	if rng.randf() < 0.7:
		out.append(defects[rng.randi_range(0, defects.size() - 1)])
	if rng.randf() < 0.2:
		var second: StringName = virtues[rng.randi_range(0, virtues.size() - 1)]
		if second not in out:
			out.append(second)
	return out


## Tirada de atributos (§S2_DESIGN 1): 3–10, campana suave centrada en ~6.5.
static func roll_attributes(rng: RandomNumberGenerator) -> Dictionary:
	var attrs: Dictionary = {}
	for key: StringName in ATTR_KEYS:
		attrs[key] = 3 + rng.randi_range(0, 3) + rng.randi_range(0, 4)
	return attrs


## Atributo final = base + modificadores de rasgos, acotado 1–10.
static func final_attribute(attrs: Dictionary, traits: Array, key: StringName) -> int:
	var value: int = int(attrs.get(key, 6))
	for id: StringName in traits:
		var e: Dictionary = entry(id)
		if not e.is_empty():
			value += int((e["attr_mod"] as Dictionary).get(key, 0))
	return clampi(value, 1, 10)


## Multiplicador de velocidad de una familia de trabajo por los rasgos.
static func work_mod(traits: Array, family: StringName) -> float:
	var factor: float = 1.0
	for id: StringName in traits:
		var e: Dictionary = entry(id)
		if not e.is_empty():
			factor *= float((e["work_mod"] as Dictionary).get(family, 1.0))
	return factor
