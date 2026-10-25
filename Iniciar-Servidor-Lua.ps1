# Servidor local Lua Windows — requer LuaJIT e LuaSocket compativeis
[CmdletBinding()]
param(
  [string]$IP = "127.0.0.1",
  [ValidateRange(1,65534)][int]$Porta = 8080,
  [ValidateRange(0,8)][int]$Bots = 0,
  [ValidateSet("lan","vpn")][string]$Rede = "lan",
  [string]$Codigo = ""
)
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
if (-not (Test-Path "server-lua/run.lua") -or -not (Test-Path "src/protocol/msgpack.lua")) {
  throw "Pacote incompleto: mantenha as pastas server-lua e src juntas."
}
$lua = Get-Command "luajit.exe" -ErrorAction SilentlyContinue
if (-not $lua) { $lua = Get-Command "luajit" -ErrorAction SilentlyContinue }
if (-not $lua) {
  throw "Instale LuaJIT para Windows (luajit.exe). Este ZIP nao inclui binarios."
}
& $lua.Source -e 'assert(jit and jit.os == "Windows"); assert(require("socket")); assert(require("ffi"))'
if ($LASTEXITCODE -ne 0) {
  throw "LuaJIT com LuaSocket e FFI compativeis e necessario. Confira o README."
}
if ($Codigo -eq "") {
  $random = New-Object 'System.Byte[]' 12
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($random) } finally { $rng.Dispose() }
  $Codigo = ([BitConverter]::ToString($random)).Replace("-", "").ToLowerInvariant()
}
if ($Codigo -notmatch '^[A-Za-z0-9-]{8,64}$') { throw "Codigo da sala invalido." }
$dir = Join-Path $PSScriptRoot "dados-lua"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$env:MOO_IO_BIND_IP = $IP
$env:MOO_IO_ROOM_CODE = $Codigo
$env:MOO_IO_NETWORK_MODE = $Rede
$env:MOO_IO_BOT_COUNT = [string]$Bots
$env:MOO_IO_LUA_DATA_DIR = $dir
$env:PORT = [string]$Porta
Remove-Item Env:MOO_IO_V2_PRIVATE_ROOM -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Servidor LOCAL Lua — Moo-IO"
Write-Host "Endereco: $IP`:$Porta"
Write-Host "Codigo: $Codigo"
Write-Host "Bots: $Bots"
Write-Host "Pare o servidor Node.js caso esteja usando esta porta."
Write-Host ""
& $lua.Source "server-lua/run.lua"
if ($LASTEXITCODE -ne 0) { throw "Servidor Lua encerrou com erro: $LASTEXITCODE" }
