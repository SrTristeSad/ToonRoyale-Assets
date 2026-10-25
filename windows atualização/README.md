# Moo-IO — Windows (servidor local Lua)

## Menu inicial e tela de morte

A tela inicial tem estilo de menu classico de PC: logo original Moo-IO centralizado,
fundo animado do proprio mundo, botoes grandes de jogar, servidores, opcoes e
sair. O cliente continua usando a navegacao nativa de teclado, mouse e gamepad.

Quando um **visitante morre na sala de um amigo**, a animacao original de tres
segundos ocorre sobre a ultima area explorada. Em seguida, aparece uma escolha:
**Voltar a partida** envia o pedido de renascimento pela conexao autenticada
existente e aguarda confirmacao do servidor; **Sair da sala** desconecta
somente o visitante, preservando a sala do anfitriao. Teclas Enter/R e Esc,
alem de A/B no gamepad, controlam a escolha.

Quando o **anfitriao morre**, o fluxo original de retorno ao menu e mantido,
mas o fundo mostra o ultimo local da morte em vez de recentralizar o mundo.
Sair do cliente com uma sala ainda aberta continua exigindo confirmacao.

## Inteligencia de animais e bots

As partidas usam decisoes autoritativas no **servidor Lua**, sem IA calculada
no cliente. Animais passivos procuram fugir de humanos proximos e predadores;
animais hostis reavaliam os alvos mais rapidamente e tentam contornar
paredes de cavernas e limites do mapa. O nivel de dificuldade ainda
controla velocidade/agressividade e os comportamentos de alcateia.

Bots aparecem com nomes normais (Lince, Ari, Raposa etc.), sem prefixo
"Bot". Eles escolhem recursos de maneira mais consistente, recuam diante
de ameacas superiores e podem cooperar com outros bots. Formar uma
tribo e opcional, depende de proximidade e oportunidade: parte dos bots
prefere jogar sozinha.

Bots acumulam XP real coletando e combatendo. Quando recebem pontos por
idade, escolhem armas ou construcoes usando as mesmas regras e os mesmos
pre-requisitos de idade do jogador (pacote H). Nao recebem armas de graca.
Um bot pode preferir machados para recursos, outro espada para combate e
outro arco ou besta; ao lutar, troca para equipamento de longo alcance
apenas se a arma estiver desbloqueada e se houver municao/recursos.
Quando o inimigo se aproxima ou ao coletar, volta a arma corpo a corpo.
Sua arma aparece normalmente para os demais jogadores pelos snapshots
do servidor; ataques respeitam tempo de recarga e fisica original. Quando formam grupos, usam as tribos reais do
servidor e nao recebem privilegios nem recursos inventados.

## Configuracao de controles

Abra **Opcoes > Editar teclado e joystick** na tela inicial, ou
**ESC > Configuracoes > Editar teclado e joystick** durante uma partida.
Clique no comando e pressione uma tecla ou botao fisico para remapear.
Analogicos genericos podem usar outros pares de eixos (1-2, 2-3, 3-4,
4-5 ou 5-6); a tela permite escolher cada par independentemente.
Ajuste zona morta, sensibilidade e troque os analogicos de gamepads SDL.
As escolhas ficam salvas na pasta de dados do LÖVE e continuam na
proxima execucao, sem afetar o servidor ou os mods. ESC cancela captura,
Restaurar Padrao recupera o layout inicial.

## Controle USB / Bluetooth (joystick)

Controles reconhecidos pelo SDL/LÖVE como gamepads (Xbox, PlayStation via
mapeamento, etc.) usam os botões padronizados. O cliente também tenta aceitar
joysticks USB genéricos com os eixos físicos 1/2 (esquerdo), 3/4 (direito)
e botões físicos 5 (L1), 6 (R1), 8 ou eixo 6 (R2). Em controles genéricos
com outra ordem de eixos, o mapeamento pode variar.

- Analógico **esquerdo**: andar.
- Analógico **direito / R3**: apontar a arma. Não precisa pressionar o R3:
  basta inclinar. A mira permanece onde foi deixada até movê-la novamente;
  mover o mouse devolve o controle da mira ao mouse.
