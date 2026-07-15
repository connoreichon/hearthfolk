# BUILD 003 — «Las Culturas del Fuego»

Orden de producción. Sustituye el juego de zonas de la 002 por una aldea
emergente con identidad propia. Diseños completos con críticas en
`docs/design/003_diseno_ola1.json` y `003_diseno_ola2.json`; dirección de
arte canon en `docs/ART_DIRECTION_003.md`.

## Visión (inamovible)

El jugador **siembra bandas** de colonos donde quiera y después solo gestiona
como **espíritu del hogar** — sopla brasas, bendice, atiende peticiones; nunca
ordena. Los aldeanos tienen rasgos variados, **eligen oficio solos**, talan
solos, y acabarán **construyendo sus casas solos**. Los caminos **emergen por
donde camina la gente**. Cada banda enciende SU hoguera, y esa hoguera es la
**semilla de su cultura**: del bioma y de los fundadores nacen ropa, tótem,
música y crónica distintas. Eras: pieles → madera → piedra. Inspirado en
WorldBox sin parecerlo: cero verbos punitivos, escasez y cuidado, y son los
aldeanos quienes ritualizan — el jugador solo aviva.

## Qué muere de la Build 002

- La fogata y el carro centrales pregenerados, y el camino de tierra del spawn.
- El chequeo «Sin acceso desde el asentamiento» (ya sin uso al no colocar el jugador).
- Las llegadas de colonos por el camino sur (pasan a llegar «al humo» del campamento más cercano al borde).
- Las herramientas R/H del jugador — PERO solo cuando la autoconstrucción esté verde (S6): hasta entonces siguen como puente jugable, apuntando al campamento más cercano.
- Los guardados de la 002 (bump a FORMAT_VERSION 2 en S0; los slots viejos se marcan «versión antigua» en el menú).

## Contrato técnico

El de siempre (tick 20 Hz, tipado como error, TaskBoard atómico, IDs estables,
100 % procedural, gdformat+gdlint) **más la puerta nueva de la 002.1**: ninguna
fase cierra sin `suite verde + tools/release_smoke.ps1 OK`. Notas de
implementación aprendidas por los críticos, vigentes en TODA la build:

1. **Prioridad del TaskBoard: 0 = máxima.** Tres diseños la leyeron al revés. Sugerencias del jugador = número MÁS ALTO que las tareas de oficio.
2. **Inventario GLOBAL compartido** en toda la Build 003 (la economía por aldea es Build 004). Se declara y no se discute en cada sistema.
3. Save v2: un solo bump en S0; cada fase añade SU clave con default en `migrate()`.
4. Fauna sin navmesh ni física: steering + `TerrainData.get_height` + chequeos escalonados (`tick % 5`).
5. `CitizenVisual.setup()` no es idempotente: nunca regenerar ropa de vivos; los cambios de era visten solo a los recién llegados.

## Fases

### S0 — Fundación multi-aldea (el trabajo caro e invisible)
- `BandPlacer`: al empezar, el jugador reparte N colonos (slider 6–16 en el menú, por defecto 10) en bandas por clic; ghost anillo verde/rojo; validación mínima (tierra, no agua, pendiente <22°); rueda ajusta el grupo; dispersión ≥2,5 m; radio de exclusión entre campamentos 12 m (ghost rojo, sin fusiones). Al terminar: UN solo bake de navmesh y el sim arranca.
- `CampEntity` (kind `camp`, grupos `campfire`+`storage` reutilizados): hoguera pequeña + montón de suministros por banda, con los números de colisión/RVO ya conquistados (cilindro 1,35 / obstáculo 1,0).
- **Barrido «mi hoguera»**: grep exhaustivo de `fires[0]`, `get_nodes_in_group(&"storage")[0]` y equivalentes (~10 sitios: audio_director, morale, rest_spot, find_storage, state_return/eat/rest, haul_dispatcher, settler_arrivals, day_night multi-luz, milestones) → `Citizen.home_camp()` / `CampGen.nearest_campfire()`.
- El mapa base queda 100 % naturaleza. `--autoplace` (4+4+2 fijo) para tests, sonda y `--newgame`.
- Puerta: suite + soak 20 min con 3 bandas vivas (comen, descansan, acarrean a SU campamento) + smoke release.

