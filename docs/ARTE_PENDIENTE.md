# Encargos de arte pendientes (para el agente visual)

## ⚠️ AVISO (2026-07-17 ~13h): 2 tests rojos con tu world_gen en curso
- `test_map_generator::test_river_network_exists` — «el cauce se hunde
  bajo el nivel del agua en 240,-48»: el tallado del río no llega a
  fondo en ese punto con tu altura nueva (¿altiplano/duna pisando el
  carve? El carve del río debe aplicarse DESPUÉS de todo relieve).
- `test_construction` — 2 maderas descuadradas: probablemente el mismo
  height alterado recoloca árboles/rutas del test. Con tu tanda cerrada,
  re-corre la suite entera antes de commitear.
(La flora lejana unificada — FarFlora con hierba — es del otro agente y
está verde con test_band_placer; no toca altura ni economía.)

## ACANTILADOS (orden del dueño 2026-07-17, «glow up» del relieve)
Farallones costeros y cortados de meseta — tú tienes world_gen.gd
caliente, lo dejo diseñado para que no choquemos:
- Ruido `_cliff_noise` (seed+515, freq ~0.002): decide QUÉ tramos de
  costa son farallón (>0.3) y cuáles playa (el resto, como hoy).
- En `height()`: donde `sea_mask` sube Y `_cliff_noise` manda, NO fundir
  el terreno hacia el fondo con smoothstep(0.3, 0.85): usar una banda
  DURA (p. ej. smoothstep(0.55, 0.68)) y mantener la altura base +2..5 m
  hasta el borde → caída vertical al mar. Rocas de PropGen en la base.
- Cortados interiores: en el borde de los altiplanos (h>9) un ruido fino
  puede escalonar la caída (terrazas de 2-3 m) en vez de rampa.
- OJO navmesh: agent_max_slope 42° — el farallón debe ser >60° para que
  NADIE lo navegue; los mojones/bloqueadores de agua ya cubren el resto.
- El clima por punto sigue en `snow_weight/arid_weight/climate_tint`.

## Ropajes por clima (HECHO por el agente de sistemas — contexto)
CitizenVisual._apply_climate_gear: gorro+capa de pieles (frío, tiers
1-2), paño de lino (cálido). Si quieres remodelarlos en Blender, los
nodos se llaman FurCap/FurCape/SunWrap (hijos de Head/Torso).

Coordinación entre agentes — Build 004, biomas nuevos (2026-07-17):

- **Flora de TUNDRA (Biome.NIEVE)**: hoy usa los pinos del MegaKit con el
  seed sesgado (`TreeGen.seed_for_pines`). Ideal: variante de abeto
  nevado / abedul y algún prop helado (rocas con nieve, matorral seco).
- **Flora de SABANA (Biome.SABANA)**: hoy reduce densidad y concentra los
  árboles comunes junto al agua (oasis, `terrain_chunk.populate`).
  Ideal: ACACIA de copa plana para la llanura y PALMERA + juncos para
  los oasis; algún prop de hueso/termitero/roca arenisca.
- Punto de enganche: `terrain_chunk.populate` decide qué prop por bioma
  (`which == WorldGen.Biome.NIEVE / SABANA`); TreeGen elige el modelo.
  El clima por punto: `world_gen.snow_weight/arid_weight/climate_tint`.
