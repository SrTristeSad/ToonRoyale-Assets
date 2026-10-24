# Servidor Lua — migração 1:1 da versão Windows

**Objetivo:** portar o servidor local Node.js para Lua sem mudar o jogo, as regras nem o protocolo do cliente.

## Implementado e testado

- **Protocolo autenticado** em `protocol/session.lua`: io-init, IDs dinâmicos das mensagens, SHA-256/HMAC, máscaras, contador, anti-replay e ledger.
- **WebSocket RFC6455** em `net/websocket.lua`: upgrade, SHA-1, frame binário, mascaramento, comprimento, fragmentação rejeitada e limite de payload.
- **Gateway LuaSocket** em `net/host.lua`: endpoint `/ping`, parâmetros `/mooio/protocol`, status, emissão de tickets de convite de uso único em `POST /api/join`, negociação `/s/LC`, limite de jogadores, bind restrito a LAN/VPN e loop não bloqueante. O host recebe **callbacks obrigatórios** `onConnect` e `onPacket`, que serão fornecidos pelo motor do mundo quando portado.
- **Adaptador de sala** em `net/room_transport.lua`: associa cada peer WebSocket a um `Player` verdadeiro, entrega pacotes autenticados a `Room.handleInput`, preserva `null` no MessagePack, bloqueia sessões encerradas e separa limpeza pré-remoção de notificações posteriores. Pode ser configurado com os callbacks reais de `player_registry.lua`; não troca automaticamente o host Node.
- Gerador criptográfico de parâmetros do protocolo em `protocol/build.lua`.
- Testes: `tests/protocol.lua` contra os valores calculados pelo JavaScript original (`tests/reference.mjs`), `tests/websocket.lua` e um teste de HTTP + WebSocket real (`tests/host-smoke.lua` / `tests/host-smoke.py`).

## Migração do mundo (fase atual)

Implementações independentes no diretório `world/`:

- `objects.lua`: **mesmo gerador de mundo** de `server/src/moomoo/server.js::generateWorld`, com posicionamento, escalas, biome rio/neve/deserto, cactos, verificação de sobreposição, distribuição de recursos e grade de colisões.
- `collision.lua`: port da função `ObjectManager.checkCollision`, incluindo empurrão sólido, separação entre jogadores, dano e veneno, armadilhas, cura, boost, teleporte e `zIndex`. Efeitos que dependem de outros módulos recebem callbacks explícitos em vez de inventar implementações.
- `environment.lua`: fórmulas de neve, regiões secretas e limites de mapa copiadas de `effects.js` e `Player.keepInWorld`.
- `movement.lua`: port do **trecho de movimento de `Player.update`**, cobrindo aceleração, lentidão, rio/piscinas secretas, neve, acessórios, deslocamento em subpassos, colisões do mundo e com jogadores, desaceleração e limites. Recebe o equipamento real, a lista de jogadores, o relógio e o mundo via dependências obrigatórias. Não implementa sozinho regeneração, coleta, combate nem spawn.
- `snapshot.lua`: port dos métodos **`Game.syncPlayers` e `Game.syncObjects`**, incluindo os pacotes `D`, `a`, `H` e `N` (quando sandbox ilimitado), campo de anonimato, envio inicial, delta de atributos, desaparecimento/retorno do campo de visão e visibilidade de construções por time. Mantém `null` explícito no MessagePack para não deslocar os campos.

