# HEARTHFOLK — BUILD 004: «CAMINO AL MERCADO»

## Orden de producción — de prototipo sólido a producto vendible

---

# 0. CONTEXTO (LÉELO, ES REAL)

Este proyecto ya existe y está sano. Un revisor externo clonó el repositorio, descargó Godot 4.7, importó el proyecto y **ejecutó la suite completa de tests: 88 métodos, 1.452 comprobaciones, 0 fallos**. La arquitectura del contrato técnico (tick de simulación a 20 Hz, `TaskBoard` atómico, `EntityRegistry` con IDs estables, `IPersistent`, 100 % procedural) está respetada y funciona. Ya hay estaciones, agricultura, moral, llegadas de colonos, eventos, multi-campamento, oficios, fauna ambiental y caminos emergentes. El apartado visual ya tiene tonemap AgX, SSAO, glow, niebla de distancia, cielo procedural y ciclo día/noche con gradientes.

**Tu misión NO es rehacer nada de eso.** Tu misión es cerrar la distancia entre «prototipo técnicamente impresionante» y «juego que un desconocido compra, entiende en 3 minutos y no quiere cerrar». Esa distancia es de **game feel, identidad visual, gancho de juego, onboarding y rendimiento a escala**, no de fontanería.

Trabaja sobre el estado actual del repo. Antes de tocar nada, ejecuta y confirma que la suite sigue verde.

---

# 1. CONTRATO DE TRABAJO (idéntico al de siempre)

## 1.1 Autonomía total
* **No hagas preguntas.** Si algo es ambiguo, decide, aplica la opción más robusta y anótalo en `docs/DECISIONS.md`.
* No pidas confirmación entre fases. Continúa.
* Yo doy ideas vagas; **tú las conviertes en decisiones concretas y las ejecutas a fondo**. Cuando yo diga «que se vea mejor» o «que tenga más vida», tradúcelo tú a números, materiales, curvas y criterios medibles, y hazlo. No me devuelvas la pelota.

## 1.2 Permisos de entorno (TIENES VÍA LIBRE)
Tienes permiso explícito para **descargar, instalar y ejecutar** en esta máquina todo lo que necesites: Godot 4.7 stable + export templates de la versión exacta, Python 3.11+ con `numpy`/`scipy`/`pillow`, `gdtoolkit` (`gdformat`/`gdlint`), `git`, y cualquier CLI (`ffmpeg`, `7z`, `winget`, `scoop`) que te facilite el trabajo. Verifica cada instalación ejecutando su versión antes de seguir. Trabaja en la carpeta del proyecto en el Escritorio y haz push a `https://github.com/connoreichon/hearthfolk.git` al cerrar cada fase (si el push falla por auth, sigue en local y deja el comando en el informe; no intentes autenticarte tú).

## 1.3 Reglas absolutas (innegociables)
1. **Prohibido simular trabajo.** Nada de `# TODO` ni funciones vacías dentro del alcance. Si está en el alcance, se implementa, se ejecuta y se verifica.
2. **Prohibido afirmar que algo funciona sin haberlo ejecutado.** Cada «hecho» va respaldado por un comando y su salida.
3. **Prohibido `Engine.time_scale`** (rompe la nav a ×4; ya está resuelto con el tick fijo, no lo rompas).
4. **Prohibido tocar la arquitectura del contrato técnico.** Extiéndela, no la sustituyas.
5. **Prohibido meter assets de terceros con licencia dudosa.** Todo procedural o CC0/dominio público documentado en `docs/LICENSES.md`.
6. Todo GDScript **tipado** (ya está `untyped_declaration=2`; que siga en 0 warnings).
7. Si algo no llega a funcionar, **no lo escondas**: `docs/LIMITATIONS.md` con estado real, motivo y plan. Prefiero una limitación honesta a una mentira.

## 1.4 Puerta de calidad por fase (OBLIGATORIA)
Ninguna fase (M0…M8) se cierra sin, en este orden:
```
1. gdformat . && gdlint .                                   → 0 quejas
2. godot --headless --path . -s tests/run_tests.gd          → RESULTADO: OK
3. tools/release_smoke.ps1 (o su equivalente headless)      → OK
4. Captura(s) de pantalla del cambio en docs/screenshots/   → evidencia visual
5. git commit -m "M<n>: <resumen>"  +  entrada en CHANGELOG.md
6. Entrada en BUILD_004_REPORT.md: qué hiciste, qué verificaste, cómo, qué quedó fuera.
```
Una fase con la consola escupiendo errores **no está terminada**, por bonita que se vea.

