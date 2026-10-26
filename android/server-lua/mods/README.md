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

## Animações independentes e novas espécies (sem precisar criar mapas)

Modificações JSON em `server-lua/mods/ID.json` podem agora conter **`animalAnimations`** e/ou **`newAnimals`** mesmo sem a seção `changes` de regras tradicionais. Assim, o mesmo mod funciona sobre o mapa clássico da **sala Lua LC**, sobre qualquer outro mapa personalizado e pode ser combinado com alterações de dificuldade/recursos. **A sala MB clássica e os servidores V2 não são alterados.**

### Animações independentes

Exemplo: `animacao-lobo.json`, que acrescenta animações ao lobo original (ID `4`) sem modificar sua física ou precisar de um mapa.

```json
{
  "schemaVersion": 1,
  "id": "animacao-lobo",
  "name": "Animacao Independente do Lobo",
  "requiresClient": "base",
  "animalAnimations": {
    "4": {
      "sheet": "lobo_animado.png",
      "frameWidth": 64,
      "frameHeight": 64,
      "idle": {"row": 0, "frames": 4, "fps": 6},
      "walk": {"row": 1, "frames": 6, "fps": 10},
      "attack": {"row": 2, "frames": 4, "fps": 12, "loop": false}
    }
  }
}
```

Todos os estados são opcionais: `idle`, `walk`, `attack`, `hurt`, `death`. O PNG pode ser instalado em `assets/custom/img/animals/animations/` com `INSTALAR-ANIMACAO.bat`. Se a imagem não existir no cliente, o mob continua com a arte estática original. Mods de animação usam o mesmo carregamento de mods de regras no menu da sala.

### Espécies novas

Exemplo: `novas-especies.json`, que registra dois mobs **15** e **16** (sem reutilizar ou alterar o tipo de animal original). O núcleo aceita **IDs 15 a 63**, até 24 definições novas por mod e até 30 animais configurados de cada espécie no mundo inicial:

```json
{
  "schemaVersion": 1,
  "id": "criatura-exemplo",
  "name": "Criatura Exemplo",
  "requiresClient": "base",
  "newAnimals": {
    "15": {
      "name": "Lobo Cinzento",
      "src": "lobo_cinzento",
      "health": 510,
      "scale": 82,
      "speed": 0.0012,
      "turnSpeed": 0.002,
      "weightM": 0.5,
      "hostile": true,
      "chargePlayer": true,
      "dmg": 14,
      "viewRange": 950,
      "killScore": 650,
      "drop": ["food", 90],
      "desired": 3
    }
  },
  "animalAnimations": {
    "15": {
      "sheet": "lobo_cinzento.png",
      "frameWidth": 64,
      "frameHeight": 64,
      "idle": {"row": 0, "frames": 4, "fps": 6},
      "walk": {"row": 1, "frames": 6, "fps": 10},
      "attack": {"row": 2, "frames": 4, "fps": 12}
    }
  }
}
```

O campo `src` identifica o PNG estático `lobo_cinzento.png` em `assets/custom/img/animals/`; `sheet` identifica uma spritesheet em `assets/custom/img/animals/animations/`. Se faltar arte personalizada, o novo mob continua visível com a imagem padrão de lobo. Esses arquivos são opcionais, mas cada jogador deve instalá-los para ver a personalização. **Nenhum PNG é transmitido automaticamente pelo servidor.**

O servidor valida os atributos, os limites de dano/vida/velocidade, recompensas e quantidades, cria mobs reais usando a IA e o combate existentes, e anuncia as espécies novas no pacote de conexão dos clientes. A IA é escolhida pelos atributos declarados (hostilidade, perseguição, velocidade), **não por scripts Lua arbitrários**.

Quando um mapa personalizado declara `spaces[].mobs[].kind` com ID de **15 a 63**, esse mob só aparece se a espécie tiver sido registrada em algum mod selecionado; o servidor rejeita salas com espécie desconhecida. Se dois mods tentarem registrar a mesma espécie ou animar o mesmo ID, o servidor rejeita o conflito. Não há override silencioso de conteúdo.

## Mapas de mods

Um mapa de mod descreve regiões e passagens com o mesmo contrato do núcleo (pisos, paredes, dimensões, colisões, animais e tiles). Não precisa seguir nomes como `caverna`, `bunker` ou `casa`. Exemplo incluso: `server-lua/mods/maps/refugio-personalizado.json`. O catálogo do menu encontra esses mapas junto aos de `server-lua/maps/` e indica **MOD INSTALADO**. Consulte `server-lua/maps/README.md` para o formato e os limites de segurança.

Não há execução de scripts de terceiros, leitura de páginas web, instalação de
dependências, modificações de rede nem acesso à conta do jogador. Os clientes
convidados usam os mesmos sprites e pacotes de rede do jogo. O host precisa
reiniciar a sala para trocar mods ou dificuldade.
