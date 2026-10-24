param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$Export
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Path builds/verification -Force | Out-Null
    $importOutput = & $Godot --headless --editor --import --path $projectRoot --quit 2>&1 | Out-String
    $importExit = $LASTEXITCODE
    $importOutput | Set-Content -LiteralPath builds/verification/import.txt
    if ($importExit -ne 0 -or ($importOutput -match '(?m)SCRIPT ERROR:|^ERROR:')) {
        Write-Output $importOutput
        throw "Godot import failed (exit $importExit)"
    }
    Write-Output 'Godot import passed. Details: builds/verification/import.txt'
    $testOutput = & $Godot --headless --path $projectRoot -s addons/gut/gut_cmdln.gd -gexit -gdisable_colors 2>&1 | Out-String
    $testExit = $LASTEXITCODE
    $testOutput | Set-Content -LiteralPath builds/verification/tests.txt
    Write-Output $testOutput
    if ($testExit -ne 0 -or -not ($testOutput -match 'All tests passed!') -or ($testOutput -match '(?m)SCRIPT ERROR:|^ERROR:')) { throw 'GUT failed or did not complete' }
    if ($Export) {
        New-Item -ItemType Directory -Path builds/windows -Force | Out-Null
        $exportOutput = & $Godot --headless --path $projectRoot --export-release 'Windows Desktop' builds/windows/ProjectOutpost.exe 2>&1 | Out-String
        $exportExit = $LASTEXITCODE
        $exportOutput | Set-Content -LiteralPath builds/verification/export.txt
        if ($exportExit -ne 0 -or ($exportOutput -match '(?m)SCRIPT ERROR:|^ERROR:')) {
            Write-Output $exportOutput
            throw "Export failed (exit $exportExit)"
        }
        Write-Output 'Windows export passed. Details: builds/verification/export.txt'
        Copy-Item -LiteralPath docs/ATTRIBUTION.md -Destination builds/windows/THIRD_PARTY_NOTICES.md -Force
        Copy-Item -LiteralPath docs/licenses -Destination builds/windows -Recurse -Force
        $runtimeProblems = '(?m)SCRIPT ERROR:|^ERROR:|godot_ai game_helper|ObjectDB instances were leaked'
        $runtimeOutput = & "$projectRoot/builds/windows/ProjectOutpost.exe" --headless -- --verify-export 2>&1 | Out-String
        $runtimeExit = $LASTEXITCODE
        $runtimeOutput | Set-Content -LiteralPath builds/verification/runtime.txt
        Write-Output $runtimeOutput
        if ($runtimeExit -ne 0 -or -not ($runtimeOutput -match 'OUTPOST_EXPORT_VERIFIED') -or ($runtimeOutput -match $runtimeProblems)) { throw 'Exported runtime failed, leaked audio or included development bridge' }
        $playtestOutput = & "$projectRoot/builds/windows/ProjectOutpost.exe" --headless -- --verify-export --playtest 2>&1 | Out-String
        $playtestExit = $LASTEXITCODE
        $playtestOutput | Set-Content -LiteralPath builds/verification/runtime-playtest.txt
        Write-Output $playtestOutput
        if ($playtestExit -ne 0 -or -not ($playtestOutput -match 'OUTPOST_EXPORT_VERIFIED:.*profile=playtest') -or ($playtestOutput -match $runtimeProblems)) { throw 'Playtest profile failed, leaked audio or included development bridge' }
        $flowOutput = & "$projectRoot/builds/windows/ProjectOutpost.exe" --headless -- --verify-release 2>&1 | Out-String
        $flowExit = $LASTEXITCODE
        $flowOutput | Set-Content -LiteralPath builds/verification/runtime-flow.txt
        Write-Output $flowOutput
        if ($flowExit -ne 0 -or -not ($flowOutput -match 'OUTPOST_RELEASE_FLOW:.*"ok":true') -or ($flowOutput -match $runtimeProblems)) { throw 'Exported acceptance flow failed' }
    }
}
finally {
    Pop-Location
}