- `spawn.lua`: port do **spawn/reset de Player** — recursos iniciais, XP, arma, itens, posições, atributos especiais e uso/consumo de pontos de respawn. `objects.lua` ganhou `disableObject` e `fetchSpawnObj` para a remoção segura do objeto e broadcast `Q`.
- `vitals.lua`: port do período pré-movimento do `Player.update` — timers de vergonha, regeneração, veneno, cura por contato e rendimento periódico (moinhos/equipamento). Mantém o temporizador de 1 s separado por personagem, inclusive durante respawn.
- `health.lua`: port de `changeHealth` e `kill` do Player original — multiplicadores de armadura, defesa anti-projéteis, imunidade administrativa, estatísticas, notificações de vida/morte, recompensas e efeitos por abate. Pontuação e rede são **callbacks obrigatórios**, não mocks no servidor.
- `economy.lua`: port de `addResource`, `addWeaponXP`, `earnXP`, `changeItemCount`, `hasRes`, `useRes` e `canBuild`. Os valores vêm de `src/game/config.lua` transcrito de `shared/config.js`, sem inventar novos custos.
- `weapon_tick.lua`: parte de armas/ferramentas do `Player.update`, incluindo golpe pendente, autocoleta, recarga, consumo de munição, modificadores de alcance e velocidade, recuo de mosquete, geração de projéteis e acionamento do Turret Gear. Precisa de `Player.gather`, `hasRes`, `useRes` e `ProjectileManager.addProjectile` reais, injetados como dependências; não simula disparos por conta própria.
- `gather.lua`: port integral da lógica de `Player.gather`: coleta de árvores, pedra, arbustos, ouro, bônus de capas, demolição de construções, ressarcimento de recursos, combate corpo a corpo, escudos, empurrão, roubos, efeitos de veneno, sangramento, reflexão de dano e vampirismo. Exige os callbacks autoritativos `hitObject`, `disableObject`, `sendAnimation`, `changeHealth`, `addResource` e `earnXP`; não implementa inventário ou IA artificial substitutos.
- `build.lua`: port de `Player.buildItem`, com posicionamento real no mapa, limites, bloqueios, construções, cura por alimentos, penalização de vergonha, gastos de recursos e geração de objetos. `objects.lua` agora possui `addDynamic`, reutilizando SIDs e indexação espacial do `ObjectManager.add` original.
- `projectiles.lua`: port de `Projectile` e `ProjectileManager`, com ciclo de vida, quadro inicial, alcance, colisão de segmento/retângulo (`UTILS.lineInRect`), dano a jogadores e estruturas, defesa de escudos, reutilização de projéteis e pacotes `X`, `L`, `Q` e `Y`.
- `structures.lua`: port de `Game.updateStructures`, `Game.turretTarget` e `GameObject.update`: atualização de moinhos, temporizador de torretas, seleção de alvo, proteção por tribo, invisibilidade, disparo em direção ao inimigo e atualização visual `M`. Estruturas destruídas são retiradas de `updateObjects` como no Node.
- `game_loop.lua`: transcrição da ordem de atualização de `Game.tick`: bots, cooldowns, jogadores, projéteis, estruturas, IA, spawn de animais, líderes, placar, minimapa, estatísticas e sincronização por observador. Usa o relógio monotônico injetado e exige serviços reais para módulos ainda não portados.
- `player_constructor.lua`: port inicial do construtor `new Player` do Node, com estado da sessão pré-spawn, poderes, campos de autenticação, inventário gratuito derivado de `shared/config/store.js` e métodos `shownName`, `canSee`, `applyPowers`, `displaySkin` e `resetMoveDir`. **Ainda não substitui sozinho o Player completo**: métodos de inventário, combate, geração de nickname e operações do host continuam em integração.
- `player_update.lua`: conecta `vitals.lua`, `movement.lua` e `weapon_tick.lua` na mesma ordem de `Player.update`, incluindo a verificação de morte após dano periódico e antes da física.
- `player_identity.lua`: transcrição do preâmbulo do construtor `Player`, com IDs, equipamentos iniciais, poderes, permissões, nomes, personalização e métodos `resetMoveDir`, `addItem`, `setUserData`, `shownName`, `getData`, `applyPowers` e `displaySkin`. A filtragem exige o vocabulário integral `NAME_WORDS` original, fornecido externamente; os testes diferenciais usam um dicionário reduzido explícito apenas para verificar a lógica.
- `player.lua`: monta o jogador a partir de `Identity`, `Spawn`, `Economy`, `Health`, `Gather`, `Build`, `Snapshot` e `PlayerUpdate`, incluindo seleção de variantes, torreta, animação de ataque e pacotes. Exige mundo e configuração originais, catálogo de lojas, anticheat, emissor de pacotes e callback real de morte.
- `score.lua`: port de `Game.scoreCallback` para pontos, XP, progresso e estatísticas, com comparação direta contra Node.
- `player_registry.lua`: ciclo de sessão de `Game.addPlayer/removePlayer` com atribuição/reuso dos 50 SIDs, hash SHA-256 do endereço de conexão, campos de conta, boas-vindas `A` contendo os 15 animais originais, hooks obrigatórios de limpeza, notificações de presença, contagem e saída `E`. Inclui callbacks prontos para `RoomTransport`, sem permitir pular a autenticação ou a gestão de clãs.

