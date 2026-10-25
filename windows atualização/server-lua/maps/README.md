# Núcleo de mapas personalizados (schemaVersion 1)

Ao criar uma sala local no Windows, use **Jogar → Configurar minha sala** para selecionar o mundo clássico ou um mapa JSON instalado em uma destas pastas:

- `server-lua/maps/ID.json`: mapas integrados ou criados pelo usuário.
- `server-lua/mods/maps/ID.json`: **mapas adicionados por mods**, exibidos no mesmo seletor.

O carregamento também funciona para qualquer ID e qualquer quantidade válida de regiões; nomes como `bunker-01`, `caverna-01` e `casa-1` **não têm significado especial para o motor de mapas**. A física, os animais, as portas, o minimapa e o transporte entre andares utilizam os mesmos componentes. IDs duplicados não substituem silenciosamente o mapa integrado. Não são aceitos arquivos Lua executáveis de terceiros.

## Posicionamento na superficie (contrato atualizado)

Em mapas com `"mode": "generated"`, a superficie e sempre procedural.
Nao informe `x`/`y` em `surface[]`, `portals[]` e `interactables[]`.
O servidor assume `"placement": "random"` automaticamente; o campo pode
ser omitido. O campo `spawn` nao e aceito nesses mapas: jogadores usam
o nascimento original do MooMoo.io. `generation.seed` continua opcional
para reproduzir testes; omiti-lo permite mapas diferentes a cada partida.

As coordenadas `targetX`/`targetY` e a geometria dentro de `spaces[]`
permanecem: indicam destinos locais, paredes e portas, nao pontos fixos
da superficie. Mapas legados `"mode": "authored"` continuam aceitando
posicoes manuais. Mods de regras `world` mudam quantidades antes da geracao,
sem alterar o algoritmo original de distribuicao.

## Geração original e distribuição aleatória (recomendado)

Os mapas em `"mode": "generated"` usam **exatamente o gerador de recursos do MooMoo.io presente no núcleo**: árvores/arbustos distribuídos nas células do mundo, pedras e minério de ouro espalhados pelo mapa, respeitando colisões e água. Em vez de posicionar tudo manualmente, deixe `"generation": {}` para manter as quantidades normais de `shared/config`. Os mods de regras podem alterar essas quantidades para a sala Lua sem mudar o algoritmo.

Para espalhar entradas e recursos **a cada partida**, declare `"placement": "random"` e **não informe** `x` nem `y`:

```json
{
  "mode": "generated",
  "generation": {},
  "portals": [
    {
      "id": "entrada-laboratorio",
      "placement": "random",
      "to": "laboratorio",
      "targetX": 600,
      "targetY": 700,
      "style": "hatch"
    }
  ],
  "surface": [
    {"placement": "random", "kind": 2, "scale": 85, "count": 8}
  ],
  "interactables": [
    {"id": "suprimento-perdido", "kind": "cache",
     "placement": "random", "resource": "food", "amount": 10}
  ]
}
```

O fragmento acima mostra apenas os campos relevantes, não o manifesto completo. Os interiores continuam declarando geometria local, paredes, portões e conexões internas. **O servidor sorteia as entradas na superfície**, separa entradas diferentes no mapa, procura pontos sem colisões, atualiza automaticamente as passagens de retorno do interior e sincroniza todos os jogadores. A posição dos recursos também deixa de ser uma lista fixa de coordenadas.

`generation.seed` é **opcional**: se omitida, o mundo muda entre as partidas; se especificada, permite reproduzir exatamente a mesma geração para testes e desafios. O campo `spawn` também é opcional: sem ele, reaparece o fluxo original de spawn do MooMoo.io, sem colocar o jogador num único ponto previamente marcado.

Mapas antigos com `x`/`y` explícitos continuam aceitos por compatibilidade, particularmente em `mode: "authored"`. O que mudou é o padrão dos mapas gerados fornecidos com o jogo: eles não trazem mais locais fixos de entradas, spawn ou recursos. A interface também deixou de revelar à distância as coordenadas ou distâncias das entradas.

## Objetos interativos declarativos (JSON)

Mapas de mods podem declarar `interactables` nas regiões `spaces[]` e na superfície. Não há execução de scripts do pacote: o servidor é responsável pelos recursos, colisões e estados.

```json
"interactables": [
  {"id":"bau-01","kind":"cache","x":540,"y":550,
   "label":"Baú de madeira","resource":"wood","amount":35},
  {"id":"alavanca-01","kind":"lever","x":650,"y":740,
   "label":"Abrir portão","target":"portao-01"},
  {"id":"portao-01","kind":"gate","x":820,"y":770,
   "width":48,"height":175,"material":"metal"}
]
```

