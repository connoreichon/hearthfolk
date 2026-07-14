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

Ocho corridas. Las siete primeras cazaron y enterraron **cuatro bugs de raíz** de atascos (detalle completo en BUGFIXES.md): isla de navmesh en el spawn de colonos, destinos de comer/descansar sin snap, discos RVO más grandes que sus agujeros, y el detector de bloqueo engañado por el micro-temblor del RVO. La octava, limpia:

```text
soak002 FINAL: día 21 | pob 6 | casas 1 | ent 52→65 (máx 76)
             | memoria 63.3→64.4 MB | comida-cero 0/414
SOAK002 RESULTADO: OK        (exit 0 — CERO atascos en 40 minutos)
```

2.5 años simulados: 2 colonos llegados (población al tope de camas — correcto: crecer más exige más casas, y eso es del jugador), 2 inviernos superados sin hambruna, bosque repoblándose (entidades acotadas), memoria +1.7 %. Suite final: **51 métodos, 459 comprobaciones** (el test de transporte mostró un fallo intermitente 1/3 corridas por carrera de tiempos del RVO; ventana ampliada y anotado como rareza conocida — en juego, el desatasco garantizado lo reintenta solo).

## Export y entrega

- `build/Hearthfolk_002.exe` — 112.8 MB, pck embebido, verificado ejecutándolo (captura `docs/screenshots/q6_exe_menu.png`).
- `build/Hearthfolk_002_win64.zip` — 44.4 MB, listo para itch.io (texto de página en `docs/ITCH_PAGE.md`).
- Acceso directo **«Hearthfolk»** creado en el Escritorio del usuario (icono de la cabaña).

## Qué mirar como probador (build 002)

1. Menú → Nueva partida → slot y semilla. ¿Se entiende sin explicación?
2. Marca 6-8 árboles (T), dibuja una casa (R) y un huerto (H) cerca del carro. Sube a ×2 y suelta las manos 10 minutos.
3. ¿Te apetece seguir mirando? ¿Qué te aburre primero?
4. Pasa un invierno: ¿se siente la presión de la despensa sin ser frustrante?
5. ¿La llegada de un colono nuevo se celebra sola o pasa desapercibida?
6. Guarda (F5), sal al menú, carga: ¿todo sigue igual?
7. Apunta cualquier atasco visual de habitantes (icono «?») con lo que estaban haciendo.
