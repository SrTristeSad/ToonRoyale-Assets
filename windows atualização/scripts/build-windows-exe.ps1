# SPDX-License-Identifier: AGPL-3.0-only
# Build the Windows x64 application as a fused LÖVE executable.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$LoveDir,
  [string]$TlsNodeExe = '',
  [string]$OutputDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) { $OutputDir = Join-Path $root 'dist\Moo-IO-Windows-EXE' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$buildArgs = @{ LoveDir = $LoveDir; OutputDir = $OutputDir }
if ($TlsNodeExe) { $buildArgs['TlsNodeExe'] = $TlsNodeExe }
& (Join-Path $PSScriptRoot 'build-windows.ps1') @buildArgs
if (-not (Test-Path (Join-Path $OutputDir 'main.lua') -PathType Leaf)) {
  throw 'Release incompleto: main.lua ausente.'
}
$paths = Join-Path $OutputDir 'src/net/mooio_paths.lua'
$pathText = [IO.File]::ReadAllText($paths)
$pathText = $pathText.Replace('abra MOO-IO.vbs na pasta do projeto.',
  'abra Moo-IO.exe na pasta do projeto.')
[IO.File]::WriteAllText($paths, $pathText, [Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$gameArchive = Join-Path $OutputDir 'Moo-IO.love'
$exe = Join-Path $OutputDir 'Moo-IO.exe'
$runtime = Join-Path $OutputDir 'love.exe'
if (Test-Path -LiteralPath $gameArchive) { Remove-Item -LiteralPath $gameArchive -Force }
if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
$zip = [IO.Compression.ZipFile]::Open($gameArchive, [IO.Compression.ZipArchiveMode]::Create)
try {
  $gameFiles = @()
  foreach ($filename in @('main.lua','conf.lua')) {
    $gameFiles += @(Get-Item -LiteralPath (Join-Path $OutputDir $filename))
  }
  foreach ($folder in @('src','assets','server-lua')) {
    $gameFiles += @(Get-ChildItem -LiteralPath (Join-Path $OutputDir $folder) -File -Recurse)
  }
  foreach ($file in $gameFiles) {
    $entry = $file.FullName.Substring($OutputDir.Length + 1).Replace('\','/')
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $file.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
  }
} finally {
  $zip.Dispose()
}
$check = [IO.Compression.ZipFile]::OpenRead($gameArchive)
try {
  $required = @('main.lua','conf.lua','src/game/death_marker.lua',
    'src/game/world_state.lua','server-lua/local_server.lua',
    'assets/custom/img/weapons/hammer_1.png')
  $names = @($check.Entries | ForEach-Object { $_.FullName })
  foreach ($needed in $required) {
    if ($names -cnotcontains $needed) { throw "Jogo compilado sem: $needed" }
  }
} finally {
  $check.Dispose()
}
Copy-Item -LiteralPath $runtime -Destination $exe -Force
$target = [IO.File]::Open($exe, [IO.FileMode]::Append, [IO.FileAccess]::Write)
$payload = $null
try {
  $payload = [IO.File]::OpenRead($gameArchive)
  $payload.CopyTo($target)
} finally {
  if ($payload) { $payload.Dispose() }
  $target.Dispose()
}
Remove-Item -LiteralPath $gameArchive -Force
# The local Lua host uses love.exe internally. Do not remove it or runtime DLLs.
$legacyLauncher = Join-Path $OutputDir 'MOO-IO.vbs'
if (Test-Path -LiteralPath $legacyLauncher) {
  Remove-Item -LiteralPath $legacyLauncher -Force
}
$instructions = @'
Moo IO Windows - build para teste com Moo-IO.exe

Extraia todo o ZIP e abra Moo-IO.exe com duplo clique, sem VBS.
Mantenha DLLs, love.exe, src/, assets/, server-lua/, scripts/ e runtime/
na mesma pasta. O love.exe inicia SOMENTE as salas Lua em segundo plano.
Para erros da sala: server-lua/data/lua-host.log e lua-stderr.log.
'@
[IO.File]::WriteAllText((Join-Path $OutputDir 'LEIA-ME-PRIMEIRO.txt'),
  $instructions, [Text.UTF8Encoding]::new($false))
$global:LASTEXITCODE = 0
Write-Host "Executavel Windows direto pronto: $exe"
