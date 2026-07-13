# Hearthfolk — Build 001

Simulador de asentamiento orgánico. El jugador marca intenciones; los habitantes las interpretan, transportan materiales y construyen por fases.

## Jugar directamente

`build/Hearthfolk_001.exe` — ejecutable Windows autocontenido (pck embebido). Controles en `docs/CONTROLS.md`.

## Requisitos

- Windows 10/11.
- Godot 4.7 stable (instalado vía `winget install GodotEngine.GodotEngine`).
- Python 3.11+ con `numpy` y `pillow` (solo para regenerar audio/texturas).
- `pip install gdtoolkit` (formato y lint de GDScript).

## Abrir el proyecto

```powershell
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"
& $godot --path "C:\Users\Usuario\Desktop\Hearthfolk" -e   # editor
& $godot --path "C:\Users\Usuario\Desktop\Hearthfolk"      # jugar
```

## Tests

```powershell
& $godot --headless --path . -s tests/run_tests.gd          # unit + integración
& $godot --headless --path . -s tests/soak/soak_20min.gd    # soak 20 min ×4 (P8)
```

## Regenerar audio

```powershell
python tools/gen_audio.py   # escribe WAVs en assets/audio/generated/
```

## Documentación

`docs/CONTROLS.md` · `docs/FEATURES.md` · `docs/LIMITATIONS.md` · `docs/DECISIONS.md` · `BUILD_001_REPORT.md`
