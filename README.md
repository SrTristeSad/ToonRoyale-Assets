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

## Edição pixel art fofa (176 PNGs)

A nova edição está em [`assets/pixel-art/img/`](assets/pixel-art/img/), organizada com os mesmos nomes e tamanhos das artes de referência. A edição original continua intacta em [`assets/img/`](assets/img/).

- **14 sprites de animais redesenhados**: animais dóceis mais expressivos; bull, lobos e monstros com aparência fofa, mas hostil.
- **162 outras imagens estilizadas** com grade pixel art, paleta e contornos atualizados; essas imagens não são redesenhos integrais.
- Todos os 176 arquivos são PNGs verificados e preservam os tamanhos originais de tela. O manifesto de validação está em [`assets/pixel-art/pixel-art-manifest.json`](assets/pixel-art/pixel-art-manifest.json).
- Código reprodutível: [`tools/chibi_animals.py`](tools/chibi_animals.py), [`tools/build_pixel_art.py`](tools/build_pixel_art.py) e [workflow](.github/workflows/create-pixel-art.yml).

> Nota de direitos: as artes de equipamentos derivam de referências de terceiros. O processamento de estilo não comprova licença comercial; revise direitos e substitua artes não autorizadas antes de lançar o jogo.
