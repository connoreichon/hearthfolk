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
