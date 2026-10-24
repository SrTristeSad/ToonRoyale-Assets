# Migração do servidor local Node.js para Lua

**Meta:** preservar os pacotes, os valores e o comportamento do servidor original, não criar um jogo diferente.

## Estado atual

- Implementado: metade **servidor** do transporte MessagePack autenticado (handshake `io-init`, tabelas por sessão, mixer, HMAC-SHA256, máscaras, sequência, ledger e pacotes de resposta).
- Reutiliza o protocolo Lua existente do cliente (`src/protocol/`) para evitar divergências.
- O código do Node.js continua sendo a **referência executável** e o servidor ativo enquanto a migração não atingir paridade.
- Não implementado em Lua ainda: endpoints HTTP, servidor WebSocket, emissão/consumo de tickets, contas, mundo autoritativo, movimento, colisões, recursos, construções, combate, animais, bots, clãs, ranking, administração e persistência.
- **Não anuncie nem configure esta etapa como servidor jogável ou 1:1.** Nenhum fallback oculto para Node deve ser chamado de servidor Lua.

## Protocolo

A implementação está em `protocol/session.lua`. As funções espelham `server/src/protocol/session.js`.

Testes: `lua5.4 server-lua/tests/protocol.lua` a partir da pasta `windows atualização`. Em uma distribuição LÖVE, as mesmas dependências podem ser carregadas pelo LuaJIT.

## Critério para mudar o host local

Somente substituir `src/net/mooio_host.lua` quando houver testes reais cliente↔Lua com os **mesmos** pacotes/estados do Node e equivalência de spawn, movimento, construção, colisões, combate, economia, animais, bots, eventos, clãs, morte/respawn e desconexão. Cada divergência deve ser tratada antes de migrar a função. Os parâmetros devem vir de `shared/config.js`, não de valores inventados.
