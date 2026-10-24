# SPDX-License-Identifier: AGPL-3.0-only
# Opt-in LOCAL Lua server. Do not modify the default Node launcher.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$dataDir = Join-Path $root 'server-lua\data'
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
$env:MOO_IO_LUA_SERVER = '1'
$env:MOO_IO_LUA_DATA_DIR = $dataDir
$env:PORT = '8080'
$log = Join-Path $dataDir 'lua-host.log'
$stdout = Join-Path $dataDir 'lua-stdout.log'
$stderr = Join-Path $dataDir 'lua-stderr.log'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($log,"MOOIO_PHASE_PREPARING" + [Environment]::NewLine,$utf8)
try {
  if (-not $env:MOO_IO_BIND_IP) { throw 'Endereco LAN/VPN ausente.' }
  if (-not $env:MOO_IO_ROOM_CODE) { throw 'Codigo da sala ausente.' }
  if (-not $env:MOO_IO_BOT_COUNT) { $env:MOO_IO_BOT_COUNT='0' }
  $assigned = @(Get-NetIPAddress -AddressFamily IPv4 -IPAddress $env:MOO_IO_BIND_IP -ErrorAction SilentlyContinue | Where-Object { $_.AddressState -eq 'Preferred' })
  if ($assigned.Count -eq 0) { throw "O IP $($env:MOO_IO_BIND_IP) nao esta em um adaptador LAN/VPN ativo." }
  $loveExe = $null
  foreach ($candidate in @((Join-Path $root 'runtime\love\love.exe'),(Join-Path $root 'love.exe'))) {
    if (Test-Path $candidate -PathType Leaf) { $loveExe=$candidate;break }
  }
  if (-not $loveExe) {
    $installed=Get-Command love.exe -ErrorAction SilentlyContinue
    if ($installed) { $loveExe=$installed.Source }
  }
  if (-not $loveExe) { throw 'Runtime LÖVE Lua ausente no pacote Windows. Precisa de love.exe e LuaSocket.' }
  [System.IO.File]::AppendAllText($log,"MOOIO_PHASE_STARTING" + [Environment]::NewLine,$utf8)
  $process=Start-Process -FilePath $loveExe -ArgumentList ('"' + $root + '"') -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if ($process.ExitCode -ne 0) {
    $errors = if (Test-Path $stderr) { [System.IO.File]::ReadAllText($stderr,$utf8) } else { '' }
    throw ("Servidor Lua encerrou com erro " + $process.ExitCode + ": " + (($errors -split '[\r\n]+' | Select-Object -Last 2) -join ' | '))
  }
} catch {
  [System.IO.File]::AppendAllText($log,("MOOIO_PHASE_ERROR " + $_.Exception.Message + [Environment]::NewLine),$utf8)
  exit 1
}
