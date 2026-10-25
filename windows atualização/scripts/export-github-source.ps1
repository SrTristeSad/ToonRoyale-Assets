# Build a standalone, clean source tree ready to replace ONLY Moo-IO/windows/.
# This does NOT push to the real game repository.
[CmdletBinding()]
param([string]$OutputDir = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) { $OutputDir = Join-Path $root 'dist\Moo-IO-GitHub-Source' }
$root = [IO.Path]::GetFullPath($root).TrimEnd('\')
$OutputDir = [IO.Path]::GetFullPath($OutputDir).TrimEnd('\')
if ($OutputDir -eq $root -or $OutputDir -eq (Split-Path -Parent $root) -or
  ($root.StartsWith($OutputDir + '\',[StringComparison]::OrdinalIgnoreCase))) {
  throw 'OutputDir must not contain or replace the source repository.'
}
if (Test-Path -LiteralPath $OutputDir) {
  Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force $OutputDir | Out-Null
# Explicit runtime allowlist; no Node server, legacy JS, development fixtures,
# test harnesses, original project folders or test-only launcher.
foreach ($dir in @('src','assets','server-lua','licenses','docs')) {
  $from = Join-Path $root $dir
  $to = Join-Path $OutputDir $dir
  if (-not (Test-Path -LiteralPath $from -PathType Container)) {
    throw "Required source directory missing: $from"
  }
  Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
}
foreach ($file in @('.gitignore','main.lua','conf.lua','MOO-IO.vbs',
  'README.md','LICENSE','NOTICE.md','MIGRAR-PARA-GITHUB.md')) {
  $from=Join-Path $root $file
  if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "Missing $file" }
  Copy-Item -LiteralPath $from -Destination (Join-Path $OutputDir $file) -Force
}
$scripts=Join-Path $OutputDir 'scripts'
New-Item -ItemType Directory -Force $scripts | Out-Null
foreach ($file in @('start-server-lua.ps1','tls-relay.mjs',
    'import-json-pack.ps1','import-animation.ps1',
    'build-windows.ps1','test-lua-release.ps1',
    'export-github-source.ps1')) {
  Copy-Item -LiteralPath (Join-Path $root "scripts\$file") -Destination (Join-Path $scripts $file) -Force
}
# Windows Lua release deliberately keeps developer tests in the staging repo,
# not inside source archives for players or migration.
$obsoleteGuide=Join-Path $OutputDir 'server-lua\MIGRATION_3_STEPS.md'
if (Test-Path -LiteralPath $obsoleteGuide) {
  Remove-Item -LiteralPath $obsoleteGuide -Force
}
$serverTests=Join-Path $OutputDir 'server-lua\tests'
if (Test-Path -LiteralPath $serverTests) {
  Remove-Item -LiteralPath $serverTests -Recurse -Force
}
Get-ChildItem -LiteralPath (Join-Path $OutputDir 'src') -Filter 'test_*.lua' -File |
  Remove-Item -Force
$data=Join-Path $OutputDir 'server-lua\data'
if (Test-Path -LiteralPath $data) { Remove-Item -LiteralPath $data -Recurse -Force }
# Keep the source distributable readable, free from Node executables and all BATs.
$invalid=@('server','shared','tests','tools','support','package.json',
  'MOO-IO.bat','MOO-IO-Lua-Teste.vbs','INSTALAR-MAPA.bat',
  'INSTALAR-MOD.bat','INSTALAR-ANIMACAO.bat','INSTALAR-MOB-ARTE.bat')
foreach ($item in $invalid) {
  if (Test-Path -LiteralPath (Join-Path $OutputDir $item)) {
    throw "Legacy or extraneous file in clean source: $item"
  }
}
$unwanted=@(Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
  Where-Object { $_.Extension -eq '.bat' -or $_.Name -like 'test_*.lua' -or
    $_.Name -eq 'node.exe' -or $_.Name -eq 'love.exe' })
if ($unwanted.Count -gt 0) {
  throw "Unexpected development/compiled file: $($unwanted[0].FullName)"
}
foreach ($mustHave in @('src\game\mooio_home.lua',
  'src\game\death_marker.lua','server-lua\world\bots.lua',
  'server-lua\local_server.lua','server-lua\world\map_dependencies.lua',
  'server-lua\mods\novas-especies.json','assets\custom\img\weapons\hammer_1.png',
  'scripts\start-server-lua.ps1','scripts\tls-relay.mjs')) {
  if (-not (Test-Path -LiteralPath (Join-Path $OutputDir $mustHave) -PathType Leaf)) {
    throw "Essential game file missing from source export: $mustHave"
  }
}
# Do not redirect or silently modify the Moo-IO repository. Files are staged
# as the CONTENTS of its windows/ directory, not a new project root.
Write-Host "READY: clean Lua source for Moo-IO/windows: $OutputDir"
$global:LASTEXITCODE=0
