extends Node
## Señales globales del juego. Nada de lógica, nada de estado.

# --- Mundo ---
signal tree_marked(tree_id: int)
signal tree_unmarked(tree_id: int)
signal tree_felled(tree_id: int, position: Vector3, wood_units: int)
signal resource_spawned(entity_id: int, type: StringName, position: Vector3)
signal resource_picked(entity_id: int, citizen_id: int)
signal resource_delivered(type: StringName, amount: int, target_id: int)

# --- Habitantes ---
signal citizen_state_changed(citizen_id: int, state: StringName)
signal citizen_stuck(citizen_id: int, position: Vector3)
signal citizen_need_critical(citizen_id: int, need: StringName)

# --- Tareas ---
signal task_published(task_id: int, kind: StringName)
signal task_claimed(task_id: int, citizen_id: int)
signal task_released(task_id: int, reason: StringName)
signal task_completed(task_id: int)

# --- Construcción ---
signal zone_confirmed(zone_id: int, rect: Rect2, kind: StringName)
signal construction_started(building_id: int)
signal construction_phase_advanced(building_id: int, phase: int)
signal construction_completed(building_id: int)
signal construction_stalled(building_id: int, missing: Dictionary)
signal construction_cancelled(building_id: int)

# Siembra de bandas (Build 003)
signal band_placed(band_id: int, center: Vector3)
signal placement_finished

# --- UI / feedback ---
signal tool_changed(tool: StringName)
signal selection_changed(entity_id: int)
signal toast(message: String, kind: StringName)

# --- Sistema ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
