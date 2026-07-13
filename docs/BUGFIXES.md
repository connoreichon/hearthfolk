# BUGFIXES — errores encontrados y corregidos durante el desarrollo

## P1 — Winding invertido en meshes procedurales

- **Síntoma**: (preventivo) caras de las primitivas orientadas hacia dentro.
- **Causa**: Godot usa winding horario para caras frontales; la orientación matemática (cross · outward > 0) genera caras traseras.
- **Diagnóstico**: sonda empírica `tools/dev_probe_winding.gd` comparando un `PlaneMesh` nativo (dot cross·normal = −4) con `MeshLib.beveled_box`.
- **Arreglo**: `MeshLib._tri_out` invierte el orden cuando `cross(b−a, c−a) · outward > 0`.

## P4 — Congelación total del movimiento dependiente de la semilla

- **Síntoma**: con semilla 2222 los 4 habitantes vibraban en el sitio (velocidad invertida cada frame); con 4242 (P2/P3) todo funcionaba. Tests de wander y tala en rojo.
- **Causa raíz**: el navmesh rasterizado (cell_height 0.3) queda hasta ~0.58 m por encima del origen del habitante. `NavigationAgent3D` comprueba la llegada al waypoint con distancia 3D: con `path_desired_distance = 0.5` el waypoint nunca se consume si el desnivel navmesh-origen supera 0.5 (depende de la altura del terreno → de la semilla) y el agente oscila eternamente alrededor del waypoint.
- **Diagnóstico**: sonda `tools/dev_probe_move.gd` — dxz=0.00 pero dy=0.58 con idx congelado.
- **Arreglo**: `nav_agent.path_height_offset = 0.6` (compensa el desnivel en las comprobaciones de proximidad). Los valores del contrato §7.4 (0.5/0.35) se mantienen.

## P4 — Habitante repelido al intentar llegar al centro del árbol

- **Síntoma**: el leñador se paraba a 0.83 m del tronco sin llegar nunca (target_desired_distance 0.35 < radio de colisión del tronco + radio del agente) → detector de bloqueo en bucle.
- **Arreglo**: `Citizen.move_to_near(punto, stand_off)` — objetivo desplazado 1.15 m hacia el habitante y pegado al navmesh; `MoveToResource` considera llegada a < 1.7 m del objetivo.

## P4 — (herramienta) stash conflictivo durante la bisección

- Incidencia de proceso, no del juego: un `git stash pop` con conflictos revirtió 4 ficheros a P3 en mitad del diagnóstico y enmascaró el estado real. Reaplicados y verificados con la suite.
