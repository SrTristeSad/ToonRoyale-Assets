# Migração Windows -> Android

**Destino:** `ToonRoyale-Assets/android` (branch de integração até validação).
**Origem inicial:** `SrTristeSad/Moo-IO/android`.
**Fonte do núcleo atual:** `ToonRoyale-Assets/windows atualização`.

## Implementado

1. Cópia integral dos 256 arquivos originais do Android, incluindo assets,
   `native/`, controles de toque, testes e configuração LÖVE.
2. Atualização dos módulos neutros de plataforma (estado de mundo, catálogo de
   mapas, renderização, painel, HUD, animações, morte e protocolo V2).
3. Mantidos `src/mobile/`, `src/input.lua`, o menu Android e seu host
   Node nativo, sem importar WASD, controle de PC ou launcher Windows.
4. Implementação de transições entre espaços na sessão móvel e preservação
   da última posição da morte na reconexão para a mesma sala.
5. Renascimento na mesma conexão (anfitrião e convidado) para não descartar
   estado persistido na sala pelo servidor.
6. Bot count 0..8 atravessa Lua, controle localhost autenticado, Intent Android
   e variável de ambiente `MOO_IO_BOT_COUNT` do servidor Node.
7. Navegador de salas V2 real, com seleção, salas privadas e login via browser.
8. CI: verificação sintática Lua, testes de ciclo de vida, toque e diretório;
   build APK da fonte atual do servidor JavaScript na pasta Windows.

## Pendências / não alegar paridade 1:1 ainda

- O servidor Lua de `windows atualização/server-lua` **não** é iniciado
  no Android. Suas dificuldades pacífico/difícil/extremo, mods e geração de
  mapas customizados não foram adaptados ao processo Node Android.
- Confirmar no aparelho transições de mapas, text input e V2 HTTPS autenticado.
- Validar assinatura do APK, instalação e hospedagem real no emulador.
- Comparar arte/renderização sob GLES com Windows e testar desempenho mobile.
- Não substituir os controles móveis pelos periféricos de PC.

## Atualização do servidor embarcado

`.github/workflows/android-host-apk.yml` cria temporariamente
`windows/` a partir de `windows atualização/` no runner, gera
`server/src/offline.mjs` e incorpora o bundle no APK. Não é copiado um
snapshot estático do servidor para a pasta Android.

**Fonte original Moo-IO não modificada.**
