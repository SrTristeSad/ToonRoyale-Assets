# Complete Windows LÖVE/Lua local host + V2 HTTPS client. Node binary is TLS transport ONLY.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$LoveDir,
  [string]$TlsNodeExe = '',
  [string]$OutputDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) { $OutputDir = Join-Path $root 'dist\Moo-IO-Windows' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$LoveDir = [IO.Path]::GetFullPath($LoveDir)
if (-not (Test-Path (Join-Path $LoveDir 'love.exe') -PathType Leaf)) { throw 'LÖVE 11.5 Windows x64 ausente.' }
# The official LÖVE 11.5 runtime already bundles LuaSocket.
# Check the full official runtime, rather than demanding stand-alone socket DLLs.
foreach ($required in @('love.dll','SDL2.dll')) {
  if (-not (Test-Path (Join-Path $LoveDir $required) -PathType Leaf)) {
    throw "Runtime oficial LÖVE incompleto: $required."
  }
}
if (-not (Test-Path (Join-Path $root 'assets\custom\img\weapons\hammer_1.png') -PathType Leaf)) {
  throw 'Pacote de artes incompleto.'
}
if ($OutputDir -eq $root -or $OutputDir -eq $LoveDir) { throw 'OutputDir invalido.' }
if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
New-Item -ItemType Directory -Force $OutputDir | Out-Null
foreach ($folder in @('src','assets','server-lua')) {
  $from = Join-Path $root $folder
  $to = Join-Path $OutputDir $folder
  & robocopy.exe $from $to /E /XJ /R:2 /W:1 /MT:16 /NP /NJH /NJS /NFL /NDL | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "Falha ao copiar $folder" }
}
New-Item -ItemType Directory -Force (Join-Path $OutputDir 'scripts') | Out-Null
Copy-Item (Join-Path $root 'scripts\start-server-lua.ps1') (Join-Path $OutputDir 'scripts\start-server-lua.ps1') -Force
Copy-Item (Join-Path $root 'scripts\import-json-pack.ps1') (Join-Path $OutputDir 'scripts\import-json-pack.ps1') -Force
Copy-Item (Join-Path $root 'scripts\import-animation.ps1') (Join-Path $OutputDir 'scripts\import-animation.ps1') -Force
Copy-Item (Join-Path $root 'scripts\tls-relay.mjs') (Join-Path $OutputDir 'scripts\tls-relay.mjs') -Force
# Only a TLS relay uses this executable; no Node game engine is shipped.
if (-not $TlsNodeExe) {
  $cmd=Get-Command node.exe -ErrorAction SilentlyContinue
  if (-not $cmd) { throw 'Node.js 22 x64 necessario somente para a ponte TLS do cliente V2.' }
  $TlsNodeExe=$cmd.Source
}
if (-not (Test-Path $TlsNodeExe -PathType Leaf)) { throw 'node.exe TLS ausente.' }
$version=(& $TlsNodeExe --version)
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^v22[.]') {
  throw "Versao de Node TLS nao suportada: $version (requer Node 22)."
}
$nodeDir=Join-Path $OutputDir 'runtime\node'
New-Item -ItemType Directory -Force $nodeDir | Out-Null
Copy-Item $TlsNodeExe (Join-Path $nodeDir 'node.exe') -Force
foreach ($file in @('main.lua','conf.lua','MOO-IO.vbs','README.md','LICENSE','NOTICE.md')) {
  Copy-Item (Join-Path $root $file) (Join-Path $OutputDir $file) -Force
}
if (Test-Path (Join-Path $root 'licenses')) {
  Copy-Item (Join-Path $root 'licenses') (Join-Path $OutputDir 'licenses') -Recurse -Force
}
Copy-Item (Join-Path $LoveDir '*') $OutputDir -Recurse -Force
# Keep production free of tests, Node differential fixtures and debug launchers.
# Tests are retained in the staging repository for parity auditing, but they
# must not ship to players or be published as project source.
$clientTests=Get-ChildItem -LiteralPath (Join-Path $OutputDir 'src') -Filter 'test_*.lua' -File -ErrorAction SilentlyContinue
foreach ($test in $clientTests) { Remove-Item -LiteralPath $test.FullName -Force }
foreach ($relative in @('server-lua\tests')) {
  $target=Join-Path $OutputDir $relative
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
}
# Runtime output must never inherit development accounts.
$luaData = Join-Path $OutputDir 'server-lua\data'
if (Test-Path $luaData) { Remove-Item $luaData -Recurse -Force }
New-Item -ItemType Directory -Force $luaData | Out-Null
foreach ($bad in @('server','scripts\start-server.ps1','server-lua\tests')) {
  if (Test-Path (Join-Path $OutputDir $bad)) { throw "Node/V2 inesperado no pacote: $bad" }
}
[IO.File]::WriteAllText((Join-Path $OutputDir 'LEIA-ME-PRIMEIRO.txt'),
  "Moo IO Windows: hospede salas com o servidor Lua ou entre em salas V2 existentes pelo convite HTTPS. node.exe embutido e usado SOMENTE como ponte TLS no cliente, nao como servidor do jogo.")
# Robocopy exit code 1 means "files copied", not a failure.
# Prevent a stale external exit code from failing the calling PowerShell CI step.
$global:LASTEXITCODE = 0
Write-Host "Pacote Windows Lua pronto: $OutputDir"