### S1 — Mapa 2.0 y gráficos base (la mayor inversión visual por hora)
- Biomas por ruido de dominio con fronteras suaves: Pradera, Bosque Umbrío, Ribera de Juncos, Colinas de Piedra + Claro Florido raro (0–1). Densidades de árbol/roca contrastadas y agua consultable — la variedad que las culturas necesitarán.
- Terreno 2.0: albedo por ruido, roca en pendiente, orilla húmeda con máscara real de río, **sombras de nubes** scrolleadas por el viento (en vez de sky shader: la cámara pica 48–55° y no ve el cielo).
- Agua viva (olas, espuma por profundidad, hielo en invierno), hierba instanciada (MultiMesh, 1 draw call), viento en vertex shader.
- `PaletteData` crece con las rampas por bioma de ART_DIRECTION_003.
- Puerta: captura por bioma × estación, 60 fps en desktop, suite + smoke.

### S2 — Rasgos y oficios (con auto-tala: el pilar que faltaba)
- 5 atributos (fuerza, destreza, percepción, mano verde, diligencia) + 5-6 rasgos con efecto visible (glotón, frugal, cazador nato, recolector, solitario/gregario). Panel de info los muestra. Save: clave `traits`.
- Autoselección de oficio: IA de utilidad (necesidad de aldea × aptitud × preferencia) como pesos retrocompatibles sobre `best_task_for`; reevaluación estacional; leñador/constructor/agricultor/recolector-base.
- **Auto-tala**: los leñadores marcan árboles solos según el stock de madera objetivo; la T del jugador pasa a sugerencia (prioridad más débil = número mayor). Sin esto no hay madera autónoma y S6 sería letra muerta.
- Puerta: soak 1 año con reparto de oficios estable (flapping ≤1 cambio/colono/estación) y madera fluyendo sin tocar T.

### S3 — Caminos emergentes + ambiente vivo
- `TrafficGrid` (celda 1 m, pisadas desde el gancho existente de citizen, decaimiento estacional) → senda de tierra en el shader. **Rehacer el tuning sobre papel primero** (los números del diseño no producían senda visible). Sin bonus de velocidad v1.
- Peces del río 100 % GPU, pájaros posados en rocas/tocones (no en árboles talables), luciérnagas de noche, hojas en otoño, niebla del amanecer.
- Puerta: tras 1 año de soak, las rutas diarias se VEN como sendas (captura), suite + smoke.

### S4 — El latido (que no aburra): rescoldos, crónica y tensión
- **Rescoldos**: recurso regenerable del espíritu. Verbos v1: **avivar** una hoguera (inspiración temporal, duración corregida en unidades de sim y pacto explícito con day_night) y **bendecir** a un aldeano (rasgo temporal). Susurrar y terreno sagrado/prohibido: FUERA (Build 004 — susurrar necesita la autoconstrucción; lo sagrado será ritual de los aldeanos, no brocha del dios).
- **HearthFire**: la hoguera consume leña; racionar o avivar es UNA decisión real del jugador; hoguera apagada = crisis (moral, lobos futuros). Economía de rescoldos simulada en papel ANTES de codificar.
- **Crónica del pueblo**: diario generado (nacimientos, bodas, inventos, crisis; cap 200 entradas, sin resumen anual). Es el registro donde escribirán todos los sistemas siguientes.
- **Director de tensión** (WorldEvents 2.0): invierno duro, fiebre leve, hoguera apagada — anunciar → responder → crónica. + 4 peticiones de ancianos con rescoldo de recompensa.
- Puerta: un año entero anuncia/responde/registra sin toasts huérfanos; suite + smoke.

