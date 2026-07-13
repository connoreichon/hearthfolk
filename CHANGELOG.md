# CHANGELOG — Hearthfolk

## P6 — Zonas y construcción (2026-07-13)

- Receta `cottage_a.tres` (BuildingRecipe + 4 BuildingPhase: Cimientos 3, Estructura 4, Paredes 3, Tejado 2 = 12 madera).
- `CottageGen`: cabaña 5×4 m por ~36 piezas biseladas con variación por semilla (ventana 3 opciones, tejado ±6°, banco 50 %, color secundario); puerta orientada hacia la fogata en pasos de 90° al colocar. Luz cálida en la ventana cuando alguien duerme dentro de noche.
- `ConstructionSite`: fase 0 con estacas y cuerdas, demanda de material por tareas `supply` (con reserva y cancelación si llega madera del suelo), hasta 2 constructores (`build` tasks), piezas apareciendo una a una con pop 0.9→1.0 y serrín, `construction_stalled` con toast del material exacto que falta, conversión a edificio al terminar (2 plazas de sueño).
- Estados `Supply` (carro→obra con carga visible) y `Build` (martilleo, suelta si falta material).
- La madera del suelo va primero a la obra que la necesita, después al carro (§7.3).
- Herramienta "Zona residencial" (R): rectángulo con snap 0.5 m, ghost verde/rojo translúcido y texto explicando POR QUÉ es inválida (pequeña/fuera/agua/pendiente/árboles/obstáculos/solapes/sin acceso); al confirmar nace zona persistente + obra.
- Navmesh rehorneado al empezar y terminar obras; stand-off de obra 4.0 m (evita atascos en el agujero del navmesh).
- Dormir en cabaña: hasta 2 dentro (ocultos), resto junto a la fogata.
- Tests: obra completa de principio a fin (4 fases, 12 maderas consumidas, ≥30 piezas visibles), reglas de validación de zona. 26 métodos, 353 comprobaciones, 0 fallos.
- Evidencia: `docs/screenshots/p6_building.png` (cimientos), `p6_done.png` (terminada).

## P5 — Transporte (2026-07-13)

- `HaulDispatcher`: publica tareas `haul` (prioridad 4, por delante de la tala) cuando aparece madera; al cargar partida regenera tareas desde el mundo real.
- Estados `CarryResource` (pausa de recogida, el haz desaparece del mundo y aparece en las manos vía Marker3D) y `DeliverResource` (entrega en carro o en obra vía payload `site_id`, listo para P6).
- `Citizen.pick_up/deliver_carry/drop_carry`: capacidad 2, carga visible (2 troncos en manos), interrupciones (comer/dormir) sueltan la carga al suelo como item físico que se re-publica solo.
- Andar cargando: brazos fijos hacia delante, inclinación hacia atrás (modo carry).
- Persistencia de la carga en save_data/load_data.
- Test: 3 haces sembrados → todo acaba en el almacén, inventario exactamente 6, cero items huérfanos. 24 métodos, 336 comprobaciones, 0 fallos.
- Evidencia: `docs/screenshots/p5_haul.png` (tocón + haces + habitante cargando).

## P4 — TaskBoard, tala y madera física (2026-07-13)

- Estados de trabajo: `FindTask` (prioridades §7.3, nunca actúa sin claim), `MoveToResource` (stand-off 1.15 m, timeout, purga de targets muertos), `Harvest` (golpe cada 1.2 s), `RecoverFromStuck` (reintento → apartarse → teleport suave + soltar tarea).
- `TreeEntity` completo: hp 10, inclinación progresiva 6° con astillas, caída hacia el sector seguro (8 sectores, nunca hacia habitantes/obras; los del arco se apartan), rebote al caer, polvo, desvanecido y spawn de 6 unidades de madera en 3 haces + tocón persistente con anillos.
- `ResourceItem` (haz físico de 1–2 troncos con ID y persistencia) y `StumpEntity`.
- Árboles: NavigationObstacle3D dinámico en vez de horneado (talar no rehornea el navmesh).
- Herramienta "Marcar tala" (T): cursor de hacha pixel-art procedural, hover con contorno (blanco válido / rojo "Demasiado joven" con tooltip), clic marca/desmarca publicando/cancelando tareas, caja de arrastre para marcado múltiple, validación de alcanzabilidad con toast "Sin acceso".
- Marcado visual: contorno dorado permanente + hacha 3D flotante con giro.
- Icono de estado sobre la cabeza (§5.5): hacha/fardo/martillo/pan/luna/interrogación como mini-meshes procedurales billboard, desvanecido a >32 m.
- Bugs graves arreglados (ver BUGFIXES.md): congelación de navegación dependiente de semilla (`path_height_offset`), repulsión al llegar al tronco (stand-off).
- Tests: tala completa (6 maderas + tocón + tarea purgada), sin doble reclamación. 23 métodos, 332 comprobaciones, 0 fallos.
- Evidencia: `docs/screenshots/p4_chop.png`.

## P3 — Necesidades y día/noche (2026-07-13)

