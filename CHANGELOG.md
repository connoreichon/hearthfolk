# CHANGELOG — Hearthfolk

# BUILD 004 — «Camino al Mercado» (en curso)

## HOTFIX — Pantalla de siembra a plena luz (2026-07-16)
- La pantalla de reparto de bandas se veía casi negra tras V1 (luminancia
  media 56/255). Causa real encontrada por bisección visual: NO era la hora
  del día — la vista de águila (≈460 m) queda entera FUERA del alcance de
  sombras del sol de V1 (PSSM, 240 m) y la falda del horizonte, aplastada en
  el mapa de sombras, enterraba el valle en una sombra falsa.
- Arreglo en `world.gd` (rama de siembra, sin tocar el `BandPlacer`):
  mediodía limpio congelado (`SimClock.reset(1, 0.40)` + PAUSED) y sombra
  direccional APAGADA solo mientras se siembra; ambas cosas vuelven al
  confirmar el reparto (`placement_finished`). La hora dorada del juego en
  marcha queda intacta.
- Verificado: captura regenerada con `dev_probe_placement.gd` — luminancia
  media 151/255 (objetivo ≥150); etiqueta de bioma/validez legible.

## V1 — Luz y atmósfera «Hora dorada eterna» (2026-07-16)
- Dirección de arte fijada en `docs/ART_DIRECTION_VISUAL.md`: valle de
  juguete bañado en la última luz de la tarde, la hoguera como corazón.
- Curva de día con intención (`daylight_gradient/energy.tres`): amanecer
  ROSADO brumoso, mediodía limpio, HORA DORADA ámbar intensa (energía
  1.15 con color oro = contraluz), atardecer naranja rasante, noche azul.
- God rays baratos: niebla volumétrica tenue (density 0.022, anisotropía
  0.65) que DayNight enciende SOLO en amanecer y hora dorada, con fundido.
- La niebla de distancia vive el ciclo: verdosa de día → AZUL de noche.
- SSAO 2.2/r2.0/p1.8 + SSIL 0.9/r4.0: los objetos se POSAN en el suelo y
  la hierba rebota color en las bases. Sombras: blur 1.35, bias afinado.
- Sonda `dev_probe_visual.gd`: 6 vistas fijas (amanecer/dorada/mediodía/
  noche/águila/retrato) a 1920×1080 con la misma semilla — capturas
  antes/después en `docs/screenshots/visual/`.

## M0 — Arreglos previos (2026-07-16)
- `NavUtil.map_ready()` + guards en TODAS las queries de navegación
  tempranas (rest_spot, move_to_near, desatascos, llegadas, recover):
  adiós al `query failed before first map synchronization`. Test de
  regresión `test_nav_ready.gd`.
- 0 «edge errors» del bake: celda XY 0.4 + agent_radius 0.4 (múltiplos
  exactos), bloqueadores de agua fusionados en tiras, y respiro de 2
  frames entre ficheros del runner. Diagnóstico por bisección con el
  filtro nuevo `HF_TEST_FILTER` del runner.
- `test_haul_flow` determinista (herramientas de serie, ventana mayor,
  settle por condición): 20/20 corridas verdes.
- Salida limpia del runner: `ResourceJanitor` (caches estáticos) +
  `AudioDirector.shutdown()` (tween de música blindado y matado, streams
  liberados) + drenaje del hilo de audio. 0 RID leaked; quedan 4 objetos
  efímeros estables documentados en LIMITATIONS.md.

# BUILD 002 — «Un año en la colina» (2026-07-14)

## Q0 — Cara de juego
- Menú principal con el asentamiento vivo de fondo (cámara orbital), nueva partida con 3 slots + semilla, cargar con resumen por slot, opciones persistentes (volúmenes por bus, pantalla completa, vsync), menú de pausa (Esc), autosave por slot, icono procedural (ventana + .ico).

## Q1 — Estaciones
- Año de 8 días (2 por estación) con señal `season_changed`; tintes globales de shader para hojas/hierba con transición suave, nieve en invierno, luz solar estacional; brotes que crecen en primavera y siembra natural en otoño (tope 70 árboles) — el bosque se repuebla.