---

# 2. ARREGLOS PREVIOS (M0 — antes de añadir nada)

El revisor encontró esto **ejecutando el juego**. Arréglalo primero, con test de regresión cada uno:

1. **Consulta de navegación antes de la sincronización del mapa.**
   `scripts/ai/citizen.gd`, función `rest_spot()` (~línea 400): llama a `NavigationServer3D.map_get_closest_point(map, spot)` cuando el mapa de navegación todavía no ha hecho su primera sincronización, lo que dispara `ERROR: NavigationServer navigation map query failed because it was made before first map synchronization`.
   * Arreglo: antes de cualquier query, comprueba `NavigationServer3D.map_get_iteration_id(map) != 0` (o conecta a `map_changed` una vez y cachea el estado listo en un flag global, p. ej. en `TrafficGrid` o un pequeño `NavReady` helper). Si el mapa no está listo, devuelve un fallback seguro (`global_position`) sin lanzar la query. Aplica el mismo guard a **todas** las llamadas a `map_get_closest_point` / `is_reachable` que puedan ocurrir en los primeros frames o en contexto de test.
   * Test: un caso que instancie un habitante y fuerce `Rest` en el frame 0 sin que aparezca el error en consola.

2. **Errores de aristas del navmesh al hornear.**
   El horneado suelta `Navigation region synchronization had 7 edge error(s). More than 2 edges tried to occupy the same map rasterization space`. Geometría demasiado densa/solapada.
   * Arreglo: sube `navigation/3d/merge_rasterizer_cell_scale` o el `cell_size` del bake, y/o simplifica la geometría de colisión que se hornea (los props estáticos no necesitan malla de colisión detallada para el navmesh — usa cajas de colisión simples para el bake). Objetivo: **0 edge errors** en el log de un arranque limpio y del soak.
   * Test: hornear el mapa base y afirmar 0 warnings de edge merge (captura el log y busca la cadena; que no aparezca).

3. **Test de transporte intermitente (1/3).**
   El informe 002 reconoce que un test de transporte falla ~1 de cada 3 corridas por una carrera de tiempos del RVO. Un test *flaky* es un test roto.
   * Arreglo: haz el test determinista (fija semilla, avanza por ticks contados en vez de por tiempo real, o espera a una condición explícita en vez de a un número de frames). Córrelo **20 veces seguidas** y que pase las 20. Documenta en `BUILD_004_REPORT.md` las 20 salidas.

4. **`RID leaked at exit` en el runner de tests.**
   Limpieza fina: libera los recursos estáticos/cacheados (materiales, meshes generados) en el `quit()` del runner o marca su liberación. Objetivo: runner que sale sin warnings de RID.

M0 no cierra hasta que el arranque limpio del juego y el soak salgan **sin un solo `ERROR`/`WARNING` de los de arriba** en consola.

---

# 3. LA IDEA CENTRAL DEL RESTO DE LA BUILD

El juego hoy es un **sandbox precioso sin arco**. Se puede mirar, pero no hay una razón para *seguir* mirando ni un momento en el que el jugador diga «¡sí!». Un producto vendible necesita: un **gancho** en los primeros 3 minutos, **tensión y alivio** en bucle, **momentos que se celebran solos**, y una **identidad visual** que se reconozca en una miniatura. Todo lo que sigue sirve a eso.

Traduce cada objetivo «blando» a algo medible. Cuando yo escribo «que tenga alma», tú entregas: paleta afinada con números, curva de luz, partículas, sonido reactivo, y una captura que lo demuestre.

---

# 4. FASES

## M1 — GAME FEEL / JUGOSIDAD (lo que más se nota por poco esfuerzo)

Objetivo medible: que **cada acción del jugador y cada hito del mundo tenga respuesta audiovisual en < 100 ms**. Nada debe ocurrir en silencio.

