# Moo-IO — Windows (servidor local Lua)

## Entrar em servidores V2 existentes

O cliente Windows permite entrar em salas LAN/VPN pelo IP/porta/código e em servidores V2 externos pelo convite `https://sala.dominio/CODIGO`. Use **Jogar → Entrar em outra sala**; quando a sala exigir login, selecione **Entrar com conta V2 (navegador)**. O aplicativo abre o navegador para cadastro/autorização PKCE; a senha nunca é digitada no jogo. Ao autorizar, o cliente recebe um token da sala e estabelece um WebSocket com os mesmos pacotes do Moo-IO.

Convites públicos exigem DNS, HTTPS/WSS, certificados válidos e o gateway V2 já configurado na VPS. O pacote Windows inclui um `node.exe` 22 isolado **somente como ponte TLS verificada para conexões de saída do cliente**, iniciado sob demanda e encerrado ao fechar o jogo. Ele não hospeda partidas e não executa o servidor Node.js do V2. Criar sala local utiliza exclusivamente o servidor Lua.

## Dificuldade das salas

- **Pacífico:** regeneração de 6 HP/s, menos animais hostis e criaturas comuns hostis deixam de perseguir espontaneamente; ideal para construção e exploração.
- **Normal:** jogo clássico, com valores e comportamento originais.
- **Difícil:** mais animais, lobos próximos compartilham alvos e tentam aproximar-se pelos flancos, além de prever o movimento do jogador.
- **Extremo:** maior pressão de inimigos, interceptação e formação de caça mais intensa.

Selecione o nível na tela **Criar minha sala**. O nível pertence à sala, não à conta do jogador. O Normal mantém todas as regras tradicionais.

## Mods de dados

Os mods do servidor local são arquivos JSON instalados em `server-lua/mods/`, sem código executável. Na criação da sala, informe os IDs separados por vírgula (por exemplo `mais-lobos,fauna-hostil`). Eles podem ajustar atributos dos animais e a população de cada tipo; os clientes convidados não precisam instalar mods para esses ajustes. Consulte `server-lua/mods/README.md`. Mods só entram em vigor ao reiniciar a sala.

**Moo-IO** é um jogo multiplayer de sobrevivência e combate em 2D, com visão de cima. Explore o mapa, reúna recursos, construa estruturas, equipe armas e enfrente animais e outros jogadores.

## O jogo

- **Exploração e sobrevivência:** percorra o mapa, encontre animais e obtenha comida, madeira e pedra.
- **Construção de bases:** use recursos para colocar paredes, armadilhas e estruturas de defesa e apoio.
- **Combate:** utilize armas corpo a corpo e de longa distância para caçar, se defender e enfrentar outros jogadores.
- **Evolução:** ganhe experiência, avance de idade e desbloqueie novos equipamentos e construções.
- **Equipamentos e loja:** escolha itens, chapéus e acessórios com diferentes efeitos durante as partidas.
- **Interface de partida:** acompanhe vida, recursos, experiência, inventário, mapa e classificação dos jogadores.

## Arquitetura desta copia

O cliente LÖVE inicia somente o servidor local Lua (`server-lua/`) ao selecionar **Criar minha sala**. Para **entrar em um V2 externo**, a ponte TLS Node 22 do próprio cliente é acionada apenas sob demanda, sem hospedar motor V2.

A pasta `server/` no checkout do GitHub permanece **somente como referencia historica Node.js para testes de paridade** e nao entra no ZIP Windows criado por `scripts/build-windows.ps1`. Essa distincao evita afirmar que o codigo-fonte historico foi apagado ou que a paridade ja e perfeita.

O build offline usa a distribuicao oficial LÖVE 11.5 Windows x64, que ja inclui LuaSocket. O empacotamento valida os arquivos essenciais do runtime e nao exige DLLs LuaSocket separadas.

**Paridade 1:1:** ainda depende de testes executaveis Node/Lua e regressao grafica de uma partida completa. Nao trate a replica como integralmente homologada ate tais verificacoes passarem.

## Salas e multiplayer

O cliente Windows permite **criar sua própria sala** com um servidor local integrado. A sala só é criada quando você escolhe **Criar minha sala** — abrir o menu **Jogar** não inicia uma partida automaticamente.

Você pode jogar em uma rede local (**LAN**) ou usar uma rede **VPN privada** já configurada para reunir amigos de outros lugares. Também é possível **entrar em uma sala existente** pelo endereço IP e código de convite.

O dono da sala pode abrir **Esc → Convidar amigos** para copiar o convite e compartilhá-lo com os participantes.

## Bots de IA

Ao criar uma sala, o anfitrião pode **ativar ou desativar bots** e escolher de **0 a 8 bots**. Por padrão, eles ficam desligados.

Os bots são controlados pelo servidor e participam do mesmo mundo dos jogadores. Eles podem explorar, procurar recursos, caçar, atacar, recuar diante de ameaças e reaparecer após serem derrotados.

## Menu durante a partida

A tecla **Esc** abre um menu sobre o mundo do jogo, com as opções **Voltar ao jogo**, **Configurações**, **Convidar amigos** e **Sair da partida**.

Nas configurações, é possível alterar a exibição da grade do mapa e o modo de tela cheia. O mundo multiplayer continua em funcionamento enquanto o menu está aberto.

Se o anfitrião escolher sair e encerrar a sala, o jogo **pede confirmação antes de desligar o servidor local e desconectar os participantes**. Um convidado pode sair sem encerrar a sala dos demais.

## Versão Windows

Esta versão reúne o **cliente para Windows**, o **servidor local de partidas** e os recursos visuais do jogo. O pacote Windows preparado inclui os componentes necessários para iniciar o cliente e hospedar salas sem baixar dependências ou converter imagens durante a abertura.