**Controle:** caminhe até um baú ou alavanca e pressione **F**. O servidor verifica se a pessoa está viva, na região correta, a menos de 150 unidades e sem paredes no caminho. A recompensa de um baú pode ser madeira (`wood`), pedra (`stone`) ou comida (`food`), de 1 a 500 unidades, concedida uma única vez por partida. Uma alavanca aponta para um portão existente na *mesma* região e o abre permanentemente naquela partida. O portão fechado é uma parede de colisão real; sua abertura remove essa parede do servidor e de todos os clientes na região. Jogadores que entrarem depois recebem o estado atualizado.

Limites: até 32 objetos interativos por região; todos precisam de IDs exclusivos. A superfície permite baús de recursos e pontos de coleta limitados, enquanto portões/alavancas/interruptores físicos pertencem a regiões interiores ou subterrâneas até que a física de barreiras na superfície seja ampliada. Esses objetos não adicionam execução Lua, imagens externas ou comportamentos arbitrários. O mapa `refugio-personalizado.json` demonstra esses elementos.

## Animações opcionais de mobs (spritesheet PNG)

**Nenhuma animação é obrigatória.** Os mobs continuam funcionando com a imagem PNG original quando um mapa não define animações, quando a spritesheet não foi instalada ou quando falta uma ação. Movimentação, colisões, inteligência artificial, ataque, dano e recompensas continuam sob controle do servidor.

No JSON de um **mapa personalizado**, acrescente `animalAnimations` no nível principal. Cada chave é o ID numérico do tipo de animal original (por exemplo, `"4"` é o lobo):

```json
"animalAnimations": {
  "4": {
    "sheet": "wolf_custom.png",
    "frameWidth": 64,
    "frameHeight": 64,
    "idle":   {"row": 0, "frames": 4, "fps": 6},
    "walk":   {"row": 1, "frames": 6, "fps": 10},
    "attack": {"row": 2, "frames": 5, "fps": 12, "loop": false},
    "hurt":   {"row": 3, "frames": 3, "fps": 8, "loop": false},
    "death":  {"row": 4, "frames": 7, "fps": 7, "loop": false}
  }
}
```

O arquivo `wolf_custom.png` é uma **spritesheet de quadros alinhados em grade**, com cada animação em uma linha (a primeira é a linha `0`), e cada quadro com as dimensões `frameWidth × frameHeight`. Não precisa declarar as cinco ações: `idle`, `walk`, `attack`, `hurt` e `death` são independentes. Se uma ação não estiver presente, o renderizador usa `idle` quando existir; sem `idle`, mantém o sprite original. Uma animação com `loop: false` mantém o último quadro até a ação terminar; outras podem repetir os quadros continuamente. Animações de ataque e dano são acionadas por eventos reais do jogo, sem mudar a lógica do combate.

**Instalação no Windows:** arraste o PNG para `INSTALAR-ANIMACAO.bat`, que o copia para `assets/custom/img/animals/animations/`, ou coloque o arquivo manualmente nessa pasta. Alternativamente, o cliente procura em `server-lua/mods/animations/`. O nome deve coincidir exatamente com `sheet`. Também é possível arrastar o JSON do mapa para `INSTALAR-MAPA.bat`.

Limites do formato: nomes PNG simples (sem caminhos relativos), `frameWidth` e `frameHeight` de 8 a 512, até 24 quadros por ação, até 32 linhas e velocidade de 1 a 30 FPS. O instalador PNG limita o arquivo a 8 MiB e 4096 × 4096 pixels. Nenhum arquivo Lua, script, link externo ou shader pode ser executado pelo manifesto.

**Multiplayer:** o host anuncia aos clientes os metadados visuais. Para enxergar animações personalizadas, cada jogador precisa ter a mesma spritesheet PNG instalada no próprio cliente; se não tiver, verá a imagem original, mas continuará jogando normalmente. O modo clássico e as salas V2 não passam a exigir animações.

## Pontos de coleta e interruptores reversíveis

Para um mapa personalizado, `interactables` também aceita pontos de coleta limitados e mecanismos que podem alternar o mesmo portão diversas vezes:

```json
"interactables": [
  {"id":"mina-pedra","kind":"node","x":550,"y":930,
   "label":"Minerio renovavel","resource":"stone","amount":8,
   "charges":3,"cooldownMs":1500},
  {"id":"interruptor-portao","kind":"switch","x":690,"y":880,
   "label":"Abrir ou fechar","target":"portao-metal","cooldownMs":500},
  {"id":"portao-metal","kind":"gate","x":750,"y":730,
   "width":48,"height":175,"material":"metal"}
]
```

