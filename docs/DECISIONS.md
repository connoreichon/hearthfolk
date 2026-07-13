# DECISIONS — Hearthfolk Build 001

Formato: `[FECHA] [ÁREA] Ambigüedad → Decisión → Motivo`

- [2026-07-13] [ENTORNO] El repo remoto indicado (`github.com/connoreichon/hearthfolk.git`) no coincide con la identidad git local (`fontanalex12`) → trabajo solo en local, commits por fase, sin push → no se publica trabajo en un repositorio ajeno sin confirmación explícita del usuario. Comandos para subirlo a un repo propio: ver `BUILD_001_REPORT.md`.
- [2026-07-13] [AUDIO] scipy no estaba instalado → `tools/gen_audio.py` usa solo numpy (filtros y envolventes a mano) → una dependencia menos, misma calidad para WAVs sintetizados.
- [2026-07-13] [ENTORNO] Mapa de entrada → registrado por código (`scripts/utilities/input_setup.gd`) en vez de serializado en `project.godot` → una única fuente de verdad tipada, sin bloques `Object(InputEventKey,...)` frágiles.
- [2026-07-13] [UI] Conflicto de atajos: §11 asigna 1/2/3 a velocidades y §12 pide "atajos numéricos" para herramientas → velocidades en Espacio/1/2/3; herramientas en T (tala), R (zona residencial), C (demoler/cancelar), I (información), Esc (cancelar) → sin colisiones.
- [2026-07-13] [TESTS] GUT vs runner propio → runner propio (`tests/run_tests.gd`, extends SceneTree; los autoloads SÍ están disponibles en modo `-s`, verificado empíricamente) → cero dependencias de terceros y sin riesgo de incompatibilidad con Godot 4.7.
- [2026-07-13] [ARQ] `IPersistent` como interfaz → contrato duck-typing documentado + helper estático `implemented_by()` → GDScript no tiene interfaces y las entidades heredan de `CharacterBody3D`/`StaticBody3D`, imposible herencia común.
- [2026-07-13] [ARQ] `TaskBoard.best_task_for(citizen: Citizen)` referenciaría una clase que no existe hasta P2 → firma `best_task_for(citizen_id: int, from_position: Vector3, kinds)` → evita dependencia circular autoload→clase de gameplay.
- [2026-07-13] [DATOS] Sentido de la barra de hambre → 100 = saciado, 0 = famélico (recomendación de §7.1 adoptada) → todas las barras "más = mejor", consistente en código y UI.
- [2026-07-13] [ENTORNO] Godot instalado vía winget (4.7 stable, sin symlink en PATH) → los scripts y docs usan la ruta completa del paquete winget → reproducible sin tocar PATH del usuario.