### S5 — Culturas del Fuego v1
- `CultureData` **congelada en génesis** (sin drift): ejes muestreados del bioma real de la hoguera + rasgos fundadores → endónimo, paleta de ropa (Río/Bosque/Piedra de ART_DIRECTION), plato típico, tabú, rito nocturno.
- Tótem y estandarte procedurales (gramática de formas por semilla cultural).
- Música con acento: 3 loops modales + `pitch_scale` por cultura (la matriz completa, Build 004).
- Panel de cultura (símbolo + endónimo + tarjetas + combustible visible) y la crónica pasa a hablar «en voz del fuego».
- Puerta: 3 bandas en 3 biomas → 3 identidades distinguibles A SIMPLE VISTA (capturas comparadas); suite + smoke.

### S6 — Fauna y caza
- Conejo PRIMERO (valida núcleo steering/director/despawn con arte mínimo), luego ciervo con manadas y balanceo por fase.
- Caza **rediseñada sobre papel** antes de codificar (la tríada huida-tirada-carne del diseño era incoherente): cazador nato como 5º oficio, carne al pipeline de acarreo.
- Arbustos de bayas persistentes (patrón TreeEntity) + recolección con gameplay.
- Puerta: soak 1 año — caza ≥30 % de la comida invernal, ninguna persecución >30 s, poblaciones estables.

### S7 — Autoconstrucción (el corazón del pitch)
- `PlotValidator` extraído de tool_manager (geometría+solape, SIN acceso) + `HomePlanner`: cuándo (vínculo/pareja, sin cama, madera objetivo) y dónde (scoring: llano, cerca de SU hoguera, no pegado, cerca de recursos) decide construir cada aldeano; la obra entra al TaskBoard/ConstructionSite existentes.
- Retirada REAL de R/H del jugador. Camas con dueño (reserva).
- Puerta: soak 2 años — 10 colonos sembrados levantan ≥4 casas solos en sitios razonables, cero intervención.

### S8 — Eras y clímax
- `EraController`: pieles → madera → piedra por logros (población/edificios/comida); recetas por era (choza de pieles → cabaña → casa de piedra); ropa por era solo en recién llegados.
- Decoración emergente (rasgo creativo → tótem/banco cerca del centro de SU aldea; prioridad correcta: número ALTO).
- Lobos-como-evento: el círculo de luz de la hoguera es santuario absoluto; susto sin muerte, aullido posicional, crónica. (FSM completa de caza/raid: Build 004.)
- Puerta: soak 2 años alcanza era de madera con crónica coherente; suite + smoke.

### S9 — Cierre
- Balance con el feedback del probador, soak 40 min ×4 con 3 bandas, export, zip, página itch actualizada, BUILD_003_REPORT.md con guía del probador.

## Riesgos top-5

1. **Radio de explosión de S0** (todo asumía UNA fogata): mitigación — barrido con grep exhaustivo + helper único (`home_camp`/`nearest_campfire`) + soak de puerta específico.
2. **Saves**: un solo bump v2 en S0, claves por sistema con default, slots 002 marcados en menú.
3. **Rendimiento fauna/hierba**: contrato del punto 4 + presupuesto <0,5 ms/tick para 40 animales; medir en la puerta de S6.
4. **Tuning "emergente" que no emerge** (caminos, rescoldos, caza): simular en papel antes del soak — regla nueva de la build.
5. **Jugabilidad continua**: R/H no se retiran hasta S7 verde; cada fase se entrega jugable y visiblemente mejor.

## Fuera de alcance (Build 004)

Puertos y barcos · guerra o daño · encuentros culturales completos (préstamo,
rivalidad, emisarios — v1 solo «vieron humo al otro lado del arroyo») · drift
cultural · economía por aldea · susurrar ideas · terreno sagrado · diales de
prioridad globales · RAID de lobos · matriz musical completa.