* **Cámara con vida**: micro-shake al talar/caer árbol (amplitud ≤ 0.15 m, decae en 0.25 s), suavizado de zoom y rotación con `1 - exp(-k·dt)` (ya usado; audítalo y aplícalo en todo movimiento de cámara), ligero *ease* al centrar con `F` y doble clic.
* **Feedback de selección**: al seleccionar habitante/obra/árbol, contorno con *pulse* sutil (brillo senoidal 0.5 Hz), y una línea punteada animada hacia su destino (offset del dash con el tiempo).
* **Juice de tala y construcción**: *squash & stretch* en el impacto (ya hay algo; súbelo a que se lea claramente), astillas que rebotan y se desvanecen, *pop* de escala en cada pieza colocada (0.85→1.0 con un pequeño *overshoot* elástico), anillo de polvo en el suelo al caer un árbol.
* **Números/toasts con carácter**: cuando entra madera al almacén, un `+2` diminuto que sube y se desvanece sobre el carro. Cuando se termina una casa, un pequeño destello cálido + partículas + un *stinger* de audio de 1.5 s. Cuando llega un colono, ídem con su propio *stinger*.
* **Curva de sonido reactiva**: el volumen del ambiente de trabajo escala con cuánta gente trabaja; el fuego suena más fuerte de noche; al pausar, el mundo se «apaga» suavemente (low-pass filter en el bus Master, no corte seco).
* **Hover en todo lo interactivo**: cualquier cosa clicable resalta al pasar el ratón, sin excepción.

Criterio de aceptación: graba (o capturas en secuencia) el bucle talar→caer→recoger→entregar→construir→terminar y verifica que **cada** transición tiene sonido + partícula + respuesta visual. Lista en `BUILD_004_REPORT.md` los 12+ puntos de feedback añadidos.

## M2 — IDENTIDAD VISUAL (que se reconozca en una miniatura)

Objetivo medible: que una captura del juego sea distinguible de «otro sim genérico de Godot con SSAO». Ahora mismo es competente pero anónimo. Dale una firma.

* **Afina la paleta y el grading** hacia una dirección de arte con nombre propio (elige tú y documéntala en `docs/ART_DIRECTION_004.md`: p. ej. «acuarela cálida de atardecer perpetuo» o «diorama de fieltro»). Ajusta `adjustment_*`, `glow`, y los materiales base hacia esa dirección. **No** basta con subir saturación; define una relación luz-sombra coherente.
* **Contorno artístico opcional** (estilo ilustración): evalúa un outline sutil por post-proceso o por back-face en props y habitantes (color derivado del material, no negro puro). Si mejora la lectura de silueta, actívalo; si ensucia, no. Decide con capturas A/B en `docs/screenshots/`.
* **Cielo y luz de hora dorada**: refuerza el atardecer (la hora más «vendible») con un cielo más rico, rayos de sol (god rays baratos vía glow/quads), y sombras largas. La miniatura de la tienda saldrá de aquí.
* **Vegetación viva**: el shader de viento ya existe; súbele presencia (ondas coherentes por zonas, no ruido plano), y añade un leve *scatter* de partículas ambientales (polen de día, luciérnagas o brasas de noche) para densidad atmosférica.
* **Agua del arroyo**: hoy es un plano translúcido. Dale un shader con normal-scroll y un borde de espuma barato donde toca la orilla. Barato, pero vivo.
* **Sombra de personaje que sigue el terreno**: el blob actual es un quad plano; proyéctalo sobre la pendiente (decal o raycast de 3 puntos).

Criterio de aceptación: 4 capturas «de tienda» (amanecer, hora dorada, noche, vista de águila) en 1920×1080 que un humano usaría como material de marketing sin retocar. Antes/después de la paleta en el informe.

## M3 — EL GANCHO Y EL ARCO (por qué seguir jugando)

Objetivo medible: un jugador nuevo tiene un **objetivo claro a los 60 s**, una **primera victoria a los ~5 min**, y una **razón para el siguiente cuarto de hora**. Hoy no hay ninguna de las tres.

