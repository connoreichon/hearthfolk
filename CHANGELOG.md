# CHANGELOG — Hearthfolk

## P0 — Entorno (2026-07-13)

- Godot 4.7 stable instalado (winget) y verificado (`4.7.stable.official.5b4e0cb0f`).
- gdtoolkit 4.5 (gdformat + gdlint) instalado y en uso.
- Proyecto creado en `Desktop\Hearthfolk`: git init, `.gitignore` Godot, estructura completa de carpetas §2.1.
- `project.godot`: Forward+, 1920×1080 canvas_items/expand, `untyped_declaration=2` (error), 8 capas de colisión con nombre, 8 autoloads.
- Autoloads: EventBus (lista cerrada de señales §2.4), SimClock (tick fijo 20 Hz, velocidades, fases del día), GameState (RNG sembrado, inventario), TaskBoard (claim atómico, TTL, blacklist, purga de targets muertos), EntityRegistry (IDs estables), SaveManager (I/O JSON + migraciones), AudioDirector (buses Music/Ambience/SFX/UI), DebugOverlay (F3 con métricas).
- Runner de tests propio (`tests/run_tests.gd`) + `HFTestCase`; primer test de humo verde (11 comprobaciones).
- Puertas P0: `gdformat`+`gdlint` limpios; import headless exit 0; arranque headless `--quit-after 3` exit 0 sin errores; tests exit 0.
