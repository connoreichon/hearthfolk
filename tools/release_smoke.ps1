# Smoke test del template RELEASE: exporta y ejecuta el flujo real del
# jugador (menu -> Empezar -> mundo vivo). Caza crashes que el editor y
# los tests headless (debug) enmascaran: la validacion de instancias
# nulas/liberadas de GDScript esta compilada solo en debug, asi que un
# use-after-free ahi es error amable y en release es 0xc0000005.
#
# Uso:  powershell -File tools/release_smoke.ps1 [-Runs 3] [-Seconds 30]
param(
    [int]$Runs = 3,
    [int]$Seconds = 30
)

$godot = "C:\Users\Usuario\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe"
$exe = Join-Path $env:TEMP "hf_smoke_release.exe"
$project = Split-Path -Parent $PSScriptRoot

Set-Location $project
& $godot --headless --path . --export-release "Windows Desktop" $exe 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Output "SMOKE: FALLO export ($LASTEXITCODE)"; exit 1 }

$fails = 0
foreach ($i in 1..$Runs) {
    $p = Start-Process -FilePath $exe -ArgumentList '--resolution', '1152x648', '--', '--newgame' -PassThru
    Wait-Process -Id $p.Id -Timeout $Seconds -ErrorAction SilentlyContinue
    if (-not $p.HasExited) {
        Stop-Process -Id $p.Id -Force
        Write-Output "SMOKE run ${i}: OK (vivo tras ${Seconds}s)"
    } else {
        $fails += 1
        Write-Output "SMOKE run ${i}: CRASH exit=$($p.ExitCode)"
    }
}
Remove-Item $exe -ErrorAction SilentlyContinue
if ($fails -gt 0) { Write-Output "SMOKE RESULTADO: FALLOS ($fails/$Runs)"; exit 1 }
Write-Output "SMOKE RESULTADO: OK ($Runs/$Runs vivos)"
exit 0