* **Onboarding real**: el `TutorialGuide` actual son 5 pistas de texto. Conviértelo en un arranque guiado orgánico: los primeros colonos ya sugieren su primera hoguera, aparece una pista contextual *solo* cuando hace falta, y la primera casa terminada dispara una pequeña celebración que confirma «esto es lo que hace el juego». Que nadie tenga que leer un manual.
* **Bucle de tensión/alivio con nombre**: formaliza el ritmo estación→despensa→invierno→supervivencia como el latido del juego. El invierno debe *sentirse* (paleta más fría ya existe; súbele presión con el ritmo de la despensa y un evento de helada telegrafiado con antelación para que el jugador pueda actuar). Alivio en primavera con repoblación y un *stinger* de renacimiento.
* **Hitos que importan y se celebran solos**: hay `milestones`; haz que sean visibles y satisfactorios (primera casa, primer colono nacido/llegado, primera cosecha, primer invierno superado, aldea de N habitantes, primer camino que emerge del suelo). Cada uno con toast especial, sonido y una línea de crónica.
* **La Crónica**: un pequeño registro narrativo (una línea por hito y por evento, con el nombre del colono implicado) accesible desde el HUD. Es lo que la gente comparte en redes. Persístelo en el guardado.
* **Progresión de eras** (si la visión de Build 003 lo tiene a medias): pieles → madera → piedra, aunque sea una versión mínima. Da la sensación de *avanzar*, no solo de *mantener*.

Criterio de aceptación: describe en el informe la experiencia minuto a minuto de una partida nueva (0–15 min) y demuestra con capturas que el objetivo, la primera victoria y el siguiente gancho aparecen en esos tiempos.

## M4 — PROFUNDIDAD DE DECISIÓN (para que no sea solo mirar)

Objetivo medible: que el jugador tenga **al menos 3 decisiones significativas** por partida temprana que cambien el resultado, sin romper la filosofía «no ordenas, avivas».

* **Peticiones y bendiciones** (del rol «espíritu del hogar» de la visión 003): el jugador puede *sugerir* prioridades (número de prioridad más alto que las de oficio, respetando que 0 = máxima en el TaskBoard), soplar brasas para acelerar una hoguera, o bendecir a un colono. Cada acción con coste/cooldown para que sea una decisión, no un botón spameable.
* **Escasez con dientes**: que quedarse sin comida o sin madera talable tenga consecuencia real y comunicada (moral baja, trabajo lento) pero nunca una espiral de muerte injusta. Telegrafía siempre antes de castigar.
* **Rasgos que se noten**: los `traits` existen; haz que un colono «perezoso» o «trabajador» cambie visiblemente el ritmo de la aldea y que el jugador lo perciba en el panel y en el comportamiento.

Criterio de aceptación: lista las decisiones, su coste, su efecto medible, y un test que verifique que una sugerencia del jugador reordena el trabajo sin saltarse la prioridad de supervivencia.

## M5 — RENDIMIENTO A ESCALA (el mapa de 1 km no puede ir a tirones)

Objetivo medible: **60 FPS estables** con el mapa grande y 3+ bandas vivas, en una máquina de gama media. La build 003 apunta a ~1×1 km por chunks; si no rinde, no se vende.

* Perfila con el mapa grande poblado. Ataca lo que salga: streaming de chunks por distancia, LOD plano para lo lejano, *pooling* de partículas e items, `MultiMeshInstance3D` para vegetación y props repetidos, horneado de navmesh asíncrono solo cerca de actividad.
* Presupuesto explícito: define un objetivo de draw calls y de nodos activos, mídelo en F3, y no lo superes.

Criterio de aceptación: soak de 20 min a ×4 en el mapa grande con **FPS medio ≥ 60 y percentil 1 % ≥ 45**, memoria estable (±10 % entre minuto 5 y 20), 0 atascos > 15 s, 0 leaks de entidades. Adjunta la traza de FPS.

## M6 — MÚSICA Y AMBIENTE SONORO (hoy omitida)

Objetivo medible: que el juego **suene a algo**, no a silencio con efectos.

* Pieza generativa por capas en `tools/gen_audio.py` (o síntesis en tiempo real con `AudioStreamGenerator`): un colchón cálido que cambia por estación y por momento del día (más luminoso de día, íntimo de noche, tenso en invierno). Nada de loops descargados: procedural y documentado.
* Mezcla: buses `Master → Music / Ambience / SFX / UI` (ya existen), *ducking* de la música cuando hay eventos importantes, límite de voces.

