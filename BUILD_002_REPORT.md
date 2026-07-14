# BUILD_002_REPORT — Hearthfolk «Un año en la colina»

Orden de producción: `docs/BUILD_002_ORDER.md` (mi propia orden, heredando el contrato técnico de la 001).

## Fases

| Fase | Contenido | Puerta |
|---|---|---|
| Q0 | Menú, opciones, 3 slots + semilla, pausa, icono | Test de flujo menú→partida→guardar→cargar ☑ |
| Q1 | 4 estaciones, nieve, repoblación del bosque | Tests de estaciones + capturas otoño/invierno ☑ |
| Q2 | Huerto, comida física, hambre real | Test de ciclo completo + invierno congela ☑ |
| Q3 | Llegadas de colonos, Casa larga | Test de llegadas (cama+excedente, tope) ☑ |
| Q4 | Moral activa que escala el trabajo | Tests de vínculo/seguridad/factor 0.6–1.15 ☑ |
| Q5 | Hitos, eventos, música por estación | Tests de hitos/helada/viajero ☑ |
| Q6 | Soak 2.5 años, export, zip itch.io | Ver abajo |

Suite final: **50 métodos, 456 comprobaciones, 0 fallos**. `gdformat`/`gdlint` limpios en todas las fases (`.gdlintrc`: max-public-methods 32, documentado).

## Soak Build 002 (40 min reales ×4, ~2.5 años in-game)

(pendiente de pegar al terminar)

## Export

(pendiente)

## Qué mirar como probador (build 002)

1. Menú → Nueva partida → slot y semilla. ¿Se entiende sin explicación?
2. Marca 6-8 árboles (T), dibuja una casa (R) y un huerto (H) cerca del carro. Sube a ×2 y suelta las manos 10 minutos.
3. ¿Te apetece seguir mirando? ¿Qué te aburre primero?
4. Pasa un invierno: ¿se siente la presión de la despensa sin ser frustrante?
5. ¿La llegada de un colono nuevo se celebra sola o pasa desapercibida?
6. Guarda (F5), sal al menú, carga: ¿todo sigue igual?
7. Apunta cualquier atasco visual de habitantes (icono «?») con lo que estaban haciendo.
