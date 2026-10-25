# Lua-only Windows distribution regression check.
# Execute after build-windows.ps1: powershell -File scripts/test-lua-release.ps1 -DistDir <path>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DistDir)
$ErrorActionPreference='Stop'
$DistDir=[IO.Path]::GetFullPath($DistDir)
$required=@(
  'love.exe','main.lua','conf.lua','server-lua\local_server.lua',
  'scripts\start-server-lua.ps1','src\net\mooio_paths.lua',
  'src\game\mooio_home.lua'
)
$forbidden=@(
  'server','runtime\node','scripts\start-server.ps1',
  'src\net\browser_auth.lua','src\test_browser_auth.lua','server-lua\tests'
)
foreach ($path in $required) {
  if (-not (Test-Path (Join-Path $DistDir $path))) { throw "Missing runtime file: $path" }
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
if (($main+$homeSource) -match 'BrowserAuth|pendingBrowserLogin|v2_login|provider_lite|provider_firebase|V2 Lite|ENTRAR NA CONTA V2') {
  throw 'V2 login/provider code leaked into release UI'
}
$conf=Get-Content (Join-Path $DistDir 'conf.lua') -Raw
if ($conf -match 'visible\s*=\s*false') { throw 'Invalid LÖVE 11.5 window visible setting' }
Write-Host 'PASS: Lua-only release static contract'
