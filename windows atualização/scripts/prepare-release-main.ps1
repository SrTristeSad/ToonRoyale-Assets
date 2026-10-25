# Drop staging-only test entry points from a copied main.lua release file.
# This never changes the repository's main.lua, where CI still runs the tests.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing $Path" }
# Git checkout on Windows may convert LF to CRLF; normalize BEFORE
# locating the test block. LÖVE accepts LF on Windows.
$code=[IO.File]::ReadAllText($Path).Replace("`r`n","`n")
$start=$code.IndexOf('  local integrationMode=os.getenv("MOOQUEST_INTEGRATION")',[StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Test-entry prelude not found in source main.lua' }
$end=$code.IndexOf("`nend`n`nangle=function",$start,[StringComparison]::Ordinal)
if ($end -lt 0) { throw 'End of client love.load not found' }
$release=$code.Substring(0,$start)+
  "  -- Production startup: remain on the Moo IO menu until user action.`n"+
  $code.Substring($end)
if ($release.Contains('require("src.test_') -or
  $release.Contains('MOOQUEST_TESTS')) {
  throw 'Staging test entry point still exists in production code.'
}
if (-not $release.Contains('MOO_IO_LUA_SERVER') -or
  -not $release.Contains('function love.load()') -or
  -not $release.Contains('BrowserAuth.begin')) {
  throw 'Required server/client startup was removed.'
}
[IO.File]::WriteAllText($Path,$release,[Text.UTF8Encoding]::new($false))
Write-Host 'PASS production main.lua: test entry points removed, normal client/server preserved'
