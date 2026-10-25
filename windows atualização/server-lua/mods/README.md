# Núcleo de mods — Moo-IO Windows/Lua

O núcleo aceita **dois tipos independentes de conteúdo JSON**: mods de regras em `server-lua/mods/ID.json` e mapas/modificações de cenário em `server-lua/mods/maps/ID.json`. Ambos podem ser combinados na mesma sala: selecione o cenário na lista de mapas e as regras na lista de mods. Um mod de regras pode alterar animais e economia do mundo sem fornecer um mapa; um mapa personalizado pode funcionar sem nenhum mod de regras.

Os mods de regras são **pacotes de regras JSON** interpretados pelo servidor local. Coloque cada
manifesto em `server-lua/mods/ID.json`. Na tela **Jogar → Criar minha sala**,
escolha a dificuldade, clique **Escolher** para marcar os mods instalados e só
então clique **Criar sala**. Também é possível informar IDs separados por
vírgula no campo, para jogadores avançados.

O servidor valida todos os mods e combina as regras **antes de gerar o mapa,
criar jogadores ou iniciar o processo**. Os ajustes pertencem somente àquela
sala. Se algum mod estiver inválido, ausente ou entrar em conflito com outro,
a criação é recusada com uma mensagem — sem carregar parcialmente as regras.

## Formato v1

```json
{
  "schemaVersion": 1,
  "id": "floresta-densa",
  "name": "Floresta Densa",
  "description": "Mais árvores e minério.",
  "requiresClient": "base",
  "changes": {
    "world": {"treesPerArea": 17, "bushesPerArea": 7, "totalRocks": 54, "goldOres": 12}
  }
}
```

Grupos permitidos:

- **`world`**: valores inteiros de `treesPerArea` (0–50), `bushesPerArea` (0–50), `totalRocks` (0–400) e `goldOres` (0–160).
- **`spawns`**: `{"4":{"desired":18}}` altera a quantidade do animal 4; de 0 a 200, com teto total de 600 animais.
- **`animals`**: por ID do animal, `health`, `dmg`, `speed`, `viewRange` e `turnSpeed`, com limites validados pelo núcleo.
- **`rules`**: `healthRegenPerSecond` (0–30), `cooperativeWolves` (booleano) e `predictiveHostiles` (booleano). São verificadas no próprio tick do servidor.

## Dificuldade escolhida ao iniciar a partida

- **Pacífico:** menos animais agressivos, menos perseguição, regeneração natural de 6 HP/s.
- **Normal:** referência tradicional, sem regeneração nem colaboração de matilhas introduzida.
- **Difícil:** mais animais, criaturas hostis antecipam movimento e lobos caçam em grupo.
- **Extremo:** multiplicadores maiores e formação de caça ainda mais agressiva.

O núcleo aplica **primeiro a dificuldade**, depois os mods selecionados. Por
exemplo, `lobos-em-matilha` ativa a cooperação dos lobos no Normal, sem
precisar alterar esse preset. Cada mod somente altera os campos autorizados;
valores repetidos por dois mods diferentes são rejeitados como conflito.

## Exemplos incluídos

- `mais-lobos`: mais lobos e aumento de dano/alcance.
- `fauna-hostil`: javalis e touros mais perigosos.
- `floresta-densa`: mais árvores, arbustos, pedras e ouro.
- `lobos-em-matilha`: cooperação de lobos em qualquer dificuldade.

## Mapas de mods

Um mapa de mod descreve regiões e passagens com o mesmo contrato do núcleo (pisos, paredes, dimensões, colisões, animais e tiles). Não precisa seguir nomes como `caverna`, `bunker` ou `casa`. Exemplo incluso: `server-lua/mods/maps/refugio-personalizado.json`. O catálogo do menu encontra esses mapas junto aos de `server-lua/maps/` e indica **MOD INSTALADO**. Consulte `server-lua/maps/README.md` para o formato e os limites de segurança.

Não há execução de scripts de terceiros, leitura de páginas web, instalação de
dependências, modificações de rede nem acesso à conta do jogador. Os clientes
convidados usam os mesmos sprites e pacotes de rede do jogo. O host precisa
reiniciar a sala para trocar mods ou dificuldade.
