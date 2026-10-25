# Moo-IO Windows — JOGO COMPLETO + SERVIDOR LOCAL LUA (TESTE)

Este pacote reúne o jogo completo para Windows: cliente LÖVE 11.5, menu, controles,
mapas, imagens PNG, interface, áudio quando disponível, servidores locais LC/MB,
bots opcionais e todo o código do servidor local Lua.

**Não inclui o servidor Node.js nem a V2.** A opção "Criar minha sala"
inicia `server-lua/local_server.lua` por meio de `scripts/start-server-lua.ps1`.

## Como testar

1. Extraia o ZIP completo (não abra arquivos dentro do ZIP).
2. Se houver `love.exe` na pasta principal, basta executar **MOO-IO.vbs**.
   Se não houver, instale **LÖVE 11.5 para Windows 64-bit**, disponível em
   https://love2d.org/ e execute **MOO-IO.vbs**.
   O LÖVE 11.5 possui LuaSocket integrado.
3. No menu do jogo escolha **Criar minha sala**, selecione a rede LAN ou VPN
   privada, escolha a quantidade de bots (0 a 8) e confirme.
4. O servidor Lua começa junto com a sala. Use o convite fornecido pelo jogo
   para conectar outros clientes com a mesma versão/protocolo.
5. Para encerrar a sala utilize o menu do jogo (ESC).

## Importante

Este é um **build de teste** da réplica do servidor local Lua. O código e os
arquivos visuais estão incluídos, porém a paridade 1:1, estabilidade e testes
de ponta a ponta no Windows ainda não foram completamente validados.
Não é uma versão de produção certificada. O pacote GitHub automático contém
código e artes; o arquivo Windows portátil gerado no GitHub Actions
(`Moo-IO-Windows-Lua-Completo.zip`) inclui também o runtime LÖVE, se o
workflow de empacotamento concluir com sucesso.

Nenhum `npm install`, Node.js, V2, serviço online ou download automático
de dependências é necessário durante a inicialização do jogo. Para rede
multiplayer utilize uma LAN ou VPN privada. A hospedagem automática exige
Windows. Esta distribuição não contém progresso nem dados pessoais do host.

Código-fonte da réplica:
https://github.com/SrTristeSad/ToonRoyale-Assets
