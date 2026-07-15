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

### S1 — MAPA GIGANTE por chunks + biomas + gráficos base
**Orden del dueño (2026-07-15)**: el mapa de 120 m es de juguete — las bandas
se ven entre sí nada más sembrar. El mapa pasa a ser GIGANTE y procedural
para que los asentamientos tarden años en crecer hasta encontrarse (salvo
que el jugador los siembre cerca a propósito).
- **Escala**: objetivo Build 003 ≈ **1×1 km** (16×16 chunks de 64 m; ~70×
  el área actual), con la arquitectura preparada para crecer más:
  - Terreno por CHUNKS (malla + colisión + navmesh region POR chunk,
    horneado asíncrono y solo cerca de actividad; regiones conectadas).
  - Props por chunk (Poisson local con densidad por bioma); streaming
    visual simple por distancia a cámara (los chunks lejanos, LOD plano).
  - `TerrainData` global por función (altura/pendiente puras por ruido,
    sin array monolítico), máscara de sendas por chunk.
  - Cámara: límites del mapa desde config; zoom máximo más alto + (S4+)
    minimapa para orientarse.
- Biomas por ruido de dominio con fronteras suaves: Pradera, Bosque Umbrío, Ribera de Juncos, Colinas de Piedra + Claros Floridos raros. Red de ríos en vez del arroyo único del borde. Densidades de árbol/roca contrastadas y agua consultable.
- Terreno 2.0: albedo por ruido, roca en pendiente, orilla húmeda, **sombras de nubes** scrolleadas por el viento.
- Agua viva (olas, espuma, hielo en invierno), hierba instanciada cerca de cámara, viento en vertex shader.
- `PaletteData` crece con las rampas por bioma de ART_DIRECTION_003.
- Puerta: 10 colonos sembrados en 3 puntos MUY separados (500+ m) conviven un soak de 20 min con 60 fps en desktop y sin fugas de memoria; captura por bioma × estación; suite + smoke.

### S2 — Rasgos y oficios (con auto-tala: el pilar que faltaba)
- 5 atributos (fuerza, destreza, percepción, mano verde, diligencia) + rasgos con efecto visible, INCLUYENDO DEFECTOS de nacimiento (orden del dueño): cada colono nace con al menos una virtud y probablemente un defecto (p. ej. manos de madera → carpintero nato pero torpe con el arma). Panel de info los muestra con lenguaje evocador, no números pelados. Save: clave `traits`.
- **Catálogo GRANDE y creciente** (orden del dueño 2026-07-15): la v1 activa ~10-12 rasgos con mecánica real, pero el catálogo se define amplio desde el día uno y cada build activa más. Cada rasgo lleva `hereditary: bool` DESDE YA: cuando lleguen las familias (Build 004), los hijos heredarán rasgos de sus padres con mutación ocasional — la genética se enchufa sin migrar datos.
- El catálogo de habilidades es EXTENSIBLE por diseño: los oficios futuros (marinero con «buena mano al timón», pastor, pescador, panadero, cantero…) se enchufan añadiendo aptitudes al catálogo sin tocar la IA de utilidad. Objetivo de saga: MUCHOS oficios — cada build suma.
- **La demanda manda** (orden del dueño 2026-07-16): los oficios NO son cupos de uno — si la aldea necesita mucha leña, habrá VARIOS leñadores a la vez; la IA de utilidad asigna por necesidad × aptitud, y reequilibra cuando la necesidad cambia.
- **Infraestructura autoconstruida** (adelantada de S7 por orden del dueño): la aldea levanta SU HUERTO sola cuando la comida aprieta (el agricultor elige parcela llana en el territorio) y SU ALMACÉN cuando el montón de suministros se queda corto — con la misma maquinaria de obras existente. Las casas siguen en S7.
- **Verlo todo**: el oficio de cada colono visible al seleccionarlo y resumen de oficios por aldea en el panel Aldeas («2 leñadores · 1 agricultor · 1 constructor»).
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
- **Hoja de ruta de fauna** (orden del dueño 2026-07-15): tres familias con núcleo común — PRESAS (conejo, ciervo; jabalí que se defiende), PELIGROSA (lobos S8; oso en 004), y **DOMESTICABLE** (Build 004: gallinas/cabras/ovejas capturables → corral + pastor como oficio → huevos/leche/lana). El núcleo AnimalEntity se diseña ya con las tres familias en mente.
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

## Territorios del Hogar (orden del dueño 2026-07-15: «¿de quién es el árbol?»)

