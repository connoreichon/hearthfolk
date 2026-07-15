# S7 — Autoconstrucción: casas que crecen por niveles (diseño sobre papel)

> «Que los aldeanos hagan sus casas, que empiecen de una manera y poco a poco
> se mejoren hasta que se haga una ciudad; que haya casas a distintos niveles
> a la vez.» Corazón del pitch (orden del dueño).

## Niveles de casa (mejora in situ)

| Nivel | id | Aspecto | Coste | Camas | Desbloqueo |
|---|---|---|---|---|---|
| 1 | `choza` | Chamizo de palos, paredes bajas, techo de bálago | 4 madera | 1 | siempre (colono sin cama) |
| 2 | `cabana` | Cabaña de madera (cottage_a/b actuales) | +8 madera | 2 | aldea con ≥1 casa y stock |
| 3 | `casa_piedra` | Casa de piedra, chimenea, más alta | +14 madera | 3 | rango Pueblo+ y stock |

- **Construcción inicial** (nivel 1): los aldeanos la levantan con la maquinaria
  de obras existente (ConstructionSite, fases, tareas de suministro+construir).
- **Mejora de nivel**: una casa TERMINADA sube de nivel cuando la aldea puede
  permitírselo (rango + madera). La mejora consume madera y REGENERA la casa al
  aspecto del nivel siguiente con un floreo (pop + serrín + campanada). Así
  «poco a poco se mejora» sin rehacer la obra entera. Villager-driven en S8.
- **Conviven niveles**: cada casa mejora por su cuenta según su antigüedad y el
  stock del momento → una aldea tiene chozas nuevas junto a casas de piedra.

## Variedad y adaptación al terreno

- Variación procedural por semilla dentro de cada nivel (ventana, tejado,
  color de madera, banco, chimenea) — ya en CottageGen; se extiende por nivel.
- Emplazamiento: `_find_plot` (heredado de S2) puntúa llano, seco, en el
  territorio y con acceso practicable; la casa se orienta con la puerta hacia
  la hoguera. (Zócalos/pilotes en desnivel: cuando llegue el relieve fuerte.)

## HomePlanner (en CampEntity, junto a huerto/cobertizo)

Cadencia de planificación existente (1 comprobación por sim-tick lento):
1. **¿Falta cama?** población de la banda > camas de la banda, y hay ≥6 madera,
   y no hay ya una casa en obra → plantar una CHOZA en parcela válida.
2. **¿Mejorar?** una casa terminada de nivel < máx permitido por rango, con
   madera de sobra (stock > coste de mejora + colchón) → subирla un nivel.

Ritmo pausado (fuego lento): una casa/obra a la vez por aldea, mejoras
espaciadas. Retirada de la tecla R del jugador: NO (sigue pudiendo trazar
zonas a mano); la autoconstrucción conVIVE con el jugador.

## Camas con dueño

Casa terminada = `sleep_slots` camas; `claim_sleep_slot` ya las reserva por
colono (StateRest). Al mejorar, las camas suben (1→2→3) sin perder dueños.

## Puerta S7

Soak 1-2 años: 6-10 colonos sembrados levantan ≥3 casas SOLOS en sitios
razonables y alguna sube de nivel; cero intervención; sin atascos ni fugas.
Suite + humo.