- **`node`**: entrega `amount` por coleta, com um máximo de `charges` entre **1 e 20**, e `cooldownMs` entre **0 e 120.000 ms**. Ao acabar, permanece esgotado até o término daquela partida. O tempo de recuperação pertence ao objeto e é compartilhado por todos os jogadores, prevenindo coleta duplicada.
- **`switch`**: alterna um portão da mesma região entre aberto e fechado, com `cooldownMs` entre **0 e 120.000 ms**. Diferentemente de `lever`, não é consumido após o primeiro uso.
- **Segurança**: o servidor rejeita fechamento quando um jogador, animal ou acesso de passagem ocupa a área do portão. Não permite portão instalado sobre a saída, posição de chegada nem muito perto de uma passagem. O desenho e a colisão atualizam juntos em todos os clientes.
- **Onde usar**: pontos de coleta podem aparecer na superfície ou em regiões internas de **mapas personalizados**. Portões, alavancas e interruptores ficam em regiões com física própria. O mundo clássico e o V2 permanecem sem essas regras.
- **Sincronização**: mudanças usam versões ordenadas por objeto para recusar pacotes repetidos ou atrasados. Quem entrar depois recebe quantidades restantes, alavancas já acionadas e o estado atual de cada portão.

O mapa de exemplo `refugio-personalizado.json` inclui uma mina com três coletas e um interruptor de portão reversível. Use **F** perto dos objetos para interagir.

## Visuais, tiles e portais universais

Todo espaço `interior` ou `underground` pode declarar um objeto `visual` opcional e validado. O renderizador usa esses valores, **não o ID da região**:

```json
{
  "id": "andar-laboratorio",
  "type": "interior",
  "width": 1300,
  "height": 1100,
  "visual": {
    "floor": "metal",
    "wall": "brick",
    "tileSize": 96,
    "name": "Laboratório"
  },
  "obstacles": [
    {"x": 100, "y": 100, "width": 500, "height": 70, "material": "stone"}
  ],
  "portals": [
    {"id": "saida", "x": 600, "y": 800,
     "to": "surface", "targetX": 3500, "targetY": 3500,
     "style": "hatch", "label": "Retornar"}
  ],
  "mobs": []
}
```

- Pisos e materiais permitidos: `wood`, `rock`, `metal`, `stone`, `sand`, `earth`, `grass`, `ice` e `brick`.
- `tileSize`: número inteiro de 32 a 256 unidades. As coordenadas, paredes e colisões continuam sendo calculadas no espaço do mundo, independentemente do tamanho do desenho do piso.
- `obstacles[].material`: opcional; altera o desenho daquela parede, mas a colisão continua usando seu retângulo.
- `portals[].style`: `door`, `hatch`, `stairs`, `tunnel`, `arch`; os nomes antigos `house`, `bunker` e `cave` continuam funcionando.
- `portals[].label`: texto opcional limitado a 40 caracteres exibido no cenário e nas indicações de acesso.
- Campos omitidos usam materiais padrão compatíveis com mapas anteriores. Não há leitura de caminhos arbitrários de imagem, shaders, scripts ou bibliotecas pelos pacotes JSON.

Para testar uma instalação de mod completa, selecione **Refúgio Personalizado (mod)**. Ele está em `server-lua/mods/maps/refugio-personalizado.json` e demonstra um andar de metal e tijolos conectado a outro de gelo e pedra, com os nomes `mod-sala-metal` e `mod-sala-gelo`. Podem ser combinados mods de regras (lobos, recursos etc.) com qualquer mapa personalizado.

## Superfície

- `mode: "generated"`: aplica `generation` opcional (quantidade de árvores, arbustos, pedras e ouro; semente inteira `seed`) ao mundo que já existe. O gerador recebe RNG isolado quando há semente, sem modificar o gerador clássico.
- `mode: "authored"`: a lista `surface` de objetos fixos substitui a distribuição procedural. Cada recurso contém `x`, `y`, `kind` (0–3) e `scale`. Usa apenas sprites existentes.
- Com ambos, as regras, jogadores e física continuam pertencendo ao servidor local Lua. Alterações exigem recriar a sala.

## Casas e subsolo — contrato do núcleo

`spaces` define regiões não superficiais: `interior` para casas e `underground` para subterrâneos. Cada espaço aceita `width`, `height`, `obstacles` retangulares e `portals`. Na superfície, `portals` aponta para as entradas. Cada portal especifica `id`, `x`, `y`, `to`, `targetX` e `targetY`. O atributo opcional `style` aceita `house`, `bunker` ou `cave` e altera o desenho da entrada externa sem alterar a colisão ou o protocolo.

