class_name Professions
## Oficios v1 (§S2, docs/S2_DESIGN.md): aptitud por atributos+rasgos,
## familias de trabajo y preferencia de tareas. Catálogo EXTENSIBLE:
## un oficio nuevo = una entrada aquí + aptitudes en TraitCatalog.

const LIST: Array[StringName] = [
	&"lenador", &"agricultor", &"constructor", &"recolector", &"repoblador"
]

const NAMES: Dictionary = {
	&"lenador": "Leñador",
	&"agricultor": "Agricultor",
	&"constructor": "Constructor",
	&"recolector": "Recolector",
	&"repoblador": "Repoblador",
	&"": "Sin oficio",
}

## Familia de trabajo principal de cada oficio (velocidad + aptitud).
const FAMILY: Dictionary = {
	&"lenador": &"chop",
	&"agricultor": &"farm",
	&"constructor": &"build",
	&"recolector": &"forage",
	&"repoblador": &"plant",
}

## Tareas del tablón que el oficio prefiere (bonus en best_task_for).
const FAVORED_KINDS: Dictionary = {
	&"lenador": [&"chop"],
	&"agricultor": [&"farm_plant", &"farm_harvest"],
	&"constructor": [&"build", &"supply"],
	&"recolector": [&"haul"],
	&"repoblador": [&"plant"],
}

## Mezcla de atributos por familia de trabajo (pesos de S2_DESIGN §3).
const FAMILY_ATTRS: Dictionary = {
	&"chop": {&"str": 0.7, &"dil": 0.3},
	&"farm": {&"gre": 0.8, &"dil": 0.2},
	&"build": {&"dex": 0.7, &"dil": 0.3},
	&"haul": {&"str": 0.5, &"dil": 0.5},
	&"forage": {&"per": 0.6, &"dil": 0.4},
	&"plant": {&"gre": 0.5, &"dil": 0.5},
}

## Histéresis anti-flapping: el oficio actual defiende su puesto (§5).
const KEEP_BONUS: float = 1.35


static func display_name(profession: StringName) -> String:
	return String(NAMES.get(profession, "Sin oficio"))


static func favored_kinds(profession: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: StringName in FAVORED_KINDS.get(profession, []):
		out.append(kind)
	return out


## Aptitud (~0.3–2.0): atributos normalizados a 6.5 × rasgos de la familia.
static func aptitude(data: CitizenData, profession: StringName) -> float:
	var family: StringName = FAMILY.get(profession, &"forage")
	return _attr_blend(data, family) * TraitCatalog.work_mod(data.traits, family)


## Velocidad de trabajo por familia (§7): clamp(0.6, mezcla × rasgos, 1.6).
## Familia vacía = 1.0 (retrocompatible); &"walk" solo usa rasgos.
## SIN HERRAMIENTAS (orden del dueño) el trabajo manual cuesta un 25 % más:
## talar a mano pelada es lo que tiene — hasta que se tallan su hacha.
static func work_factor(data: CitizenData, family: StringName) -> float:
	if family == &"":
		return 1.0
	if family == &"walk":
		return TraitCatalog.work_mod(data.traits, &"walk")
	var factor: float = clampf(
		_attr_blend(data, family) * TraitCatalog.work_mod(data.traits, family), 0.6, 1.6
	)
	if not data.has_tools:
		factor *= 0.75
	return factor


## Elección de oficio por utilidad (§5): necesidad × aptitud, con el
## oficio actual multiplicado por KEEP_BONUS. needs: oficio → 0..1.
static func choose(data: CitizenData, needs: Dictionary) -> StringName:
	var best: StringName = &"recolector"
	var best_score: float = -1.0
	for profession: StringName in LIST:
		var score: float = float(needs.get(profession, 0.1)) * aptitude(data, profession)
		if profession == data.profession:
			score *= KEEP_BONUS
		if score > best_score:
			best_score = score
			best = profession
	return best


static func _attr_blend(data: CitizenData, family: StringName) -> float:
	var weights: Dictionary = FAMILY_ATTRS.get(family, {})
	if weights.is_empty():
		return 1.0
	var total: float = 0.0
	for key: StringName in weights:
		var value: int = TraitCatalog.final_attribute(data.attrs, data.traits, key)
		total += float(weights[key]) * (float(value) / 6.5)
	return total
