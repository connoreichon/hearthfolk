extends Node
## Estado del mundo: inventario, semilla, RNG. No dibuja, no decide IA.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var world_seed: int = 0
var inventory: Dictionary = {&"wood": 0, &"food": 0, &"tools": 0}
var terrain: TerrainData

# Flujo menú → partida: el menú deja aquí la intención y main/world la consume
var pending_new_seed: int = 0
var pending_load_slot: int = 0


func setup_new_game(seed_value: int) -> void:
	world_seed = seed_value
	rng.seed = seed_value
	inventory = {&"wood": 0, &"food": 0, &"tools": 0}


## Sub-semilla determinista derivada de la semilla del mundo.
func derive_seed(parts: Array) -> int:
	var acc: int = world_seed
	for part: Variant in parts:
		acc = hash([acc, part])
	return acc


func add_resource(type: StringName, amount: int) -> void:
	inventory[type] = int(inventory.get(type, 0)) + amount


func take_resource(type: StringName, amount: int) -> bool:
	var have: int = int(inventory.get(type, 0))
	if have < amount:
		return false
	inventory[type] = have - amount
	return true


func get_resource(type: StringName) -> int:
	return int(inventory.get(type, 0))
