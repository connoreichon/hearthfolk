# BUILD_001_REPORT — Hearthfolk

## Repositorio remoto — ACCIÓN DEL USUARIO REQUERIDA

La orden indicaba `https://github.com/connoreichon/hearthfolk.git`, pero la identidad git de esta máquina es `fontanalex12`. Ese repo pertenece a otra cuenta, así que **no se ha hecho push** (no se publica trabajo en repos ajenos sin confirmación). Todos los commits por fase están en local. Para subirlo a un repo tuyo:

```powershell
# 1. Crea el repo (con gh CLI autenticado):
gh repo create hearthfolk --private --source "C:\Users\Usuario\Desktop\Hearthfolk" --push
# — o a mano: crea el repo vacío en github.com y luego:
cd "C:\Users\Usuario\Desktop\Hearthfolk"
git remote add origin https://github.com/fontanalex12/hearthfolk.git
git push -u origin main
```

## Entorno

- Escritorio detectado: `C:\Users\Usuario\Desktop` (sin redirección OneDrive). Proyecto: `C:\Users\Usuario\Desktop\Hearthfolk`.
- Godot 4.7 stable — `& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe" --version` → `4.7.stable.official.5b4e0cb0f`.
- Python 3.12.10 + numpy + pillow (scipy omitido a propósito, ver DECISIONS).
- gdtoolkit 4.5 (`gdformat 4.5.0`, `gdlint 4.5.0`).

## Fases

### P0 — Entorno ✅

Hecho: estructura §2.1, project.godot (Forward+, warnings tipado como error, capas, autoloads), 8 autoloads reales (no vacíos: SimClock/TaskBoard/EntityRegistry ya funcionales), runner de tests propio, test de humo.

Verificado (comandos y salida):

- `gdformat .` → `4 files reformatted, 10 files left unchanged`
- `gdlint .` → `Success: no problems found`
- `godot --headless --path . --import` → exit 0, sin errores
- `godot --headless --path . --quit-after 3` → exit 0, consola limpia
- `godot --headless --path . -s tests/run_tests.gd` → `Métodos: 2  Comprobaciones: 11  Fallos: 0`, exit 0

Fuera de alcance de P0: nada pendiente.

### P1 — Mundo y cámara ✅

Hecho: terreno procedural completo (§4), meshes biselados (§5.3), shaders wind/terrain/outline, props por Poisson con conteos exactos, navmesh horneado por código, cámara §6 completa.

Verificado:

- `gdformat .` + `gdlint .` → limpios.
- `godot --headless --path . --quit-after 8` → exit 0, consola limpia (warnings de navegación resueltos ajustando cell_size 0.3 y merge_rasterizer_cell_scale 0.5).
- `godot --headless --path . -s tests/run_tests.gd` → `Métodos: 17  Comprobaciones: 107  Fallos: 0`.
- Run real con GPU (RTX 4060 Ti): `screenshot docs/screenshots/p1_world.png -> OK (FPS=60)`.

Detalle técnico: sonda empírica (`tools/dev_probe_winding.gd`) demostró que Godot usa winding horario para caras frontales; `MeshLib` auto-orienta cada triángulo contra su vector exterior.

Fuera de alcance de P1: interacción con ratón sobre entidades (P4), habitantes (P2).

### P2 — Habitantes visuales ✅

Hecho: figura procedural biselada (§5.3, sin cápsulas), animación procedural §5.4 (walk/idle + esqueleto work/carry), navegación con RVO y anti-vibración (§7.4 parcial: detección de bloqueo + recuperación básica; el estado RecoverFromStuck completo llega con la FSM de trabajo en P4), FSM por archivos, 4 habitantes en anillo.

Verificado:

- `gdformat`/`gdlint` limpios; import exit 0.
- `godot --headless -s tests/run_tests.gd` → `Métodos: 18  Comprobaciones: 119  Fallos: 0` (incluye integración: 4 habitantes, ≥3 en movimiento, sin solaparse tras ~450 frames a ×4).
- Run real: `docs/screenshots/p2_citizens.png`, FPS=60.

