# Build a self-contained Windows LÖVE/LuaSocket distribution (no Node or V2).
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$LoveDir,
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
foreach ($folder in @('src','shared','assets','server-lua')) {
  $from = Join-Path $root $folder
  $to = Join-Path $OutputDir $folder
  & robocopy.exe $from $to /E /XJ /R:2 /W:1 /MT:16 /NP /NJH /NJS /NFL /NDL | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "Falha ao copiar $folder" }
}
New-Item -ItemType Directory -Force (Join-Path $OutputDir 'scripts') | Out-Null
Copy-Item (Join-Path $root 'scripts\start-server-lua.ps1') (Join-Path $OutputDir 'scripts\start-server-lua.ps1') -Force
foreach ($file in @('main.lua','conf.lua','MOO-IO.vbs','README.md','LICENSE','NOTICE.md')) {
  Copy-Item (Join-Path $root $file) (Join-Path $OutputDir $file) -Force
}
if (Test-Path (Join-Path $root 'licenses')) {
  Copy-Item (Join-Path $root 'licenses') (Join-Path $OutputDir 'licenses') -Recurse -Force
}
Copy-Item (Join-Path $LoveDir '*') $OutputDir -Recurse -Force
# Keep the Windows release free from Node differential fixtures and tests.
foreach ($relative in @('server-lua\tests','src\test_browser_auth.lua','src\net\browser_auth.lua')) {
  $target=Join-Path $OutputDir $relative
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
}
# Runtime output must never inherit development accounts.
$luaData = Join-Path $OutputDir 'server-lua\data'
if (Test-Path $luaData) { Remove-Item $luaData -Recurse -Force }
New-Item -ItemType Directory -Force $luaData | Out-Null
# Remove the obsolete browser authentication module from release artifacts.
foreach ($file in @('src\net\browser_auth.lua','src\test_browser_auth.lua')) {
  $target=Join-Path $OutputDir $file
  if (Test-Path $target) { Remove-Item $target -Force }
}
foreach ($bad in @('server','runtime\node','scripts\start-server.ps1','server-lua\tests','src\net\browser_auth.lua')) {
  if (Test-Path (Join-Path $OutputDir $bad)) { throw "Node/V2 inesperado no pacote: $bad" }
}
[IO.File]::WriteAllText((Join-Path $OutputDir 'LEIA-ME-PRIMEIRO.txt'),
  "Moo IO Windows - servidor local somente Lua/LÖVE. Extraia e abra MOO-IO.vbs. LAN/VPN privada; sem Node.js ou login V2.")
Write-Host "Pacote Windows Lua pronto: $OutputDir"