Cada campamento irradia un TERRITORIO desde su hoguera. Regla simple y
sólida: un punto pertenece al asentamiento cuya hoguera esté más cerca,
SI además cae dentro de su radio de influencia — y el radio crece con el
rango (Campamento ~30 m → Aldea → Pueblo → Villa → Ciudad).

- **Los recursos del territorio son SUYOS**: los leñadores solo talan árboles
  de su territorio (S2), las casas y huertos se levantan dentro (S7), y los
  cazadores no persiguen presas hasta el territorio ajeno. Crecer de rango
  ensancha la frontera → más árboles y tierra → LA razón para prosperar.
- **Frontera visible y bonita**: mojones de piedra procedurales con la marca
  cultural del asentamiento (S5: el símbolo del tótem grabado), espaciados
  por el arco de frontera; al seleccionar una hoguera, el territorio se
  ilumina con un tinte suave del color de su cultura sobre el terreno.
- **La siembra manda**: en el mapa gigante la exclusión entre bandas sube
  (aviso en rojo bajo ~120 m), pero sembrar cerca SIGUE PERMITIDO con
  Mayús — el hacinamiento es una elección del jugador, con sus tensiones.
- **El destino**: cuando dos territorios crecidos se tocan, la frontera se
  disputa — préstamo cultural, alianza… o guerra por recursos (Build 005).
- Implementación: por distancia+radio (sin grid pesado); `territory_of(point)`
  en CampEntity; radios en SimConfig por rango; los sistemas consultan, no
  cachean. Fase: núcleo+mojones en S1 (con el mapa), consumo real en S2/S7.

## Salto visual (orden del dueño 2026-07-16: «me parece bastante cutre»)

Dos vías en paralelo, decidiendo con capturas lado a lado:
1. **Luz y atmósfera** (barato, gran salto de sensación): pasada de
   iluminación — tonemapping y exposición afinados, SSAO/glow calibrados,
   niebla de distancia suave, sombras más ricas al amanecer/atardecer.
2. **Assets CC0** (el dueño autorizó descargas): evaluar packs libres tipo
   Kenney/Quaternius para lo que peor sale por código — árboles, edificios
   y (en S6) animales — manteniendo la paleta canon por tinte de material.
   Decisión final comparando capturas antes/después con el dueño.
Físicas: pulido de sensación de movimiento (aceleración/frenado de
colonos, empujones RVO más suaves) — no hay física dura que mejorar en
un juego de dioses de maqueta.

## Agua, fronteras y descubrimientos (orden del dueño 2026-07-15)

- **El agua profunda NO se cruza**: el cauce de los ríos queda excluido de
  la navegación (bloqueadores de horneado sobre las celdas de agua, por
  chunk). Los ríos son fronteras de verdad: rodear… o progresar.
- **Descubrimientos**: la tecnología llega de forma orgánica, empujada por
  la necesidad. El primero de la saga: **EL PUENTE** — cuando un
  asentamiento en era de madera acumula leña y sus caminos chocan una y
  otra vez contra el río, a alguien se le ocurre (rasgo creativo + crónica
  + hito): tramo de puente construible sobre agua que une las dos orillas
  y rehornea la navegación. (S8 si la era de madera llega a tiempo;
  si no, primera pieza de la Build 004.) Después vendrán más
  descubrimientos con el mismo patrón: necesidad repetida + creatividad.
- **Paseo forrajero**: el ocio no es vagar — es explorar los alrededores
  del campamento BUSCANDO recursos (sesgo del paseo hacia árboles, bayas
  y setas del territorio; lo que encuentran alimenta la auto-asignación).

## Progresión de asentamiento (norte de la saga, orden del dueño 2026-07-15)

La escalera que guía TODAS las builds futuras, época medieval:
**Campamento** (hoguera) → **Aldea** (primeras casas) → **Pueblo** (pozo,
oficios, decoración) → **Villa** (mercado, murete, caminos consolidados) →
**Ciudad** (castillo, murallas, puerto si hay costa, comercio). El nombre del
asentamiento y su rango se muestran y se celebran (hito + crónica). Crecer
cuesta AÑOS: cuando dos asentamientos crecidos se encuentran, **se alían o
guerrean** (Build 005+) — la distancia a la que el jugador sembró las bandas
al principio decide cuánto tarda ese destino.

## Fuera de alcance (builds futuras)

Build 004: puertos y barcos · encuentros culturales completos (préstamo,
rivalidad, emisarios) · drift cultural · economía por aldea · susurrar ideas
· terreno sagrado · diales de prioridad · RAID de lobos · matriz musical
completa · rangos Villa/Ciudad con murallas y castillos.
Build 005+: guerra y alianzas entre ciudades · comercio entre asentamientos.