- **L1 / LB**: item anterior na barra (incluindo armas e construções clássicas).
- **R2 / RT**: próximo item na barra. Cada puxada avança exatamente uma posição.
- **R1 / RB**: atacar/usar a arma selecionada, mantendo pressionado.
- **X / Quadrado**: ataque alternativo pelo comando Espaço.
- **A / Cruz**: interagir; **B / Círculo**: voltar/pausar; **Y / Triângulo**:
  cura/ação R.
- D-pad: atalhos 1–4; Start/Options: pausa.

A barra é a lista verdadeira de armas e itens recebida do servidor e o
equipamento selecionado só é confirmado pelo protocolo original `z`.
O controle não cria itens nem altera as regras multiplayer. Teclado e
mouse permanecem utilizáveis ao mesmo tempo.


## Duas maneiras de jogar multiplayer

**Jogar:** crie sua propria sala com o servidor Lua local, ou entre diretamente na sala de um amigo usando o convite `IP:porta/CODIGO` pela rede LAN/VPN.

**Servidores:** informe o endereco `IP:porta` de um **servidor V2 existente** (LAN/VPN) e clique **Buscar salas**. O jogo consulta `GET /api/public/rooms`, exibe nome, tipo, jogadores e vagas das salas disponíveis e permite escolher qual delas acessar. Salas publicas no catalogo ja incluem o convite; salas privadas pedem o codigo enviado pelo dono. A autorizacao V2 continua acontecendo no navegador. Para servidores abertos na Internet, utilize a entrada `https://sala.dominio` com certificado valido. O cliente nao inicia nenhum processo de servidor V2.


## Entrar em servidores V2 existentes

O cliente Windows permite entrar em salas LAN/VPN pelo IP/porta/código e em servidores V2 externos pelo convite `https://sala.dominio/CODIGO`. Use **Jogar → Entrar em outra sala**; quando a sala exigir login, selecione **Entrar com conta V2 (navegador)**. O aplicativo abre o navegador para cadastro/autorização PKCE; a senha nunca é digitada no jogo. Ao autorizar, o cliente recebe um token da sala e estabelece um WebSocket com os mesmos pacotes do Moo-IO.

Convites públicos exigem DNS, HTTPS/WSS, certificados válidos e o gateway V2 já configurado na VPS. O pacote Windows inclui um `node.exe` 22 isolado **somente como ponte TLS verificada para conexões de saída do cliente**, iniciado sob demanda e encerrado ao fechar o jogo. Ele não hospeda partidas e não executa o servidor Node.js do V2. Criar sala local utiliza exclusivamente o servidor Lua.

## Dificuldade das salas

- **Pacífico:** regeneração de 6 HP/s, menos animais hostis e criaturas comuns hostis deixam de perseguir espontaneamente; ideal para construção e exploração.
- **Normal:** jogo clássico, com valores e comportamento originais.
- **Difícil:** mais animais, lobos próximos compartilham alvos e tentam aproximar-se pelos flancos, além de prever o movimento do jogador.
- **Extremo:** maior pressão de inimigos, interceptação e formação de caça mais intensa.

Selecione o nível na tela **Criar minha sala**. O nível pertence à sala, não à conta do jogador. O Normal mantém todas as regras tradicionais.

## Instalar mapas e mods após extrair o jogo

Não é necessário recompilar. Os instaladores estão na mesma pasta de `MOO-IO.vbs`:

1. Para instalar um **mapa personalizado JSON**, arraste o arquivo para **`INSTALAR-MAPA.bat`**.
2. Para instalar um **mod de regras JSON** (animais, recursos, dificuldade etc.), arraste o arquivo para **`INSTALAR-MOD.bat`**.
3. Abra **Jogar → Configurar minha sala** para atualizar os mapas. Escolha o mapa desejado e marque os mods de regras desejados separadamente.

O instalador copia apenas JSON com nome e ID válidos, respeita limites de tamanho e não substitui arquivos existentes. O motor ainda valida integralmente campos, coordenadas, materiais, colisões e alterações antes de criar a sala. Não execute scripts Lua, EXEs ou arquivos de origem desconhecida para instalar mapas. Os diretórios de instalação são `server-lua/mods/maps/` e `server-lua/mods/`.

O modo **Normal** sem modificações continua usando as regras clássicas. Os mapas personalizados e seus mods de regras são carregados somente pela sala Lua local escolhida; o servidor V2 não é alterado.

## Animações opcionais para mobs (LÖVE / spritesheet)

