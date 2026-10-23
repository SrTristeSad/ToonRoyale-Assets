# ToonRoyale Assets

Imagens em PNG verdadeiro, organizadas em `assets/img/` e preservando os nomes originais.

## Importação

A pasta `assets/img/` é preenchida automaticamente pela GitHub Action
`.github/workflows/import-png-assets.yml`, usando uma revisão fixa da fonte.

O pacote fornecido para verificação possui **176 imagens**: 168 PNGs válidos
e 8 imagens WebP com extensão `.png` que precisam ser convertidas.

A importação valida o SHA-256 agregado dos 176 arquivos de entrada,
converte as 8 imagens WebP para PNG sem alteração dos pixels RGBA e
confere novamente todos os arquivos.

## Origem e direitos

Referência de bytes: `al007ex/moomoo-clone` no commit
`06f7c1ca965a7628671676c8d9a7efd3997bb5e7`.

As imagens são mantidas como referência técnica; a presença delas
neste repositório não concede licença para redistribuição ou uso comercial.
Verifique os direitos autorais antes de publicá-las com um jogo.
