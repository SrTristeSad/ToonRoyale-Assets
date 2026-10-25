# Lua-only Windows distribution regression check.
# Execute after build-windows.ps1: powershell -File scripts/test-lua-release.ps1 -DistDir <path>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DistDir)
$ErrorActionPreference='Stop'
$DistDir=[IO.Path]::GetFullPath($DistDir)
$required=@(
  'love.exe','MOO-IO.vbs','main.lua','conf.lua','server-lua\local_server.lua',
  'scripts\start-server-lua.ps1','src\net\mooio_paths.lua',
  'src\game\mooio_home.lua','src\net\browser_auth.lua',
  'src\net\tls_bridge.lua','src\net\tls_relay_windows.lua',
  'scripts\tls-relay.mjs','runtime\node\node.exe'
)
$forbidden=@(
  'server','scripts\start-server.ps1','server-lua\tests',
  'MOO-IO.bat','MOO-IO-Lua-Teste.vbs',
  'INSTALAR-MAPA.bat','INSTALAR-MOD.bat',
  'INSTALAR-ANIMACAO.bat','INSTALAR-MOB-ARTE.bat',
  'package.json','shared','tests','tools'
)
foreach ($path in $required) {
  if (-not (Test-Path (Join-Path $DistDir $path))) { throw "Missing runtime file: $path" }
}
$testFiles=@(Get-ChildItem -LiteralPath (Join-Path $DistDir 'src') -Filter 'test_*.lua' -File -ErrorAction SilentlyContinue)
if ($testFiles.Count -gt 0) {
  throw "Development client tests leaked into release: $($testFiles[0].Name)"
}
foreach ($path in $forbidden) {
  if (Test-Path (Join-Path $DistDir $path)) { throw "Forbidden Node/V2 artifact: $path" }
}
$paths=Get-Content (Join-Path $DistDir 'src\net\mooio_paths.lua') -Raw
if ($paths -notmatch 'start-server-lua\.ps1' -or $paths -match 'return join\(root,"scripts/start-server\.ps1"\)') {
  throw 'Client startup must target only the bundled Lua server'
}
$main=Get-Content (Join-Path $DistDir 'main.lua') -Raw
$homeSource=Get-Content (Join-Path $DistDir 'src\game\mooio_home.lua') -Raw
if (($main+$homeSource) -match 'provider_lite|provider_firebase|MOO_IO_V2_PRIVATE_ROOM') {
  throw 'V2 hosting leaked into client release'
}
if ($main -notmatch 'BrowserAuth.begin' -or $homeSource -notmatch 'v2_login' -or
    $main -notmatch 'secure=secure==true') {
  throw 'Verified V2 joining was not bundled in the client'
}
$conf=Get-Content (Join-Path $DistDir 'conf.lua') -Raw
if ($conf -match 'visible\s*=\s*false') { throw 'Invalid LÖVE 11.5 window visible setting' }
$node=Join-Path $DistDir 'runtime\node\node.exe'
if ((& $node --version) -notmatch '^v22[.]') { throw 'Bundled TLS relay Node v22 missing' }
Write-Host 'PASS: Lua host + V2 join over verified TLS; no V2 hosting in release'
