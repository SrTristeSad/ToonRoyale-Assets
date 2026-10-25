# Núcleo de mapas personalizados (schemaVersion 1)

Ao criar uma sala local no Windows, clique em **MAPA** para selecionar o clássico ou um manifesto JSON instalado em `server-lua/maps/ID.json`. Não são aceitos arquivos Lua de terceiros.

## Superfície

- `mode: "generated"`: aplica `generation` opcional (quantidade de árvores, arbustos, pedras e ouro; semente inteira `seed`) ao mundo que já existe. O gerador recebe RNG isolado quando há semente, sem modificar o gerador clássico.
- `mode: "authored"`: a lista `surface` de objetos fixos substitui a distribuição procedural. Cada recurso contém `x`, `y`, `kind` (0–3) e `scale`. Usa apenas sprites existentes.
- Com ambos, as regras, jogadores e física continuam pertencendo ao servidor local Lua. Alterações exigem recriar a sala.

## Casas e subsolo — contrato do núcleo

`spaces` define regiões não superficiais: `interior` para casas e `underground` para subterrâneos. Cada espaço aceita `width`, `height`, `obstacles` retangulares e `portals`. Na superfície, `portals` aponta para as entradas. Cada portal especifica `id`, `x`, `y`, `to`, `targetX` e `targetY`.

O núcleo valida limites, solidez, IDs, dimensões, destinos e colisões das regiões antes da abertura da sala. A instância autoritativa possui `room.mapSpaces` com as funções `get(id)`, `canOccupy(spaceId,x,y,radius)` e `destination(spaceId,portalId,radius)`. O mapa padrão preserva apenas a região `surface`. A sala `MB` continua clássica quando `LC` usa um mapa personalizado.

**Limite funcional atual:** interiores e subsolos já são dados consultáveis pelo núcleo, mas **não são ainda áreas jogáveis**. Faltam transição de personagens entre espaços, atualização de colisão física por espaço, sincronização de jogadores/objetos de cada região e renderização no cliente Windows. Isso deverá ser integrado por uma extensão do protocolo local negociada pelo cliente, sem alterar o protocolo clássico nem o servidor V2. As entradas da cabana são, por enquanto, metadados; clicar nelas no jogo não teletransporta o personagem.

## Segurança e precedência

Até 128 KiB por arquivo, 24 espaços, 256 obstáculos por espaço, 400 recursos de superfície, 64 portais de superfície e 32 por espaço. Somente campos declarados são aceitos. IDs inválidos, caminhos arbitrários, scripts, destinos ausentes e posições impossíveis são rejeitados.

As configurações são aplicadas na ordem **dificuldade → mods JSON → parâmetros de geração do mapa**. Todos os dados são pré-validados antes da geração do mundo. O pacote Windows inclui os exemplos `cabana-e-mina.json` (gerado + duas regiões) e `mapa-de-exemplo.json` (disposição manual).
