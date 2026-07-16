# BUILD 004 — «Camino al Mercado» · Informe de ejecución

> Una entrada por fase: qué se hizo, qué se verificó, cómo, y qué quedó fuera.

---

## M0 — Arreglos previos (2026-07-16) ✅

**Estado de partida verificado**: suite verde (88→92 métodos tras M0, 0 fallos)
con `godot --headless --path . -s tests/run_tests.gd`.

### 1. Consulta de navegación antes de la sincronización — ARREGLADO
- `NavUtil.map_ready(map)` nuevo: `map_get_iteration_id(map) != 0`.
- Guard aplicado en TODAS las rutas que tocaban el NavigationServer en
  frames tempranos: `NavUtil.is_reachable/is_practical`, `Citizen.rest_spot`
  (fallback junto al fuego), `move_to_near` (objetivo directo),
  `_force_unstick`, `is_stranded_from_home`, `_rescue_home`, `_hop_home`,
  `_decongest_point`, `SettlerArrivals._safe_spawn_point`,
  `StateRecover.enter/_side_step`.
- Test de regresión: `tests/unit/test_nav_ready.gd` (3 métodos) — fuerza las
  rutas en frame 0 y comprueba los fallbacks.
- Verificado: el `ERROR: NavigationServer navigation map query failed…` ya
  NO aparece en la suite ni en el humo (logs `hf_m0_b..j`).

### 2. Edge errors del navmesh — ARREGLADO (0 en consola)
- Diagnóstico con bisección por fichero (filtro nuevo `HF_TEST_FILTER` del
  runner): los `7 edge error(s)` salían SOLO del mundo semilla 4444
  (`test_auto_wood`) — laderas del relieve nuevo rasterizadas a celda 0.3.
- Arreglo real: celda XY del bake 0.3→0.4 con `agent_radius` 0.4 (múltiplo
  exacto; 0.8 rozaba el campamento y mutaba los errores, 0.6 perdía
  precisión y lo cantaba en consola). Bonus: tiras fusionadas en los
  bloqueadores de agua (menos cajas coplanares) y 2 frames de respiro entre
  ficheros del runner (la región del mundo anterior se retira antes del
  siguiente bake).
- Verificado: suite completa con **0 apariciones** de `edge error` (log
  `hf_m0_i/j`), y suite verde (las rutas siguen funcionando con celda 0.4).

### 3. Test de transporte intermitente — ARREGLADO (20/20)
- `test_haul_flow` hecho determinista: fundadores con herramientas (el
  crafteo de S2 no le roba ventana), ventana 4200→6400, y el registro de
  items se espera como CONDICIÓN (300 frames de settle) en vez de instante.
- **20 corridas seguidas: 20/20 OK** (`run1..run20=OK`, log en `%TEMP%\hf_h20_*`).

### 4. RID/ObjectDB leaks del runner — ARREGLADO (RID limpio)
- `ResourceJanitor.release_static_caches()` (nuevo): suelta los caches
  estáticos de materiales/meshes (MeshLib, TreeGen, PropGen, TerrainChunk,
  MapGenerator, TreeEntity outlines, configs singleton).
- `AudioDirector.shutdown()` (nuevo): mata el tween de música (con captura
  blindada), desconecta señales, para y libera todos los reproductores y
  vacía el cache de streams. El runner lo llama y drena 5 frames + 150 ms.
- Verificado: **0 `RID leaked`**, 0 `resources still in use`; quedan
  4 ObjectDB efímeros estables (2 MeshInstance3D sin ruta + 2 materiales,
  ver LIMITATIONS.md) — sin fuga acumulativa en runtime.

**Puerta M0**: gdformat/gdlint 0 quejas · suite `RESULTADO: OK` (92 métodos,
1454+ comprobaciones) · humo release 2/2 vivos · consola de la suite SIN los
errores/warnings de §2.

---

## HOTFIX — Pantalla de siembra a oscuras (2026-07-16) ✅

**Encargo**: la pantalla de reparto de bandas quedó casi negra tras V1
(luminancia medida 56/255, RGB ≈ 29,67,28). Objetivo: plena luz SIEMPRE en
la siembra, luminancia ≥150/255 en `s1_pantalla_siembra.png`, sin tocar el
`BandPlacer` y sin romper la «hora dorada eterna» del juego en marcha.

### Diagnóstico (la hipótesis de la orden no era la causa)
1. Vía A aplicada primero (mediodía t=0.40 congelado): la luminancia apenas
   se movió, 56→51.5. La hora NO era la causa.
2. Sonda de diagnóstico: en el frame de la captura el sol estaba a energía
   1.196, ambiente 1.0, volumétrica apagada — la escena estaba BIEN
   iluminada y aun así salía negra. Algo la tapaba.
3. Bisección visual (capturas apagando elementos por turnos):
   - sin sombras del sol → luminancia 152 ✔
   - sin falda de horizonte (con sombras) → 152 ✔
   - todo puesto → 51 ✘
   **Causa real**: la vista de águila (≈460 m de altura) queda entera FUERA
   del alcance de sombras del sol que fijó V1 (`PSSM 4 splits, max 240 m`);
   el disco de la falda de horizonte (r=1100 m), aplastado («pancaked») en
   el mapa de sombras, enterraba todo el valle en una sombra falsa.

### Arreglo (quirúrgico, solo `world.gd`)
- Rama de siembra de `world._ready`: `SimClock.reset(1, 0.40)` + PAUSED
  (mediodía limpio congelado, entre por donde entre: menú, sonda o test) y
  `_sun.shadow_enabled = false` SOLO durante la siembra.
- `EventBus.placement_finished` (ONE_SHOT) → `_restore_sun_shadow()`: al
  confirmar el reparto vuelven las sombras y arranca el ciclo del día.
  El `BandPlacer` no se ha tocado; la dirección de arte del juego en marcha
  queda intacta (el cambio muere al terminar la siembra).

### Verificación
- Captura regenerada con `tools/dev_probe_placement.gd`:
  **luminancia media 151.0/255** (objetivo ≥150; antes 56). Terreno
  iluminado, panel y etiqueta de bioma/validez del cursor legibles
  (comprobado con capturas adicionales con el cursor warpeado).
- El anillo es material UNSHADED: su contraste sobre el fondo claro es el
  mismo que en la era pre-V1 (cuando la pantalla clara no daba quejas).
- gdformat/gdlint 0 quejas · suite `RESULTADO: OK` (92 métodos, 1454
  comprobaciones; una corrida intermedia dio 1 fallo puntual en
  `test_construction` que pasa aislado y en la repetición completa —
  flaky serial conocido, no relacionado: el hotfix no toca economía)
  · humo release 2/2 vivos · export re-generado.

### Hallazgos anotados (fuera del alcance del hotfix, ver LIMITATIONS)
- La MISMA sombra falsa puede aparecer en la vista de águila del juego en
  marcha (botón Águila) con el sol alto — mismo mecanismo. Plan: M2/V5.
- En mapas SEA, el agua apenas contrasta con la pradera desde el águila
  (color/alpha del shader se funden a 460 m). Plan: V2/V3.
