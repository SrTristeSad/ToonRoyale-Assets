# Imports data-only Moo-IO content next to the extracted Windows game.
# Does not execute or evaluate a community pack. Full gameplay validation
# remains authoritative in map_profiles.lua / room_mods.lua at room creation.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Source,
  [ValidateSet('map','mod')][string]$Kind='map'
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'main.lua') -PathType Leaf) -or
    -not (Test-Path (Join-Path $root 'server-lua\world\map_profiles.lua') -PathType Leaf)) {
  throw 'Execute o importador a partir da pasta completa do Moo-IO.'
}
$path=[IO.Path]::GetFullPath($Source)
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
  throw 'Arquivo JSON nao encontrado.'
}
$item=Get-Item -LiteralPath $path -Force
if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw 'Links e atalhos nao podem ser importados.'
}
$name=[IO.Path]::GetFileName($path)
if (-not ($name -cmatch '^([a-z][a-z0-9-]{1,47})\.json$')) {
  throw 'Nome invalido: use ID em minusculas, numeros e hifens (2 a 48 letras).'
}
$id=$Matches[1]
$max=if ($Kind -eq 'map') {131072} else {65536}
if ($item.Length -eq 0 -or $item.Length -gt $max) {
  throw "Arquivo muito grande ou vazio (limite: $max bytes)."
}
$utf8=New-Object System.Text.UTF8Encoding($false,$true)
try {
  $jsonText=[IO.File]::ReadAllText($path,$utf8)
  $manifest=ConvertFrom-Json -InputObject $jsonText -ErrorAction Stop
} catch {
  throw 'Arquivo JSON invalido ou fora de UTF-8.'
}
if (-not $manifest -or $manifest.schemaVersion -ne 1 -or
    $manifest.id -cne $id) {
  throw 'schemaVersion deve ser 1 e ID do JSON deve coincidir com o nome do arquivo.'
}
if ($Kind -eq 'map') {
  if (-not $manifest.name -or
      $manifest.mode -notin @('generated','authored') -or
      $null -eq $manifest.generation) {
    throw 'Mapa precisa de nome, mode e generation.'
  }
  $destination=Join-Path $root 'server-lua\mods\maps'
  if (Test-Path -LiteralPath (Join-Path $root ('server-lua\maps\'+$name))) {
    throw 'Ja existe um mapa oficial com este ID. Escolha outro nome para seu mapa.'
  }
} else {
  if (-not $manifest.name -or $manifest.requiresClient -cne 'base' -or
      $null -eq $manifest.changes) {
    throw 'Mod de regras precisa de nome, requiresClient=base e changes.'
  }
  $destination=Join-Path $root 'server-lua\mods'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$target=Join-Path $destination $name
if (Test-Path -LiteralPath $target) {
  throw 'Este ID ja esta instalado. Nao sobrescrevi o pacote existente.'
}
# CreateNew rejects any unexpected race with another importer.
$read=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try {
  $write=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try { $read.CopyTo($write) } finally { $write.Dispose() }
} finally { $read.Dispose() }
Write-Host ''
Write-Host ('Instalado: '+$name) -ForegroundColor Green
Write-Host ('Pasta: '+$destination)
Write-Host 'Abra Jogar > Configurar minha sala para atualizar a lista.'
Write-Host 'O Moo-IO validara todas as regras e colisoes antes de iniciar o mapa.'
