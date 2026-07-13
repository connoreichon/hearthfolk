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