- `DayNight`: sol rotando por `time_of_day`, color desde `daylight_gradient.tres` (Gradient) y energía desde `daylight_energy.tres` (Curve) — cero colores hardcodeados. Cielo y ambiente oscurecen de noche.
- Fogata: se enciende al atardecer (OmniLight con parpadeo por ruido, llamas emisivas con pulso, chispas GPUParticles3D).
- Necesidades: decaimiento por sim_config (hambre 1.4/min sim; energía 1.8 trabajando / 0.6 idle; recuperación 8/min descansando). Hambre < 10 → −35 % velocidad. `citizen_need_critical` al cruzar 5.
- Estados nuevos: `Eat` (va al carro, consume 1 comida, 4 s, hambre→100, toast si no hay), `Rest` (círculo alrededor de la fogata, tumbado con respiración, despierta al amanecer), `ReturnToSettlement` (noche recoge a todos).
- Interrupciones §7.3: hambre < 25 → Eat; energía < 20 → Rest; noche → Return.
- Velocidades: Espacio pausa (reanuda a la anterior), 1/2/3 = ×1/×2/×4.
- Animaciones: comer sentado con bucle de mano, dormir tumbado con respiración lenta.
- Tests: comer del carro (comida 12→11), 4/4 descansando de noche con fogata encendida, pausa congela reloj y movimiento. 21 métodos, 126 comprobaciones, 0 fallos.
- Evidencia: `docs/screenshots/p3_night.png`.

## P2 — Habitantes visuales (2026-07-13)

- `CitizenVisual`: figura humana estilizada por primitivas biseladas (piernas, cintura+pecho, brazos con manos, cuello, cabeza ovoide, pelo casquete+flequillo), cabeza ≈1/5 de altura, ~1.6 m. Cero cápsulas visibles.
- Animación procedural: caminar (piernas ±25°, brazos contrafase ±20°, bobbing, inclinación 3°), idle (respiración + micro-mirada 2–5 s), esqueleto de trabajo/carga para fases siguientes. Todo interpolado.
- `Citizen` (CharacterBody3D): NavigationAgent3D con RVO (radius 0.35, neighbor_distance 2.5, max_neighbors 6), target_desired_distance 0.35, corte seco de velocidad al llegar, velocidad = move_speed × velocidad de simulación (sin Engine.time_scale), sombra blob, detección de bloqueo 5 s + recuperación.
- FSM: `StateMachine` + `CitizenState` (enter/tick/exit), estados Idle y Wander en archivos propios.
- 4 habitantes (`elian/mara/tobin/nessa.tres`) en anillo de 3 m alrededor de la fogata.
- Test de integración: 4 habitantes aparecen, ≥3 se mueven, sin atravesarse. 18 métodos, 119 comprobaciones, 0 fallos.
- Evidencia: `docs/screenshots/p2_citizens.png` (60 FPS).

## P1 — Mundo y cámara (2026-07-13)

- Paleta, SimConfig y CameraConfig como Resources `.tres` editables.
- `MeshLib`: cajas biseladas (24 caras + 12 chaflanes + 8 esquinas, auto-winding), cilindros con ruido, esferas low-res deformables. Verificado empíricamente que Godot usa winding horario para caras frontales.
- Shaders: `wind` (balanceo por altura), `terrain_blend` (hierba/tierra por vertex color + pendiente), `outline` (back-face inflado).
- `MapGenerator`: terreno 120×120 con semilla (centro plano r=25, colina NE ~4 m, arroyo oeste con canal, camino sur pintado en vertex color), HeightMapShape3D, navmesh horneado por código sin warnings.
- Props por Poisson (Bridson) + Fisher-Yates: 34+12 árboles, 4+14 rocas, 6 flores, 8 arbustos, carro (almacén), fogata central. Jitter de rotación y escala ±12 %.
- `TreeEntity` persistente con IDs estables; `TreeGen` con 5 variantes de silueta.
- Cámara completa: WASD/QE/rueda exponencial 12–80 m, inclinación 48→55°, pan con botón central, doble clic centra, F centra asentamiento, clamp de límites, SpringArm contra terreno, viva en pausa.
- Tests: SimClock (día=480 s, pausa, ×4, anti-espiral, fases), TaskBoard (claim atómico, TTL, blacklist, cooldown, purga de targets), MapGenerator (determinismo, límites de altura, conteos exactos). 17 métodos, 107 comprobaciones, 0 fallos.
- Smoke test visual: `docs/screenshots/p1_world.png` a 60 FPS.

## P0 — Entorno (2026-07-13)

- Godot 4.7 stable instalado (winget) y verificado (`4.7.stable.official.5b4e0cb0f`).
- gdtoolkit 4.5 (gdformat + gdlint) instalado y en uso.
- Proyecto creado en `Desktop\Hearthfolk`: git init, `.gitignore` Godot, estructura completa de carpetas §2.1.
- `project.godot`: Forward+, 1920×1080 canvas_items/expand, `untyped_declaration=2` (error), 8 capas de colisión con nombre, 8 autoloads.
- Autoloads: EventBus (lista cerrada de señales §2.4), SimClock (tick fijo 20 Hz, velocidades, fases del día), GameState (RNG sembrado, inventario), TaskBoard (claim atómico, TTL, blacklist, purga de targets muertos), EntityRegistry (IDs estables), SaveManager (I/O JSON + migraciones), AudioDirector (buses Music/Ambience/SFX/UI), DebugOverlay (F3 con métricas).
- Runner de tests propio (`tests/run_tests.gd`) + `HFTestCase`; primer test de humo verde (11 comprobaciones).
- Puertas P0: `gdformat`+`gdlint` limpios; import headless exit 0; arranque headless `--quit-after 3` exit 0 sin errores; tests exit 0.
