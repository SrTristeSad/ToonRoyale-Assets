# Servidor Lua — migração 1:1 da versão Windows

**Objetivo:** portar o servidor local Node.js para Lua sem mudar o jogo, as regras nem o protocolo do cliente.

## Implementado e testado

- **Protocolo autenticado** em `protocol/session.lua`: io-init, IDs dinâmicos das mensagens, SHA-256/HMAC, máscaras, contador, anti-replay e ledger.
- **WebSocket RFC6455** em `net/websocket.lua`: upgrade, SHA-1, frame binário, mascaramento, comprimento, fragmentação rejeitada e limite de payload.
- **Gateway LuaSocket** em `net/host.lua`: endpoint `/ping`, parâmetros `/mooio/protocol`, status, emissão de tickets de convite de uso único em `POST /api/join`, negociação `/s/LC`, limite de jogadores, bind restrito a LAN/VPN e loop não bloqueante. O host recebe **callbacks obrigatórios** `onConnect` e `onPacket`, que serão fornecidos pelo motor do mundo quando portado.
- Gerador criptográfico de parâmetros do protocolo em `protocol/build.lua`.
- Testes: `tests/protocol.lua` contra os valores calculados pelo JavaScript original (`tests/reference.mjs`), `tests/websocket.lua` e um teste de HTTP + WebSocket real (`tests/host-smoke.lua` / `tests/host-smoke.py`).

## Limites — NÃO é o servidor completo

A infraestrutura de rede Lua funciona isoladamente, mas **a lógica de partida ainda precisa ser portada**. Não existe equivalência 1:1 do mundo neste estágio.

Pendente: contas/autorização V2, outros endpoints HTTP, simulação do mundo, spawn completo, movimento e colisões, construções, coleta, economia, armas, tiros, PvP, animais e IA, bots, clãs, loja, placar, persistência, moderação e anti-cheat de gameplay. A API Lua ainda admite apenas guest em LAN/VPN e não substitui a autenticação V2.

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