- `room.lua`: **motor de sala Lua integrado (ainda sem conexão de rede ao Player real)**: executa `Game.tick`, `Player.update`, projéteis, estruturas, snapshots de jogadores/objetos/animais, líderes, placar, minimapa e estatísticas. `handleInput` entrega comandos validados somente a um jogador daquela sala. O spawn de animais pode usar `animals.lua` nativo; contas com coroas seguem exigindo o `crownOf` real, e a vitória no Crab King exige broadcast e serviços reais.
- `input.lua`: port parcial de `server/src/network/packets.js::handlePacket` para `M` (spawn), `D` (direção), `9` (movimento/parada), `e` (reset), `F` (ataque/construção), `z` (armas/itens), `K` (alternâncias), `0` (ping da rede), `S` (marcação da posição no mapa) e `U` (posição escolhida no mapa tático Android). Preserva `mapPingTime`, alcance e restrições por tribo, e exige anticheat real. **Demais pacotes exigem um handler autoritativo**, não são aceitos silenciosamente.
- `social_sync.lua`: ports fiéis de `Game.syncAnimals` (pacote `I`), `sendMinimap` (`7`), `updateLeaders`, `sendLeaderboard` (`G`) e `sendStats` (`F`). Inclui jogadores anônimos, tribos, ocultação de condenados, coroas, permissões administrativas, rastreamento de animais visíveis e estatísticas, com a mesma ordenação e payloads do Node.
- `animal_types.lua`: todos os **15 tipos de animais** convertidos campo por campo de `server/src/moomoo/modules/aiManager.js::AI_TYPES`; o índice Lua é explicitamente o SID do tipo no cliente.
- `animal_health.lua`: port de `AI.changeHealth`: dano, imunidade do Crab King submerso, reação a ataques, veneno, registro de dano, morte, pontuação, drops, reaparecimento e desaparecimento de animais administrativos. Depende dos serviços de rede/pontuação reais; não inventa ouro ou recursos.
- `animal_rewards.lua`: estatísticas de caça e `animalKills` de `Game.onAnimalKilled` e multiplicadores originais da Cow Cape (1,5× pontos e comida ao abater vacas). Exige um callback completo de vitória para o Crab King, sem conceder coroas incompletas.
- `crab_king.lua`: port completo dos métodos de `AI` exclusivos ao Crab King: contenção no mapa secreto, quatro estados de mergulho, seleção de invasores, movimentação, efeito `W`, impacto `J`, quatro golpes com telegráfico (SPLASH, GEYSER, SLAM, CLAW), tempo de recarga, seleção aleatória e comando administrativo de ataque forçado.
- `crab_rewards.lua`: port de `Game.onAnimalKilled` para a vitória do chefe, exigindo 5% de participação em danos para recompensar outros jogadores, Crab Shell (chapéu 61), contagem de `bossKills`, `crabKillers`, anúncio `6` e evento interservidores. A ordem das concessões usa a sequência real de `Map` de autores do dano original, e é preservada em `ai.damageOrder`.


