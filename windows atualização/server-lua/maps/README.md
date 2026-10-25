# Núcleo de mapas personalizados (schemaVersion 1)

Ao criar uma sala local no Windows, clique em **MAPA** para selecionar o clássico ou um manifesto JSON instalado em `server-lua/maps/ID.json`. Não são aceitos arquivos Lua de terceiros.

## Superfície

- `mode: "generated"`: aplica `generation` opcional (quantidade de árvores, arbustos, pedras e ouro; semente inteira `seed`) ao mundo que já existe. O gerador recebe RNG isolado quando há semente, sem modificar o gerador clássico.
- `mode: "authored"`: a lista `surface` de objetos fixos substitui a distribuição procedural. Cada recurso contém `x`, `y`, `kind` (0–3) e `scale`. Usa apenas sprites existentes.
- Com ambos, as regras, jogadores e física continuam pertencendo ao servidor local Lua. Alterações exigem recriar a sala.

## Casas e subsolo — contrato do núcleo

`spaces` define regiões não superficiais: `interior` para casas e `underground` para subterrâneos. Cada espaço aceita `width`, `height`, `obstacles` retangulares e `portals`. Na superfície, `portals` aponta para as entradas. Cada portal especifica `id`, `x`, `y`, `to`, `targetX` e `targetY`. O atributo opcional `style` aceita `house`, `bunker` ou `cave` e altera o desenho da entrada externa sem alterar a colisão ou o protocolo.

O núcleo valida limites, solidez, IDs, dimensões, destinos e colisões das regiões antes da abertura da sala. A instância autoritativa possui `room.mapSpaces` com as funções `get(id)`, `canOccupy(spaceId,x,y,radius)` e `destination(spaceId,portalId,radius)`. O mapa padrão preserva apenas a região `surface`. A sala `MB` continua clássica quando `LC` usa um mapa personalizado.

**Jogável no cliente Windows:** escolha `cabana-e-mina` na tela de criação de sala, entre na partida, caminhe até a porta da cabana no mapa e pressione **G**. Dentro, use G na escada para descer à mina ou nas saídas para voltar. O servidor Lua decide o destino e valida distância, intervalo entre interações, obstáculos e ocupação por outro jogador. Cada região tem movimento, colisão, visibilidade e renderização independentes. O exterior mostra o telhado; o interior mostra o piso e as paredes. A mesma tecla serve para todos os portais.

O protocolo **`j` é uma extensão local** em uma posição livre da tabela de mensagens de cada sessão; não altera a ordem nem os IDs dos pacotes clássicos. Sem mapa personalizado, nenhum portal é anunciado ou habilitado. Clientes em regiões diferentes não conseguem atingir uns aos outros nem sofrer ataques de animais e torres da superfície através da parede. Golpes e projéteis usam as armas originais e respeitam paredes e andares. Os animais declarados em `spaces[].mobs` usam a IA e sprites já existentes do jogo; cada entrada contém `kind` (0 a 14, exceto o chefe 11), `x` e `y`, até 24 animais por espaço.

**Construção durante a partida:** em um mapa personalizado da sala local, pressione **B** na superfície. O servidor valida a posição apontada, o espaço livre, a distância das demais construções, o limite de 16 casas por sala e duas por jogador, além do intervalo de cinco segundos. São necessários **70 madeira e 35 pedra** (gratuito quando as regras originais são sandbox). Uma casa é criada como região independente, com portal de entrada e saída, e anunciada a todos os jogadores conectados. **G** entra ou sai. Não é possível construir dentro de outras regiões; as casas permanecem até a sala terminar, sem gravação permanente entre partidas.

**Bunker de vários andares:** o exemplo `bunker-e-cavernas.json` conecta dois pisos de bunker a duas áreas de caverna, com escadas/túneis, inimigos e duas entradas superficiais. Isso também funciona como modelo de mapa comunitário — basta instalar o JSON na pasta dos mapas.

**Limites atuais:** a arte das casas/minas ainda é desenhada com geometria 2D do próprio LÖVE; o sistema de criação de casas usa um modelo pronto, sem editor de construção peça a peça nem destruição/remoção de casas. Não há tilesets externos, elevadores animados, fechaduras, mobs inéditos com artes próprias ou persistência dos edifícios entre partidas. Configurações dos mapas externos exigem recriar a sala.

## Segurança e precedência

Até 128 KiB por arquivo, 24 espaços, 256 obstáculos por espaço, 400 recursos de superfície, 64 portais de superfície e 32 por espaço. Somente campos declarados são aceitos. IDs inválidos, caminhos arbitrários, scripts, destinos ausentes e posições impossíveis são rejeitados.

As configurações são aplicadas na ordem **dificuldade → mods JSON → parâmetros de geração do mapa**. Todos os dados são pré-validados antes da geração do mundo. O pacote Windows inclui os exemplos `cabana-e-mina.json` (cabana, mina e animais), `bunker-e-cavernas.json` (bunker de dois pisos e cavernas com inimigos) e `mapa-de-exemplo.json` (disposição manual).
