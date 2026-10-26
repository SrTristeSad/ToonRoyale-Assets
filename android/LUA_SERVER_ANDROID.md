# Android - servidor LOCAL Lua, baseado no Windows

O botão **CRIAR SALA LUA** inicia o servidor de `windows atualização/server-lua`
em uma thread independente de LÖVE. O mesmo núcleo governa IA, bots,
combate, contas, economia, morte, estruturas, dificuldades, mods e mapas.
O APK **não** incorpora Node.js nem serviços Java para hospedar a partida.

- No GitHub Actions, `server-lua/**` é copiado diretamente da pasta Windows
  atual para o APK. Não manter um fork divergente do servidor.
- Porta 8080: jogo. Porta 8081: controle autenticado em loopback.
- Dados persistentes: `love.filesystem.getSaveDirectory()/lua-server`.
- READY só é exibido após o servidor Lua criar o mundo e abrir as portas.
- Interface mantém joystick, botões e toque. Disponibiliza quatro níveis
  de dificuldade, mapas embarcados, seleção de um mod e até oito bots.
- Seleção simultânea de vários mods e instalação de pacotes externos
  ainda requerem uma interface móvel específica.
- Android pode suspender a thread ao colocar o jogo em segundo plano; **não
  é um serviço contínuo após fechar o aplicativo**.
- Se a rede Wi-Fi não estiver identificável, LAN recua para loopback:
  permite jogar no aparelho, mas amigos não poderão acessar pelo convite.
- Não afirmar estabilidade térmica sem testes físicos prolongados.