- `ai.lua`: port de `AI.init` e da atualização de **animais comuns**, cobrindo temporizadores de reaparecimento, veneno, perseguição, fuga, rotação, subpassos físicos, colisões, golpes e limite do mapa. **O Crab King não usa essa IA como substituta**: seus métodos exclusivos são implementados por `crab_king.lua` e incorporados a instâncias reais de `AI`.
- `animals.lua`: port de `AiManager.spawn`, `Game.animalPosition` e `Game.ensureAnimals`, com posições, biomas, reuso de SIDs e densidade de spawn originais. Usa agora a vida/morte Lua nativa quando recebe serviços reais `score` e `send`, com a contabilidade de caça e Cow Cape; também permite um serviço `health` autoritativo externo. O Crab King é habilitado apenas se a sala possuir os serviços verdadeiros de rede, pontuação, comunicação de vitória e a mesma tabela de vencedores do `Game`; os métodos de combate e mergulho já estão integrados.






Testes diferenciais contra **código original Node.js executado como referência**:
`world-reference.mjs` extrai a função real `generateWorld` de `server.js` e executa `ObjectManager` original. `world-reference.lua` executa o módulo Lua com a mesma semente de teste. Verificação de cada SID, tipo, posição (seis casas decimais), escala, grade, cacto, dano, além de consultas de posicionamento e células vizinhas. As sementes testadas são `1`, `42`, `12345` e `4294967295`.

`collision-reference.mjs/.lua` comparam casos sólidos, afastados, entre jogadores, armadilhas, impulso, cura, dano e teleporte. `environment-reference.mjs/.lua` comparam bordas, piscinas secretas e modificadores de neve.

`movement-reference.mjs/.lua` comparam **27 cenários por três ticks (81 snapshots)**: deslocamento, inércia, correnteza, neve, equipamentos, limites, pedra, armadilha, impulso, cura e colisões entre jogadores. O teste executa o trecho da implementação original `Player.update` do Node por extração da função, e compara o estado produzido em Lua. Execução automática na branch `main` por `.github/workflows/windows-lua-parity.yml` do repositório **ToonRoyale-Assets**, sem tocar o repositório de origem.

`snapshot-reference.mjs/.lua` executa os métodos originais de sincronização e testa três atualizações consecutivas, comprovando a mesma ordem e conteúdo de pacotes `D`/`a`/`H` em Lua. O teste também verifica anonimizacão, troca de equipamento e saída/entrada do campo de visão.

As novas suítes diferenciais também comparam:
- `weapon-reference.mjs/.lua`: 15 cenários × 3 ticks = **45 comparações** do trecho real de armas no `Player.update` Node.
- `gather-reference.mjs/.lua`: **36 cenários** com a função real `Player.gather`, `ObjectManager` e `GameObject` Node, incluindo ataques contra animais, efeitos, edifícios, colher recursos e ausência de duplicação em múltiplas células de colisão. Os valores das armas utilizados nos fixtures são conferidos com `shared/config/items.js` original.

- `build-reference.mjs/.lua`: **16 cenários** com a função original `Player.buildItem`, inclusive estruturas, comida, rio, colisões e reciclagem de objetos.
- `projectile-reference.mjs/.lua`: **20 cenários × 3 ticks (60 snapshots)** executando `Projectile`/`ProjectileManager` originais, verificando estado, colisões e pacotes de rede.
- `structures-reference.mjs/.lua`: **20 cenários × 3 ticks (60 snapshots)** com `Game.updateStructures`, `Game.turretTarget` e `GameObject.update` reais.

