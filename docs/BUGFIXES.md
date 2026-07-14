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

## P7 — IDs re-registrados al cargar partida

- **Síntoma**: el round-trip guardar→cargar→guardar producía IDs de habitante distintos (47-50 → 53-56); el segundo guardado dejaba de ser idéntico.
- **Causa**: `Citizen._ready` llamaba a `EntityRegistry.register` sin el guard `if entity_id == 0` que sí tenían el resto de entidades: al recrear desde guardado ignoraba el ID restaurado.
- **Diagnóstico**: diff carácter a carácter de las entidades serializadas dentro del test de round-trip.
- **Arreglo**: guard añadido; el test compara campo a campo y entidad a entidad.

## P7 — Lambda tipada rompe con objetos liberados

- **Síntoma**: spam de `Cannot convert argument 1 from Object to Object` en el limitador de voces al liberarse reproductores de audio.
- **Causa**: `filter(func(p: Node) ...)` no puede convertir un objeto ya liberado al tipo `Node`.
- **Arreglo**: parámetro `Variant` + `is_instance_valid`.

## Q6 — Colono atascado al aparecer (isla de navmesh en el borde sur)

- **Síntoma**: el primer soak de la Build 002 falló con «habitante 146 atascado >15 s (min 3.8)»: el primer colono en llegar se quedaba clavado nada más aparecer; el resto de los 40 minutos, limpio.
- **Causa**: el punto de aparición fijo en el borde sur (z=56) puede caer en una isla del navmesh desconectada del pueblo (el rasterizado del borde del mapa genera parches sueltos según la semilla); el escalón (c) de la recuperación teletransporta «al punto navegable más cercano»… que es la misma isla.
- **Arreglo**: `SettlerArrivals._safe_spawn_point()` — prueba z=56/50/44/36/26 sobre el camino, pega el candidato al navmesh y **verifica con `NavUtil.is_reachable` que hay ruta hasta la fogata** antes de usarlo; último recurso: junto a la fogata. Test de regresión que valida la conectividad del spawn.

## P7 — current_scene nulo en headless

- **Síntoma**: errores al parentar partículas/ghost/línea de destino y al buscar World/CameraRig en el runner de tests (`current_scene` no existe en modo `-s`).
- **Arreglo**: parenting local (`get_parent()`) y lookups por los grupos `world` / `camera_rig`.

## Hotfix 002.1 — Crash 0xc0000005 al pulsar «Empezar» (solo template release)

- **Síntoma**: el exe release se cerraba en seco al iniciar/cargar partida desde el menú (2 crashes del probador + repro determinista; visor de eventos: `0xc0000005` en ntdll). En editor, headless y debug funcionaba perfecto.
- **Causa**: la transición `change_scene_to_file` liberaba el mundo de fondo del menú (4 habitantes + RVO + navmesh vivos) en mitad del cambio mientras `SimClock` seguía emitiendo `sim_tick`. Los citizens fuera del árbol ejecutaban `get_tree().get_nodes_in_group(...)` sobre null: el check de instancia nula de GDScript está compilado **solo en debug** (`gdscript_vm.cpp`), en release es deref de puntero nulo → violación de acceso. El camino jamás se había recorrido: el bug del panel invisible impedía llegar y los tests headless simulaban la transición sin `change_scene` real.
- **Arreglo** (cinturón y tirantes):
  - Guarda `is_inside_tree()` al inicio de `_on_sim_tick` en `citizen.gd`, `construction_site.gd` y `farm_field.gd`.
  - Desmontaje determinista en ambas transiciones (`main_menu._change_to_game`, `main._exit_to_menu`): pausar SimClock → liberar el mundo → esperar 2 frames → limpiar TaskBoard/EntityRegistry → `change_scene_to_file`.
  - Lambdas conectadas a señales de autoloads convertidas a métodos con nombre (`hud.gd`, `season_controller.gd`): las lambdas no se desconectan al morir el nodo.
  - `main_menu._capture` por conexión de señal en vez de `await` (no reanudar corrutinas sobre objetos liberados).
- **Verificación**: 4/4 corridas release del flujo real vivas + 2/2 con captura limpia. Nuevo `tools/release_smoke.ps1` en el ritual: ninguna build sale sin ejecutar el flujo real contra el template release.
- **Bonus**: la partida nueva ya no hereda el reloj del menú (empezaba al atardecer); ahora `SimClock.reset(1, 0.25)` + velocidad normal.

## Hotfix 002.1 — Pantalla entera marrón al avanzar con W

- **Síntoma**: manteniendo W unos segundos, la pantalla se ponía marrón por completo y no se veía nada.
- **Causa**: con zoom por defecto la cámara cuelga ~26 m por detrás del pivot; el clamp de límites (`map_half_size - map_margin`) solo acota el pivot, así que en ~3 s de W llegabas al borde y te quedabas mirando el **vacío de detrás del mapa**, que el cielo procedural pinta de marrón tierra de suelo a cénit. Los soaks nunca mueven la cámara y las capturas eran del spawn: nadie lo había mirado.
- **Arreglo**: (1) clamp consciente del zoom (`- arm.spring_length * 0.35`); (2) falda de horizonte (disco de pradera r=600 bajo el borde) para que el más allá sea campo lejano; (3) hemisferio inferior del cielo verde oliva apagado en vez de barro; (4) el SpringArm ya no colisiona con el terreno (encogía el brazo tras una colina) — la altura la garantiza `CAMERA_CLEARANCE` sobre el terreno bajo la cámara.
- **Verificación**: autopiloto nuevo `--drive N` (mantiene W N segundos) + captura; antes/después en `docs/screenshots/repro_camera_brown.png` y `camera_fix_v2.png`.

## Hotfix 002.2 — «Sin acceso desde el asentamiento» en todo el mapa + demolición incompleta

- **Síntoma** (QA humano): tras demoler una obra, ninguna zona nueva validaba en ningún punto del mapa. Además las cabañas terminadas y los huertos no se podían demoler.
- **Causa raíz del bloqueo** (¡no era la demolición!): el horneado del navmesh convierte la TAPA del collider de la fogata (cilindro r=1.35, alto ~1.4) en una isla de navmesh desconectada. `map_get_closest_point(fogata)` prefiere esa tapa (1.38 m vertical) antes que el anillo del suelo (1.95 m horizontal), así que `is_reachable` arrancaba el camino en la isla y moría ahí → acceso denegado GLOBAL. Mina plantada al agrandar el collider en los soaks de Q6; diagnosticada con `tools/dev_probe_zone.gd`.
- **Arreglo**: `NavUtil.is_reachable` reintenta desde un anillo de 6 sondas (r=2.6) alrededor del origen si el snap directo no llega — inmune a cualquier isla futura (tapa del carro, tejados). Verificado: válido desde el frame 0.
- **Demolición completa**: `TaskBoard.cancel_for_target()` barre las tareas del objetivo (antes quedaban huérfanas), `construction_cancelled` rehornea el navmesh (antes el agujero de la obra muerta se quedaba), flag `demolished` corta la republicación en el mismo frame, las cabañas TERMINADAS se pueden demoler (50 % de madera de vuelta) y los huertos también (herramienta C). 3 tests de regresión en `test_demolish.gd`.
