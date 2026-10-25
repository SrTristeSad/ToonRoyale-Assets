# Migração Windows para Lua — três etapas de aceitação

**Alvo exclusivo:** servidor local iniciado pela opção **Criar minha sala** no Windows, `scripts/start-server.ps1` → `server/src/offline.mjs` (fonte `server/src/index.js`, modo padrão sem V2).

Esta pasta é a cópia de trabalho. O código em `SrTristeSad/Moo-IO` e
`windows atualização/server/` permanece intacto. Não trocar o servidor
padrão até os três critérios de saída serem verificáveis.

## 1. Paridade funcional: EM ANDAMENTO

Implementado e coberto por testes diferenciais Node/Lua:
- Host autenticado, protocolo e anticheat local
- Mundo, jogador, armas, recursos, estruturas, IA e Crab King
- Catálogos completos e filtro de nomes
- Pacotes H (evolução), c (compra/equipamento)
- Tribos: criação, entrada, pedido, aprovação, expulsão, saída e remoção
- Chat 6: filtro, cooldown, mensagens e shadowban
- Bots 0–8 da sala LOCAL: decisões originais, cura, caça, coleta e respawn; SIDs reais e exclusão da contagem de jogadores humanos
- Limpeza de construções: `ObjectManager.removeAllItems` original no encerramento de sessão
- Modo anônimo I para contas registradas

Evidências na CI: `tests/equipment-reference.*` (33 casos),
`tests/tribes-reference.*` (26), `tests/chat-reference.*` (39),
`tests/anon-reference.*` (18) e
`tests/gameplay-final-smoke.lua` (dois jogadores com sistemas integrados).

**Ainda faltam** para equivalência total:
- Pacotes e ações de moderação, estatísticas de perfil, administração
  e quaisquer handlers de `packets.js` ainda entregues a `onUnportedPacket`
- Serviços de contas e autorização do servidor local, clãs de contas, restrições e permissões
- Persistência de vida, progresso, sanções, denúncias e presença
- Bots já portados de `server/src/mooio/bots.js` e ligados ao `Player` real; falta validação de partida completa e aprovação da comparação diferencial
- Integração de todos os subsistemas reais sem callbacks substitutos de teste

Saída: todos os pacotes conhecidos com regras originais em Lua,
sem `onUnportedPacket` para funcionalidades de produção, testes diferenciais
e suíte de regressão completos.

## 2. Servidor Lua executável para Windows: EXPERIMENTAL

Unir `Room`, `PlayerRegistry`, `RoomTransport`, `Host`, os serviços
de conta/moderação/clãs, salvamento, bots e a sala real em um inicializador.
Distribuir dependências junto com o pacote Windows, sem downloads ou
comandos de terminal para o usuário e mantendo opção de rollback Node.

Saída: iniciar, anunciar e encerrar salas; autenticar; desconectar/reconectar;
carregar e salvar progresso; funcionar isoladamente na distribuição Windows.

## 3. Paridade 1:1 com o cliente real: PENDENTE

Verificar com o mesmo cliente Windows, comparando Node vs Lua:
- Criar nova partida, entrar, movimentar, construir, comprar, equipar e lutar
- Tribos/clãs, chat, moderar, morrer, renascer, sair e retornar
- Bots/animais, placar, conta e progressão persistente
- LAN e VPN, múltiplos clientes, pacotes malformados, latência e estabilidade

Saída: nenhum erro conhecido na equivalência visual/de mecânica/protocolo
nos cenários originais; somente então configurar Lua como padrão.

**Estado global:** o Node.js copiado segue sendo a versão jogável de produção.
Testes unitários e de integração Lua NÃO substituem a prova de uma partida
real com o cliente Windows.
