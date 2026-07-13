# FEATURES — funcionalidades realmente terminadas y probadas (Build 001)

Todo lo listado tiene test automatizado o evidencia de ejecución (ver BUILD_001_REPORT.md).

## Mundo
- Mapa procedural 120×120 m por semilla: centro llano, colina NE (~4 m), arroyo oeste con canal y agua translúcida, camino de tierra sur→centro pintado en vertex color.
- 34 árboles adultos + 12 jóvenes + 4 rocas grandes (obstáculo) + 14 pequeñas + 6 grupos de flores + 8 arbustos, distribución Poisson con jitter (misma semilla → mismo mapa, conteos exactos con test).
- Carro-almacén orientado a la fogata central; 12 comida y 4 herramientas iniciales.
- Ciclo día/noche de 8 minutos (amanecer/día/atardecer/noche) con gradientes .tres, fogata que se enciende al atardecer (parpadeo, llamas, chispas), ventanas de la cabaña iluminadas si alguien duerme dentro.
- Navmesh horneado por código; los árboles son obstáculos dinámicos (talar no rehornea); las obras sí rehornean al empezar y terminar.

## Habitantes (Elian, Mara, Tobin, Nessa)
- Figura procedural biselada con animación por código: caminar, cargar, talar/construir, comer sentado, dormir tumbado, idle con respiración y micro-mirada.
- FSM por archivos: Idle, Wander, FindTask, MoveToResource, Harvest, CarryResource, DeliverResource, Supply, Build, Eat, Rest, ReturnToSettlement, RecoverFromStuck.
- Necesidades hambre/energía (100 = bien) con umbrales de interrupción; sin comida bajan un 35 % de velocidad; descanso/seguridad/vínculo existen en datos y guardado pero no alteran la IA (documentado).
- RVO avoidance, corte seco al llegar, detección de bloqueo 5 s con recuperación en 3 pasos, velocidad ×1/×2/×4 sin tocar el motor.
- Icono de estado sobre la cabeza (hacha/fardo/martillo/pan/luna/?) con desvanecido por distancia.

## Bucle de juego
- Marcar tala (T): clic, caja de arrastre, contornos de hover/marcado, hacha flotante, "Demasiado joven" en jóvenes, aviso "Sin acceso" si no hay ruta.
- Tala: 10 golpes, inclinación progresiva, caída hacia el sector seguro (nunca hacia habitantes/obras; los del arco se apartan), 6 maderas en 3 haces físicos + tocón persistente.
- Transporte: reclamación atómica en TaskBoard (TTL, blacklist, cooldown), carga visible en manos (máx. 2), entrega a obra necesitada primero y si no al carro.
- Zona residencial (R): rectángulo 6×6–14×14 con snap, validación en vivo con motivo exacto (pequeña/fuera/agua/pendiente/árboles/obstáculos/solapes/sin acceso).
- Construcción: estacas y cuerdas → demanda de 12 maderas → 4 fases (cimientos/estructura/paredes/tejado) pieza a pieza con pop y serrín, hasta 2 constructores, `stalled` con toast del material que falta, variación procedural (ventana, tejado ±6°, banco 50 %, color).
- Comer del carro y descanso nocturno (hasta 2 dentro de la cabaña terminada, resto junto a la fogata); de noche no se reclaman tareas nuevas.

## Interfaz y sistema
- HUD: día·hora·población·madera·comida, botones ⏸/×1/×2/×4, barra de herramientas con tooltips y atajos, panel lateral de habitante/obra/árbol con actividad legible y línea al destino, toasts (máx. 4, 4 s).
- Cámara: WASD/QE/rueda exponencial 12–80 m, inclinación 48→55°, pan central, doble clic centra, F centra el asentamiento, límites, SpringArm contra terreno, viva en pausa.
- Guardado JSON con versión y migraciones: autosave 60 s, F5/F9, round-trip guardar→cargar→guardar idéntico (test), tareas regeneradas del mundo al cargar.
- Audio 100 % sintetizado (numpy): ambiente día/noche con crossfade, pájaros/insectos, tala, caída, recogida, pasos, martillo, fuego, UI; límite de voces; sliders de volumen en F3.
- F3: métricas completas, 8 cheats, últimos avisos.