Criterio de aceptación: un ciclo día completo grabado (o descrito con marcas de tiempo) mostrando cómo evoluciona la capa musical. Sliders funcionando.

## M7 — PULIDO DE UI Y ACCESIBILIDAD

* Repasa el HUD para claridad a primera vista: jerarquía visual, iconos legibles, estados de habitante en lenguaje humano (ya lo hacen; audítalo).
* Opciones mínimas de accesibilidad: escalado de UI, opción de daltonismo para los estados de validación (verde/rojo → añade forma/patrón, no solo color), rebinding básico de teclas, volumen por bus.
* Menú de pausa y de opciones pulidos. Pantalla de créditos con las licencias.

Criterio de aceptación: recorre cada pantalla y verifica que se entiende sin explicación; captura de cada una.

## M8 — EMPAQUETADO PARA TIENDA (el último kilómetro)

Objetivo: que exista un `.exe` y un `.zip` que un desconocido descarga y juega, más el material de tienda.

* Export Windows verificado ejecutándolo (captura del menú y de una partida). `.zip` para itch.io.
* **Página de tienda** (`docs/STORE_PAGE.md`): título, tagline de una línea, descripción corta y larga, lista de features, 6–8 capturas seleccionadas de M2/M3, y un GIF de 5–10 s del bucle (genera los frames con la sonda de belleza y móntalos con `ffmpeg`). Redacta también los textos de itch.io y un borrador de descripción para Steam.
* **Checklist de lanzamiento** en `BUILD_004_REPORT.md`: build firmada/comprimida, tamaño, requisitos, controles, limitaciones honestas, y qué NO entra en esta versión.

---

# 5. CRITERIOS DE ACEPTACIÓN GLOBALES

La Build 004 solo es válida si, con evidencia ejecutada:

1. ☐ M0: arranque y soak **sin** los errores/warnings de §2 en consola.
2. ☐ Suite verde tras cada fase (métodos/checks/0 fallos anotados por fase).
3. ☐ El bucle completo del juego tiene feedback audiovisual en cada paso (M1).
4. ☐ 4 capturas «de tienda» que servirían de marketing sin retoque (M2).
5. ☐ Un jugador nuevo tiene objetivo a los 60 s, victoria a los ~5 min, gancho para el siguiente cuarto de hora (M3).
6. ☐ Al menos 3 decisiones significativas del jugador con efecto medible (M4).
7. ☐ 60 FPS medios / 45 en percentil 1 % en el mapa grande poblado (M5).
8. ☐ Música generativa por capas que evoluciona con día/estación (M6).
9. ☐ Todas las pantallas de UI claras + accesibilidad mínima (M7).
10. ☐ `.exe` + `.zip` + página de tienda + GIF del bucle (M8).
11. ☐ `docs/LIMITATIONS.md` actualizado, honesto, sin maquillar.

---

# 6. ENTREGA FINAL

En el repositorio, actualizados:

1. Proyecto completo que abre y juega sin tocar nada.
2. `build/Hearthfolk_004.exe` y `build/Hearthfolk_004_win64.zip`, verificados ejecutándolos.
3. `BUILD_004_REPORT.md`: checklist de §5 con comandos, salidas y capturas; experiencia minuto a minuto de una partida nueva; las 20 corridas del test antes-flaky.
4. `docs/ART_DIRECTION_004.md`, `docs/STORE_PAGE.md`, `CHANGELOG.md` (una entrada por fase M0…M8), `docs/DECISIONS.md`, `docs/LIMITATIONS.md`, `docs/BUGFIXES.md`.
5. `docs/screenshots/` con la evidencia de cada fase y las capturas de tienda + el GIF.

---

# 7. RECORDATORIO FINAL

* Yo doy ideas vagas; **tú entregas decisiones concretas, ejecutadas y verificadas**. No me devuelvas preguntas.
* No afirmes que algo funciona si no lo has ejecutado.
* No sustituyas un sistema por una explicación de cómo se haría.
* No rompas lo que ya funciona: la suite verde es tu red de seguridad; córrela sin parar.
* El objetivo de esta build no es «más features». Es que **un desconocido lo abra, lo entienda en 3 minutos, sienta algo, y no quiera cerrarlo**.

Empieza por **M0**. Confirma la suite verde. Ahora.
