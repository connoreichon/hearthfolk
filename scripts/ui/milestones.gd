class_name Milestones
extends Node
## Q5: hitos del asentamiento. Al cumplirse: toast + subida de vínculo.

const BOND_REWARD: float = 10.0

const DEFINITIONS: Array = [
	["first_tree", "Primer árbol talado"],
	["first_house", "Un techo propio: primera casa terminada"],
	["first_harvest", "Primera cosecha en el carro"],
	["five_folk", "Somos cinco: llega el quinto colono"],
	["eight_folk", "Un pueblo de verdad: ocho colonos"],
	["three_houses", "Tres casas en pie"],
	["full_granary", "Granero lleno: 60 de comida"],
	["first_winter", "Primer invierno superado"],
	["one_year", "Un año en la colina"],
]

var done: Dictionary = {}


func _ready() -> void:
	add_to_group(&"milestones")
	EventBus.tree_felled.connect(
		func(_id: int, _pos: Vector3, _wood: int) -> void: complete("first_tree")
	)
	EventBus.construction_completed.connect(_on_house_completed)
	EventBus.resource_delivered.connect(_on_delivered)
	SimClock.day_changed.connect(_on_day_changed)


func is_done(id: String) -> bool:
	return done.has(id)


func complete(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	var title: String = id
	for entry: Array in DEFINITIONS:
		if entry[0] == id:
			title = entry[1]
	EventBus.toast.emit("Hito: %s" % title, &"success")
	AudioDirector.play_ui(&"ui_confirm")
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		citizen.bond = clampf(citizen.bond + BOND_REWARD, 0.0, 100.0)


func summary() -> String:
	var lines: Array[String] = []
	for entry: Array in DEFINITIONS:
		lines.append("%s %s" % ["☑" if done.has(entry[0]) else "☐", entry[1]])
	return "\n".join(lines)


func save_state() -> Array:
	return done.keys()


func load_state(ids: Array) -> void:
	done.clear()
	for id: Variant in ids:
		done[String(id)] = true


func _on_house_completed(_building_id: int) -> void:
	complete("first_house")
	if get_tree().get_nodes_in_group(&"buildings").size() >= 3:
		complete("three_houses")


func _on_delivered(type: StringName, _amount: int, _target: int) -> void:
	if type == &"food":
		complete("first_harvest")


func _on_day_changed(day: int) -> void:
	var population: int = get_tree().get_nodes_in_group(&"citizens").size()
	if population >= 5:
		complete("five_folk")
	if population >= 8:
		complete("eight_folk")
	if GameState.get_resource(&"food") >= 60:
		complete("full_granary")
	if day >= 9:
		complete("one_year")
	if day >= 9 and SimClock.get_season() == SimClock.Season.SPRING:
		complete("first_winter")
