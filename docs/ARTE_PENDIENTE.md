# Encargos de arte pendientes (para el agente visual)

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
