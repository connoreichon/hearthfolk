extends HFTestCase
## S2: catálogo de rasgos — tiradas deterministas, virtud garantizada,
## defectos probables, modificadores y flags hereditarios desde el día uno.


func test_catalog_is_big_and_well_formed() -> void:
	assert_true(TraitCatalog.CATALOG.size() >= 24, "catálogo GRANDE desde el día uno")
	var active: int = 0
	for id: StringName in TraitCatalog.CATALOG:
		var entry: Dictionary = TraitCatalog.CATALOG[id]
		for key: String in [
			"nombre", "detalle", "tipo", "hereditary", "activo", "attr_mod", "work_mod"
		]:
			assert_true(entry.has(key), "%s tiene la clave %s" % [id, key])
		if bool(entry["activo"]):
			active += 1
	assert_true(active >= 12, "al menos 12 rasgos con mecánica real en v1")


func test_roll_is_deterministic() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 777
	rng_b.seed = 777
	assert_eq(TraitCatalog.roll_traits(rng_a), TraitCatalog.roll_traits(rng_b))
	assert_eq(TraitCatalog.roll_attributes(rng_a), TraitCatalog.roll_attributes(rng_b))


func test_every_roll_has_a_virtue_and_only_active_traits() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var defect_rolls: int = 0
	for _i: int in 60:
		var rolled: Array[StringName] = TraitCatalog.roll_traits(rng)
		assert_true(rolled.size() >= 1, "siempre nace con algo")
		var has_virtue: bool = false
		var has_defect: bool = false
		for id: StringName in rolled:
			var entry: Dictionary = TraitCatalog.entry(id)
			assert_true(bool(entry["activo"]), "solo se reparten rasgos activos")
			if int(entry["tipo"]) == TraitCatalog.VIRTUD:
				has_virtue = true
			else:
				has_defect = true
		assert_true(has_virtue, "1 virtud garantizada (§S2_DESIGN 2)")
		if has_defect:
			defect_rolls += 1
	assert_true(defect_rolls >= 30, "los defectos son PROBABLES (~70 %%): %d/60" % defect_rolls)
	assert_true(defect_rolls <= 55, "pero no universales: %d/60" % defect_rolls)


func test_attributes_land_in_range() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for _i: int in 20:
		var attrs: Dictionary = TraitCatalog.roll_attributes(rng)
		assert_eq(attrs.size(), TraitCatalog.ATTR_KEYS.size())
		for key: StringName in attrs:
			assert_true(int(attrs[key]) >= 3 and int(attrs[key]) <= 10, "3–10")


func test_modifiers_apply_and_clamp() -> void:
	var attrs: Dictionary = {&"str": 9, &"dex": 5, &"per": 6, &"gre": 6, &"dil": 6}
	var traits: Array[StringName] = [&"brazos_de_roble", &"manos_de_madera"]
	assert_eq(TraitCatalog.final_attribute(attrs, traits, &"str"), 10, "9+2 acota a 10")
	assert_eq(TraitCatalog.final_attribute(attrs, traits, &"dex"), 3, "5−2 por manos de madera")
	assert_almost_eq(TraitCatalog.work_mod(traits, &"chop"), 1.25 * 1.1, 0.001, "roble×madera")
	assert_almost_eq(TraitCatalog.work_mod(traits, &"build"), 0.8, 0.001)
	assert_almost_eq(TraitCatalog.work_mod(traits, &"farm"), 1.0, 0.001, "familia ajena: 1.0")


func test_hereditary_flags_exist_from_day_one() -> void:
	assert_true(bool(TraitCatalog.entry(&"brazos_de_roble")["hereditary"]))
	assert_false(bool(TraitCatalog.entry(&"espalda_de_mula")["hereditary"]))
	assert_true(bool(TraitCatalog.entry(&"miedo_al_agua")["hereditary"]), "también los inactivos")