## Q2 — Huerto
- `FarmField` con parcelas de 1.25 m (tierra→plantada→brote→madura), herramienta Huerto (H), tareas de plantar/cosechar (cosecha prioritaria), la cosecha es un item físico que viaja al carro; hambre ×11 (2 comidas/día): la comida es economía de verdad; el huerto duerme en invierno.

## Q3 — El pueblo crece
- Colonos procedurales (nombre/colores/altura por semilla, guardado autosuficiente) que llegan por el camino del sur en primavera/verano si hay cama y excedente; camas = 4 base + literas por casa; receta Casa larga (cottage_b: 6×3.6, 3 camas, chimenea) alternada con la clásica.

## Q4 — Moral
- Seguridad y vínculo activos: compañía, fuego, techo e invierno mueven el ánimo; la moral (0–1) escala el trabajo entre 0.6 y 1.15 y se lee en el panel ("Contento/Tranquilo/Inquieto/Desanimado").

## Q5 — Metas, eventos y música
- 9 hitos con recompensa de vínculo y panel propio; eventos al amanecer (helada que encoge brotes, viajero con comida, bandada); música generativa pentatónica por estación (numpy) con fundido cruzado.

## Q6 — Entrega
- Soak de 40 min ×4 (~2.5 años) con el bucle completo; export y zip para itch.io. (Resultados en BUILD_002_REPORT.md.)

## P8 — Soak, export y entrega (2026-07-13)

- Soak test §17.3 (`tests/soak/soak_20min.gd`): 20 minutos reales a ×4 con el bucle completo (10 árboles + obra) → **OK**: día 11, entidades 51→51, 1 casa, memoria 58.3→58.2 MB, 0 atascos >15 s, contabilidad de madera exacta (60 = 12 casa + 48 carro).
- Export templates 4.7.stable instalados; `build/Hearthfolk_001.exe` (107.5 MB, pck embebido) exportado y verificado ejecutándolo (captura desde el propio .exe).
- Documentación final: FEATURES, LIMITATIONS, STRUCTURE, DECISIONS ampliado, checklist §19 completo en BUILD_001_REPORT.md.

## P7 — UI, audio, guardado y depuración (2026-07-13)

- `tools/gen_audio.py` (solo numpy): 17 WAVs sintetizados — ambiente de bosque (ruido rosa Voss + LFO), viento, 4 pájaros (glissando), insectos nocturnos (AM), tala, caída de árbol, recogida, 4 pasos, martillo, fuego (ruido marrón + crepitación), clic/confirmación/error de UI.
- `AudioDirector`: buses Master/Music/Ambience/SFX/UI, ambiente día/noche con crossfade, fuego posicional nocturno, pájaros espaciados, one-shots con límite de 3 voces, pasos por distancia recorrida, hooks de EventBus (tala, caída, recogida, toasts, fases de obra).
- HUD (§12): barra superior día·hora·población·madera·comida + botones ⏸/×1/×2/×4 con estado; barra inferior de 5 herramientas con tooltips y atajos; panel lateral de habitante (actividad legible, hambre, energía, tarea) y de obra (fase, progreso, entregado, quién trabaja); línea sutil al destino del seleccionado; toasts apilados máx. 4 con auto-desvanecido.
- Herramientas nuevas: Selección/Información (clic → panel) y Demoler (cancela obras con reembolso de madera y zonas; desmarca árboles).
- Guardado completo (§14): captura por IDs estables, autosave 60 s reales (no en pausa), F5/F9, migraciones con defaults. Carga: regeneración determinista del mapa (mismos IDs de árboles), poda de árboles talados, recreación por ID de tocones/items/zonas/obras/habitantes, tareas regeneradas desde el mundo, cámara restaurada.
- F3 completo (§15): FPS/ms, ticks/s, estados de habitantes, tareas libres/reservadas/fallos, rutas fallidas, atascos, entidades/nodos/cuerpos físicos, últimos avisos + 8 cheats + sliders de volumen.
- Bugs cazados: `Citizen._ready` re-registraba IDs al cargar (round-trip roto), lambda tipada del limitador de voces reventaba con objetos liberados, `current_scene` nulo en headless (parenting robusto por grupos).
- Tests: round-trip guardar→cargar→guardar semánticamente idéntico (campo a campo + diff por carácter), migración con campos ausentes. 28 métodos, 377 comprobaciones, 0 fallos.
- Evidencia: `docs/screenshots/p7_hud.png`.

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