- `game-loop-reference.mjs/.lua`: **4 perfis de sala × 6 ticks = 24 snapshots**, extraídos diretamente do método original `Game.tick`.
- `input-reference.mjs/.lua`: **33 cenários de entrada** comparados com o `handlePacket` Node original, incluindo ping, marcações no mapa e envio apenas para aliados.
- `social-reference.mjs/.lua`: **4 perfis × 3 atualizações = 12 snapshots** comparados com métodos originais do Node, incluindo `Game.crownOf` e privacidade de anonimato.
- `ai-reference.mjs/.lua`: **20 situações × 3 ticks = 60 snapshots** de `AI.update` original, cobrindo animais pacíficos, touros e lobos, perseguição, respawn e dano periódico.
- `animal-manager-reference.mjs/.lua`: valida os **15 tipos** completos do `AI_TYPES`, cálculo de local de nascimento, plano de população, reuso de SIDs e `spawnDelay`.
- `room-animals-smoke.lua`: executa vaca e lobo nativos no `Room.tick`, sem serviços inventados, e impede o Crab King de entrar sem callbacks reais de mergulho e combate.
- `animal-health-reference.mjs/.lua`: **19 situações de dano/morte** executadas com `AI.changeHealth` do Node original.
- `crab-reference.mjs/.lua`: **16 situações × 3 ticks (48 snapshots)** executando `AI.update` original com Crab King, mergulhos, gêiseres, ondas de garra, impacto em área, telegráficos e colisão da área secreta.
- `crab-rewards-reference.mjs/.lua`: **12 casos** executando `Game.onAnimalKilled` original para comparar elegibilidade de participantes, Crab Shell, estatísticas, notificações e anúncios.
- `room-crab-smoke.lua`: teste integrado `Room.tick` → spawn boss → `W` → `J` → imunidade no mergulho → morte → Crab Shell/4000 pontos/`bossKills` → anúncio e evento.

- `animals-health-smoke.lua`: testa a rota completa `Room` → `AiManager` → `AI.changeHealth` → recompensas e estatísticas, incluindo o bônus da Cow Cape e a ausência de drops em animais administrativos.
- `room-transport-smoke.lua`: verifica callbacks do Host com Room real, criação de jogador por serviço obrigatório, envio seguro, alinhamento de campos MessagePack, rejeição de peers desconhecidos e remoção ao desconectar.
- `player-identity-reference.mjs/.lua`: **18 casos** usando preâmbulo e métodos de identidade extraídos diretamente de `Player` no Node, incluindo anon, nome, equipamento gratuito, troca de item e aparência.
- `player-score-reference.mjs/.lua`: **20 variantes de arma + 8 cenários de pontuação**, comparados com `Player.variant` e `Game.scoreCallback` originais.
- `player-full-smoke.lua`: percorre `Player.new` → pacote `M` → spawn → `Game.tick` → movimento, XP, construção, combate e animações.
- `player-registry-smoke.lua`: verifica `Host`/`RoomTransport` → construtor Lua real → welcome `A` → spawn e comandos → saída, metadados de conta, hash IP, ordem de limpeza, reutilização de SID e pacote `E`.


- `player-constructor-reference.mjs/.lua`: **3 estados pré-spawn** extraídos do trecho original do construtor Node. Compara campos, poderes, chapéus e acessórios gratuitos.
- `player-methods-reference.mjs/.lua`: **10 cenários** executam diretamente cinco métodos do `Player` original, comparando visão, poderes, privacidade, chapéus e direção com Lua.
- `player-update-reference.mjs/.lua`: **18 situações × 3 ticks = 54 snapshots**, executando o método `Player.update` **inteiro**, incluindo a parada por morte durante efeitos periódicos.
- `room-smoke.lua`: valida uma sala integrada com jogador, animal, projétil e construção; emite `D`/`a`/`H`/`X`/`I`/`7`/`G`/`F`, recebe comandos da sala e mantém obrigatórios os serviços ainda não portados.

