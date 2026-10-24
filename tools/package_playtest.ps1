param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot 'builds/windows'
$playtestRoot = Join-Path $projectRoot 'builds/playtest'
New-Item -ItemType Directory -Path $playtestRoot -Force | Out-Null
$checksums = @{}
foreach ($name in @('ProjectOutpost.exe','ProjectOutpost.pck')) {
    $source = Join-Path $buildRoot $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing exported build file: $name" }
    $target = Join-Path $playtestRoot $name
    Copy-Item -LiteralPath $source -Destination $target -Force
    $checksums[$name] = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
}
$launcher = '@echo off' + "`r`n" + 'start "" "%~dp0ProjectOutpost.exe" -- --playtest' + "`r`n"
[IO.File]::WriteAllText((Join-Path $playtestRoot 'Start-Playtest.cmd'),$launcher,[Text.Encoding]::ASCII)
$manifest = @{ profile='playtest'; save='user://playtest/save.json'; settings='user://playtest/settings.json'; sha256=$checksums }
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $playtestRoot 'manifest.json')
$files = @('ProjectOutpost.exe','ProjectOutpost.pck','Start-Playtest.cmd','manifest.json') | ForEach-Object { Join-Path $playtestRoot $_ }
$archive = Join-Path $projectRoot 'builds/ProjectOutpost-Playtest.zip'
Compress-Archive -LiteralPath $files -DestinationPath $archive -Force
Write-Output "Playtest candidate: $archive"
