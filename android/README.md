# Moo-IO Android — núcleo do Windows com controles touchscreen preservados

Esta versão Android é uma adaptação do jogo desenvolvido em
[`windows atualização`](../windows%20atualiza%C3%A7%C3%A3o/).
A **lógica de gameplay, mapas, mods, gráficos, menus de salas e protocolo**
acompanham essa versão Windows. As adaptações indispensáveis para Android
continuam separadas.

## O que foi substituído pela versão Windows

- `server-lua/`: servidor local autoritativo, geração de mundo, combate,
  animais, bots, progressão, estruturas, economia, inventário, contas,
  controle anticheat, mapa personalizado, mods e animações.
- `src/game/mooio_home.lua`: fluxo Windows de criação e seleção de sala,
  escolha de mapa, ativação/desativação de múltiplos mods, dificuldade,
  bots e navegador de servidores V2.
- `src/game/mooio_pause.lua`: menu da versão Windows, com informações do
  mapa e confirmação antes de encerrar uma sala.
- `assets/` e demais módulos neutros de `src/`: arte e recursos da
  versão Windows, inclusive suporte a espécies e animações opcionais.
- `main.lua`: os fluxos da versão Windows que precisam de integração no
  Android, incluindo o renascimento na mesma conexão, retorno após morte
  e informações de mapa; a entrada Android foi preservada.

## O que NÃO deve ser substituído

- `src/mobile/controls.lua`: joystick de movimento, botão **ATACAR**
  que também controla a mira, quatro atalhos, inventário paginado, AUTO,
  chat, mapa, marcações, TOP10 e pausa.
- `src/mobile/slots.lua` e `src/mobile/performance.lua`.
- `src/mobile/lua_host_thread.lua` e
  `src/net/mooio_host.lua`: executam o servidor Lua em thread própria
  no mesmo processo LÖVE, sem servidor Node embutido.
- `native/MooIOActivity.java` e `native/MooIOTlsBridge.java`:
  entrada Android e conexão TLS autenticada com V2 externo.
- `conf.lua`: janela/tela do Android.

**Não existe servidor Node.js para hospedar salas no APK.**
A sala local usa a mesma implementação Lua da versão Windows. V2 é
sempre um servidor externo. A ponte TLS no Android permanece Java,
sem processo Node.

O APK copia `android/server-lua` diretamente; não o substitui
secretamente por código da pasta Windows durante a compilação.

## Como testar

O workflow `android-host-tests.yml` verifica código Lua, protocolos e
controles originais, e faz testes de gameplay com os fixtures da versão
Windows. O workflow `android-host-apk.yml` compila o
`Moo-IO-Android-Beta-Instalavel.apk` em LÖVE Android 11.5a.

**Limitações reais:** compilação e testes automatizados não demonstram
temperatura, estabilidade de longa duração nem multiplayer em aparelhos
físicos. O Android pode suspender a thread da sala ao sair de primeiro plano.
Salas em Wi-Fi/VPN precisam ser confirmadas nos aparelhos dos participantes.


## Android 0.5.3: interface flutuante sobre nucleo Lua Windows

- A logica da versao **`windows atualização/`** continua como base: o servidor autoritativo e Lua (`android/server-lua/`), sem Node nem WebView; salas LAN/VPN, servidor V2 externo, mapas, mods, dificuldade, bots e arte existentes sao preservados.
- **Controles touchscreen atuais**: analogico esquerdo livre para movimento, analogico direito flutuante para mira (arrasto curto) e ataque (arrasto longo); a zona central de mira nao ataca acidentalmente.
- **HUD**: barra horizontal rolavel com os itens reais desbloqueados; botoes Loja, Cla permanente, Tribo temporaria, chat, ranking, mapa, pings, pausa, AUTO e trava da mira.
- **Personalizacao**: Menu principal > Configuracoes > Controles e interface; durante a partida, Pausa > Configuracoes > Controles Touch. Tamanho geral, opacidade, tamanho individual dos analogicos e zona morta sao salvos em `mooio-hud-v1.cfg` (arquivo privado do aplicativo).
- No Android os antigos botoes desktop de Loja/Tribo e barra de inventario desktop nao sao desenhados sobre o HUD touch. As interacoes seguem usando pacotes da partida Lua real.
- Foi preservado o historico Git do Android anterior na branch base; nenhuma exclusao em massa do servidor Lua ou conteudos mais recentes do Windows foi feita.