Testes novos executam as funções originais do Node.js, comparando os mesmos efeitos na implementação Lua: `spawn-reference` (8 cenários), `vitals-reference` (12 cenários com múltiplos ticks), `health-reference` (16 cenários de danos, morte e recompensas) e `economy-reference` (19 cenários de recursos, XP e custos). A suíte GitHub Actions roda automaticamente na branch `main` do ToonRoyale-Assets.

**Integração parcial de sala confirmada:** jogador Lua composto, movimento, construções, combate, economia, animais e Crab King já executam em `Room.tick`; `player_registry.lua` conecta sessões autenticadas pelo convite do Host aos jogadores, com SID e saída testados. O host ainda precisa de implantação conjunta com todos os serviços reais de moderação de nomes, anticheat, loja, clãs, presença e persistência, além dos pacotes faltantes. **O servidor local funcional continua sendo Node.js** até a paridade jogável de ponta a ponta.

## Limites — NÃO é o servidor completo

A infraestrutura de rede e um núcleo de sala Lua funcionam isoladamente, com testes de paridade contra o Node. **Ainda não existe uma instalação Lua completa e publicável para substituir o Node.js**: o construtor já existe e foi testado, mas faltam catálogo completo de produção, vocabulário `NAME_WORDS`, anticheat definitivo, handlers de pacotes e serviços de contas, tribos, bots e persistência.

Pendente: integrar `player_registry.lua` com os serviços verdadeiros e com `net/host.lua` em uma instalação executável; contas/autorização V2, `NAME_WORDS` completo, catálogo e anticheat de produção, endpoints HTTP restantes, **handlers restantes de entrada** (upgrades, loja, clãs, chat, moderação), bots, clãs, persistência e testes reais do cliente contra o servidor Lua. A API Lua ainda admite apenas guest em LAN/VPN e não substitui a autenticação V2.

**O jogo Windows continua usando seu servidor local Node.js original.** Não foi removida nenhuma dependência, nenhum arquivo de servidor original foi alterado e o cliente não foi apontado para um mundo Lua incompleto. Isso evita regressões no jogo que já funciona.

## Como executar os testes

A partir de `windows atualização/`:

```sh
node server-lua/tests/reference.mjs > server-lua/tests/reference-fixtures.txt
lua5.4 server-lua/tests/protocol.lua server-lua/tests/reference-fixtures.txt
lua5.4 server-lua/tests/websocket.lua
lua5.4 server-lua/tests/room-smoke.lua
lua5.4 server-lua/tests/room-animals-smoke.lua
lua5.4 server-lua/tests/room-crab-smoke.lua
lua5.4 server-lua/tests/animals-health-smoke.lua
lua5.4 server-lua/tests/room-transport-smoke.lua
lua5.4 server-lua/tests/player-full-smoke.lua
lua5.4 server-lua/tests/player-registry-smoke.lua
node server-lua/tests/social-reference.mjs > /tmp/social-node.txt
lua5.4 server-lua/tests/social-reference.lua > /tmp/social-lua.txt
diff -u /tmp/social-node.txt /tmp/social-lua.txt
node server-lua/tests/game-loop-reference.mjs > /tmp/game-loop-node.txt
lua5.4 server-lua/tests/game-loop-reference.lua > /tmp/game-loop-lua.txt
diff -u /tmp/game-loop-node.txt /tmp/game-loop-lua.txt
```

Para testar a camada de rede separadamente, instale LuaSocket para o interpretador de testes:

```sh
lua5.4 server-lua/tests/host-smoke.lua &
python3 server-lua/tests/host-smoke.py
```

O gateway é um componente do futuro servidor, **não uma alternativa jogável ao Node neste momento**.

## Paridade antes da troca

A migração do host em `src/net/mooio_host.lua` só poderá ocorrer após testes reais cliente↔Lua para todas as famílias de pacotes e as mesmas regras de `shared/config.js`: entrada, mundo, coleta, economia, objetos, combate, animais, bots, tribos, morte, respawn e desconexão. Não inventar valores nem substituir funcionalidades originais por simulações.