O núcleo valida limites, solidez, IDs, dimensões, destinos e colisões das regiões antes da abertura da sala. A instância autoritativa possui `room.mapSpaces` com as funções `get(id)`, `canOccupy(spaceId,x,y,radius)` e `destination(spaceId,portalId,radius)`. O mapa padrão preserva apenas a região `surface`. A sala `MB` continua clássica quando `LC` usa um mapa personalizado.

**Jogável no cliente Windows:** escolha `cabana-e-mina` ou `bunker-e-cavernas` em **Jogar → Configurar minha sala**. As passagens agora funcionam **caminhando sobre a porta, escada ou túnel**, sem tecla G ou botão de interação. O servidor Lua seleciona o destino e valida distância, obstáculos e espaço livre; a passagem de destino fica temporariamente desarmada até o personagem afastar-se, evitando teleporte repetido. O deslocamento WASD é preservado ao mudar de região. Cada região possui sua própria geometria, colisão, visibilidade e renderização. A superfície mostra telhado/entrada; cavernas têm piso rochoso; bunkers têm piso industrial. **Dentro de qualquer andar**, o HUD exibe a **planta física do andar**, construída a partir das paredes, dimensões e portais recebidos do servidor: seu ponto aparece em verde, portas/escadas em amarelo e aliados em azul. Pressione **M** para ocultar ou mostrar essa planta, sem abrir menus nem afetar o movimento. Animais hostis não são revelados pelo minimapa.

O protocolo **`j` é uma extensão local** em uma posição livre da tabela de mensagens de cada sessão; não altera a ordem nem os IDs dos pacotes clássicos. Sem mapa personalizado, nenhum portal é anunciado ou habilitado. Clientes em regiões diferentes não conseguem atingir uns aos outros nem sofrer ataques de animais e torres da superfície através da parede. Golpes e projéteis usam as armas originais e respeitam paredes e andares. Os animais declarados em `spaces[].mobs` usam a IA e sprites já existentes do jogo, com colisão em eixos independentes contra paredes subterrâneas (sem travar ao encostar numa quina); cada entrada contém `kind` (0 a 14, exceto o chefe 11), `x` e `y`, até 24 animais por espaço.

**Casas como conteúdo de mapas e mods:** a criação de casas é feita pelo **autor** do mapa JSON, não pelo jogador. Defina a construção como uma região `spaces[]` do tipo `interior`, descreva suas paredes em `obstacles[]` e ligue-a ao mundo com `portals[]`. Para um mapa `mode: "generated"`, a entrada na superfície é sorteada e os retornos são sincronizados automaticamente. A configuração de casa não requer uma receita, tecla de construção, consumo de madeira/pedra nem arquivo de persistência separado.

**Sem construção de casas em partidas:** os antigos comandos `B` (casa), `H` (editor de paredes) e as mensagens de rede `j:build`, `j:wall` e `j:remove-wall` foram removidos do jogo normal; as mensagens antigas são recusadas pelo servidor. Não existem mais arquivos `houses-*.json` gravados por jogadores. As construções tradicionais do MooMoo.io (paredes, espinhos, armadilhas e outras do inventário) continuam disponíveis.

**Bunker de vários andares:** o exemplo `bunker-e-cavernas.json` conecta dois pisos de bunker a duas áreas de caverna, com escadas/túneis, inimigos e duas entradas superficiais. Isso também funciona como modelo de mapa comunitário — basta instalar o JSON na pasta dos mapas.

**Limites atuais:** pisos, estruturas e paredes usam geometria 2D do LÖVE com detalhes simples; não há tilesets externos, editor completo de planta baixa com ferramentas de múltiplos materiais, móveis, elevadores animados, fechaduras ou novos sprites de criaturas. As estruturas e paredes de interiores são definidas pelos autores nos arquivos JSON. Configurações de mapas externos exigem recriar a sala.

## Segurança e precedência

Até 128 KiB por arquivo, 24 espaços, 256 obstáculos por espaço, 400 recursos de superfície, 64 portais de superfície e 32 por espaço. Somente campos declarados são aceitos. IDs inválidos, caminhos arbitrários, scripts, destinos ausentes e posições impossíveis são rejeitados.

As configurações são aplicadas na ordem **parâmetros de geração do mapa → dificuldade → mods JSON**. Assim, os mods ativos prevalecem quando modificam as mesmas propriedades. O nível Normal usa a população original de **51 animais** (contando, nos mapas personalizados, os animais de cavernas/bunkers dentro da mesma população por espécie, em vez de somá-los aos 51 da superfície). Todos os dados são pré-validados antes da geração do mundo. O pacote Windows inclui os exemplos `cabana-e-mina.json` (cabana, mina e animais), `bunker-e-cavernas.json` (bunker de dois pisos e cavernas com inimigos) e `mapa-de-exemplo.json` (disposição manual).
