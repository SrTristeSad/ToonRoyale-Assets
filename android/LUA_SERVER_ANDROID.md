# Android: servidor de gameplay Lua portado do Windows

O código canônico do servidor local está nesta pasta em
`android/server-lua/`, copiado da versão Windows. O APK empacota
esse conteúdo diretamente, sem um segundo motor Node.js.

`src/mobile/lua_host_thread.lua` inicializa
`require("server-lua.local_server")` em uma thread LÖVE, ligada a
`src/net/mooio_host.lua` por canais. READY só ocorre depois de
`server:start()`; o cliente entra no jogo via WebSocket original.

- Jogo: porta 8080; API de controle: 8081.
- Arquivos persistentes: diretório privado de save da aplicação.
- Dificuldades: pacífico, normal, difícil e extremo.
- Conteúdo: mapas JSON, mods JSON, espécies e animações da versão Windows.
- Bots: entre zero e oito.
- Criação local: explícita, via **Criar minha sala**.
- Servidores V2: apenas conexões externas seguras; TLS Java do Android.
- Controles de toque: mantidos no módulo móvel anterior sem alterações.

O Android pode suspender ou encerrar a thread em segundo plano. Esta
integração não promete servidor ativo quando o aplicativo está fechado.