Fuera de alcance de P2: icono de estado sobre la cabeza (§5.5) → llega en P4 cuando existen estados de trabajo distinguibles.

### P3 — SimClock, necesidades, día/noche ✅

Hecho: ciclo día/noche con gradientes .tres, fogata nocturna con llamas/chispas/parpadeo, necesidades con decaimiento de sim_config, estados Eat/Rest/Return con interrupciones §7.3, velocidades Espacio/1/2/3.

Verificado:

- `gdformat`/`gdlint` limpios.
- Tests → `Métodos: 21  Comprobaciones: 126  Fallos: 0` (comer, dormir de noche 4/4, fogata >0.5 de energía, pausa congela reloj y posiciones).
- Run real: `docs/screenshots/p3_night.png` — noche con fogata encendida y habitantes tumbados (FPS=60).

Nota (documentada en DECISIONS): "minuto de simulación" interpretado como 60 s de `elapsed_sim_seconds`; con los valores del contrato la primera comida por hambre natural tarda ~días in-game — el cheat F3 "Vaciar necesidades" (P7) permite demostrarlo al momento; el descanso nocturno ocurre cada día igualmente.

### P4 — TaskBoard + tala + madera física ✅

Hecho: FSM de trabajo completa (FindTask/MoveToResource/Harvest/RecoverFromStuck), TreeEntity con caída segura y 6 maderas físicas en 3 haces + tocón, herramienta de marcado con drag-box y validaciones, iconos de estado §5.5, obstáculos de navegación dinámicos.

Verificado:

- `gdformat`/`gdlint` limpios.
- Tests → `Métodos: 23  Comprobaciones: 332  Fallos: 0` (tala end-to-end, claim único, wander y día/noche intactos).
- Run real: `docs/screenshots/p4_chop.png` — árbol marcado con hacha flotante y habitante talando (FPS=60).
- Dos bugs de raíz diagnosticados con sondas y corregidos (BUGFIXES.md): navegación congelada por desnivel navmesh/origen y repulsión en la llegada al tronco.

Pendiente conocido: los mensajes "RID leaked at exit" aparecen solo al salir del runner de tests (recursos estáticos vivos en el momento del quit); se revisará en P8.

### P5 — Transporte ✅

Hecho: HaulDispatcher, CarryResource/DeliverResource, carga visible en manos (máx. 2), soltado al interrumpir, persistencia de la carga.

Verificado: suite → `Métodos: 24  Comprobaciones: 336  Fallos: 0` (madera del suelo → almacén sin duplicados, exactamente 6). Run real: `docs/screenshots/p5_haul.png` (FPS=60).

### P6 — Zonas y construcción ✅

Hecho: receta/fases .tres, cabaña procedural por piezas con variación de semilla, ConstructionSite con demanda de material y 2 constructores, herramienta de zona con validación en vivo y razones, estados Supply/Build, rehorneado de navmesh, sueño en cabaña.

Verificado: suite → `Métodos: 26  Comprobaciones: 353  Fallos: 0` (obra completa sola: 4 fases, madera 12→0, edificio final). Runs reales: `p6_building.png` (cimientos pieza a pieza + estacas… la fase de plano con cuerdas se ve al inicio), `p6_done.png` (cabaña terminada con tejado #A9503E). Ajuste anti-atasco: stand-off 4.0 m alrededor del agujero de navmesh de la obra.

### P7 — UI, audio, guardado, depuración ✅

Hecho: 17 WAVs por síntesis numpy (`python tools/gen_audio.py` → exit 0), AudioDirector completo con ambiente por fase y límite de voces, HUD §12 completo, herramientas Selección/Información/Demoler, guardado §14 con regeneración determinista y tareas reconstruidas del mundo, F3 §15 con 8 cheats y volúmenes.

Verificado: suite → `Métodos: 28  Comprobaciones: 377  Fallos: 0` — incluye round-trip de guardado comparado campo a campo y entidad a entidad (diff por carácter). `docs/screenshots/p7_hud.png` (HUD + toast + árbol marcado, FPS=60). Tres bugs de raíz corregidos (BUGFIXES.md).
