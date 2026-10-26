# Migração Windows -> Android

**Destino:** `ToonRoyale-Assets/android` (branch de integração até validação).
**Origem inicial:** `SrTristeSad/Moo-IO/android`.
**Fonte do núcleo atual:** `ToonRoyale-Assets/windows atualização`.

## Implementado

1. Cópia integral dos 256 arquivos originais do Android, incluindo assets,
   `native/`, controles de toque, testes e configuração LÖVE.
2. Atualização dos módulos neutros de plataforma (estado de mundo, catálogo de
   mapas, renderização, painel, HUD, animações, morte e protocolo V2).
3. Mantidos `src/mobile/`, `src/input.lua`, o menu Android e controles por toque,
   sem WASD nem launcher Windows. A hospedagem agora usa o mesmo LOCAL
   `windows atualização/server-lua` em thread LÖVE separada.
4. Implementação de transições entre espaços na sessão móvel e preservação
   da última posição da morte na reconexão para a mesma sala.
5. Renascimento na mesma conexão (anfitrião e convidado) para não descartar
   estado persistido na sala pelo servidor.
6. Bot count 0..8 atravessa Lua, controle localhost autenticado, Intent Android
   e variável de ambiente `MOO_IO_BOT_COUNT` do servidor Node.
7. Navegador de salas V2 real, com seleção, salas privadas e login via browser.
8. CI: verificação sintática Lua, testes de ciclo de vida, toque e diretório;
   build APK da fonte atual do servidor JavaScript na pasta Windows.

## Servidor LOCAL atualizado

O APK Android agora carrega diretamente `windows atualização/server-lua`.
O host Lua é executado em thread independente, sem Node.js no APK.
Opções de dificuldade, mapas instalados e um mod por sala estão no menu
de toque. Os arquivos persistentes ficam no diretório privado da aplicação.

## Pendências / não alegar paridade 1:1 ainda

- Validar a thread, LuaSocket, inicialização de partidas e conexões reais em
  aparelhos Android físicos ou emuladores (compilar não equivale a jogar).
- Seleção simultânea de mods e instalação de pacotes pelo usuário no celular.
- Hospedagem contínua com tela apagada: LÖVE pode ser suspenso pelo Android.
- Testar jogo com amigos pela mesma Wi-Fi e pelo modo VPN.
- Medir memória, bateria, aquecimento e estabilidade em partidas longas.
- Validar clientes V2 com autenticação e comparação visual no GLES.
