# Install a local PNG spritesheet for optional JSON mob animations.
# Does not run third-party code. No change to server gameplay or V2.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'main.lua') -PathType Leaf)) {
 throw 'Execute a partir da pasta extraida do Moo-IO.'
}
$path=[IO.Path]::GetFullPath($Source)
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
 throw 'Arquivo PNG inexistente.'
}
$item=Get-Item -LiteralPath $path -Force
if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
 throw 'Links e atalhos nao sao suportados.'
}
$name=[IO.Path]::GetFileName($path)
if (-not ($name -cmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*\.png$')
  -or $name.Length -gt 64) {
 throw 'Nome invalido: letras, numeros, _ e -, terminando em .png.'
}
if ($item.Length -lt 33 -or $item.Length -gt 8388608) {
 throw 'O PNG deve ter entre 33 bytes e 8 MiB.'
}
$bytes=[IO.File]::ReadAllBytes($path)
$signature=@(137,80,78,71,13,10,26,10)
for ($i=0;$i -lt 8;$i++) {
 if ($bytes[$i] -ne $signature[$i]) { throw 'Assinatura PNG invalida.' }
}
if ([Text.Encoding]::ASCII.GetString($bytes,12,4) -cne 'IHDR') {
 throw 'IHDR PNG ausente.'
}
function ReadBigEndian32([byte[]]$b,[int]$start) {
 return ([long]$b[$start] * 16777216) + ([long]$b[$start+1] * 65536) +
   ([long]$b[$start+2] * 256) + [long]$b[$start+3]
}
$width=ReadBigEndian32 $bytes 16
$height=ReadBigEndian32 $bytes 20
if ($width -lt 8 -or $height -lt 8 -or
    $width -gt 4096 -or $height -gt 4096) {
 throw 'A spritesheet deve ter dimensoes entre 8 e 4096 px.'
}
$dest=Join-Path $root 'assets\custom\img\animals\animations'
New-Item -Path $dest -ItemType Directory -Force | Out-Null
$target=Join-Path $dest $name
if (Test-Path -LiteralPath $target) {
 throw 'Ja existe uma spritesheet com esse nome. Nada foi sobrescrito.'
}
$stream=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
Write-Host ("Spritesheet instalada: "+$name+" ("+$width+"x"+$height+")") -ForegroundColor Green
Write-Host 'Declare o mesmo nome no campo animalAnimations do mapa JSON.'
Write-Host 'O mob continuara usando sprite estatico se um clipe nao existir.'
