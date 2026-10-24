# Servidor Lua — migração 1:1 da versão Windows

**Objetivo:** portar o servidor local Node.js para Lua sem mudar o jogo, as regras nem o protocolo do cliente.

## Implementado e testado

- **Protocolo autenticado** em `protocol/session.lua`: io-init, IDs dinâmicos das mensagens, SHA-256/HMAC, máscaras, contador, anti-replay e ledger.
- **WebSocket RFC6455** em `net/websocket.lua`: upgrade, SHA-1, frame binário, mascaramento, comprimento, fragmentação rejeitada e limite de payload.
- **Gateway LuaSocket** em `net/host.lua`: endpoint `/ping`, parâmetros `/mooio/protocol`, status, emissão de tickets de convite de uso único em `POST /api/join`, negociação `/s/LC`, limite de jogadores, bind restrito a LAN/VPN e loop não bloqueante. O host recebe **callbacks obrigatórios** `onConnect` e `onPacket`, que serão fornecidos pelo motor do mundo quando portado.
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



Testes diferenciais contra **código original Node.js executado como referência**:
`world-reference.mjs` extrai a função real `generateWorld` de `server.js` e executa `ObjectManager` original. `world-reference.lua` executa o módulo Lua com a mesma semente de teste. Verificação de cada SID, tipo, posição (seis casas decimais), escala, grade, cacto, dano, além de consultas de posicionamento e células vizinhas. As sementes testadas são `1`, `42`, `12345` e `4294967295`.

`collision-reference.mjs/.lua` comparam casos sólidos, afastados, entre jogadores, armadilhas, impulso, cura, dano e teleporte. `environment-reference.mjs/.lua` comparam bordas, piscinas secretas e modificadores de neve.

`movement-reference.mjs/.lua` comparam **27 cenários por três ticks (81 snapshots)**: deslocamento, inércia, correnteza, neve, equipamentos, limites, pedra, armadilha, impulso, cura e colisões entre jogadores. O teste executa o trecho da implementação original `Player.update` do Node por extração da função, e compara o estado produzido em Lua. Execução automática na branch `main` por `.github/workflows/windows-lua-parity.yml` do repositório **ToonRoyale-Assets**, sem tocar o repositório de origem.

`snapshot-reference.mjs/.lua` executa os métodos originais de sincronização e testa três atualizações consecutivas, comprovando a mesma ordem e conteúdo de pacotes `D`/`a`/`H` em Lua. O teste também verifica anonimizacão, troca de equipamento e saída/entrada do campo de visão.

As novas suítes diferenciais também comparam:
- `weapon-reference.mjs/.lua`: 15 cenários × 3 ticks = **45 comparações** do trecho real de armas no `Player.update` Node.
- `gather-reference.mjs/.lua`: **36 cenários** com a função real `Player.gather`, `ObjectManager` e `GameObject` Node, incluindo ataques contra animais, efeitos, edifícios, colher recursos e ausência de duplicação em múltiplas células de colisão. Os valores das armas utilizados nos fixtures são conferidos com `shared/config/items.js` original.

Testes novos executam as funções originais do Node.js, comparando os mesmos efeitos na implementação Lua: `spawn-reference` (8 cenários), `vitals-reference` (12 cenários com múltiplos ticks), `health-reference` (16 cenários de danos, morte e recompensas) e `economy-reference` (19 cenários de recursos, XP e custos). A suíte GitHub Actions roda automaticamente na branch `main` do ToonRoyale-Assets.

**Ainda não está conectado ao jogo:** integração autoritativa do ciclo completo do jogador, construção, física completa dos projéteis após disparo, IA dos NPCs, objetos edificáveis, bots, tribos e endpoints de autenticação seguem pendentes. Até eles serem portados e testados, **o servidor local funcional continua sendo Node.js**.

## Limites — NÃO é o servidor completo

A infraestrutura de rede Lua funciona isoladamente, mas **a lógica de partida ainda precisa ser portada**. Não existe equivalência 1:1 do mundo neste estágio.

Pendente: contas/autorização V2, outros endpoints HTTP, simulação do mundo, conexão do spawn e dos demais módulos ao loop de partida, construções, coleta, economia, armas, tiros, PvP, animais e IA, bots, clãs, loja, placar, persistência, moderação e anti-cheat de gameplay. A API Lua ainda admite apenas guest em LAN/VPN e não substitui a autenticação V2.

**O jogo Windows continua usando seu servidor local Node.js original.** Não foi removida nenhuma dependência, nenhum arquivo de servidor original foi alterado e o cliente não foi apontado para um mundo Lua incompleto. Isso evita regressões no jogo que já funciona.

## Como executar os testes

A partir de `windows atualização/`:

```sh
node server-lua/tests/reference.mjs > server-lua/tests/reference-fixtures.txt
lua5.4 server-lua/tests/protocol.lua server-lua/tests/reference-fixtures.txt
lua5.4 server-lua/tests/websocket.lua
```

Para testar a camada de rede separadamente, instale LuaSocket para o interpretador de testes:

```sh
lua5.4 server-lua/tests/host-smoke.lua &
python3 server-lua/tests/host-smoke.py
```

O gateway é um componente do futuro servidor, **não uma alternativa jogável ao Node neste momento**.

## Paridade antes da troca

A migração do host em `src/net/mooio_host.lua` só poderá ocorrer após testes reais cliente↔Lua para todas as famílias de pacotes e as mesmas regras de `shared/config.js`: entrada, mundo, coleta, economia, objetos, combate, animais, bots, tribos, morte, respawn e desconexão. Não inventar valores nem substituir funcionalidades originais por simulações.