O jogo aceita spritesheets PNG para **parado, andando, atacando, ferido e morte** em qualquer mapa personalizado. Nenhum desses estados é obrigatório: um mob sem configuração, sem PNG instalado ou com clipes ausentes usa o sprite estático existente. As animações são apenas visuais; velocidade, colisões, dano, IA, recompensas e respawn continuam no servidor Lua.

1. Arraste a spritesheet PNG para **`INSTALAR-ANIMACAO.bat`** na pasta extraída do jogo (ou copie para `assets/custom/img/animals/animations/`).
2. No manifesto `server-lua/mods/maps/ID.json`, acrescente `animalAnimations` com o ID do animal, `sheet`, `frameWidth`, `frameHeight` e apenas os clipes desejados.
3. Crie uma nova sala com esse mapa. O cliente usará os clipes que encontrar e manterá o PNG original para os demais mobs e situações.

O JSON é validado pelo servidor. Os clipes são selecionados usando posições recebidas, eventos de ataque e redução de vida; a morte, quando configurada, usa um efeito visual curto. **Para enxergar a animação em multiplayer, cada jogador precisa ter o mesmo PNG instalado**. A instalação do arquivo é independente da lógica do servidor.

Consulte `server-lua/maps/README.md` para o exemplo JSON completo. O mundo clássico e a conexão V2 não exigem nem alteram spritesheets.

## Mods de animacao independentes e especies novas

O menu **Jogar → Configurar minha sala → Mods** aceita agora dois exemplos:

- **Animacao Independente do Lobo** (`animacao-lobo.json`): anima o lobo original na sala Lua, mesmo sem mapa personalizado. O lobo permanece estatico ate instalar `lobo_animado.png`.
- **Especies Adicionais** (`novas-especies.json`): cria **Lobo Cinzento (15)** e **Lebre do Bosque (16)** como especies proprias, com AI, atributos, recompensas e spawn controlados no servidor. Os sprites originais de lobo/ovelha sao usados no exemplo como arte provisoria. Opcionalmente instale spritesheets `lobo_cinzento.png` e `lebre_bosque.png` para animar os novos mobs.

**Mapa de demonstração:** selecione **Reserva de Criaturas (mod)** e, na lista de mods, ative **Especies Adicionais**. A reserva usa os IDs novos 15 e 16 no seu subsolo. Sem o mod de espécies, o núcleo recusa a criação dessa sala para evitar monstros incorretos.

**Para criar seus proprios monstros:** arraste o manifesto JSON com `newAnimals` e `animalAnimations` para `INSTALAR-MOD.bat`. Arraste cada PNG de animacao para `INSTALAR-ANIMACAO.bat`. Se tiver um PNG **estatico** da nova especie, use `INSTALAR-MOB-ARTE.bat` e declare seu nome (sem .png) em `newAnimals[].src`. Isso instala na pasta `assets/custom/img/animals/`. Os dados de animacao sao opcionais, independentes do mapa e podem ser combinados com mods de dificuldade/recursos. Em multiplayer, cada cliente instala os mesmos PNGs para ver as artes, sem executar codigo remoto.

As novas especies usam IDs **15 a 63** e nao alteram os 15 tipos originais. Para colocar uma especie numa sala de mapa personalizado, declare `spaces[].mobs[].kind` com o ID e selecione o mod correspondente; sem ele, o servidor rejeita a sala em vez de converter silenciosamente o mob. O modo MB classico e os servidores V2 ficam separados.

## Núcleo de mods de dados

Os mods são arquivos JSON instalados em `server-lua/mods/`. Em **Jogar → Criar minha sala**, escolha primeiro **Pacífico**, **Normal**, **Difícil** ou **Extremo** e depois clique em **Escolher** para ativar os mods instalados. Também é possível informar os IDs no campo de texto.

O núcleo suporta mudanças na população/atributos de animais, na geração do mapa (árvores, pedras e minérios) e nas regras do mundo (regeneração de vida e IA cooperativa). Essas configurações são próprias da sala e são validadas antes de gerar o mapa. O modo Normal sem mods preserva as regras tradicionais.

Incluídos: `mais-lobos`, `fauna-hostil`, `floresta-densa` e `lobos-em-matilha`. Não são executados scripts de terceiros nem distribuídos novos assets para os convidados. Consulte `server-lua/mods/README.md` para o esquema e limites da API. Alterações de mods ou dificuldade exigem recriar a sala.

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
