# Servidor local Moo-IO em Lua — pacote de teste

Esta distribuição contém apenas a **cópia do servidor local Lua**, suas bibliotecas Lua e as dependências `src/` necessárias. **Não inclui Node.js, servidor V2, cliente gráfico, npm nem o servidor original.**

## Windows

1. Instale **LuaJIT para Windows (luajit.exe)** e **LuaSocket compatível com o mesmo LuaJIT**. O gerador criptográfico do servidor utiliza a API segura do Windows via `ffi`; não use Lua 5.4 puro no Windows sem adaptação da fonte aleatória.
2. Extraia **todo** o ZIP, mantendo as pastas `server-lua/` e `src/`.
3. Execute `Iniciar-Servidor-Lua.cmd` no diretório extraído, ou abra o PowerShell e rode:
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\Iniciar-Servidor-Lua.ps1 -IP 127.0.0.1 -Porta 8080 -Bots 0`
4. Use o IP, a porta e o código de convite exibidos para conectar o cliente Windows compatível com o protocolo local. **Pare o servidor Node que estiver usando a porta 8080 antes de iniciar o Lua.**

Para receber conexões de outros dispositivos LAN, use seu **IP privado real** no parâmetro `-IP` (não use IP público nem `0.0.0.0`). Pode definir `-Rede vpn` para endereços privados VPN compatíveis. O código do convite é gerado a cada inicialização ou passado por `-Codigo`.

## Linux

Instale `lua5.4` e `lua-socket`; execute `bash ./iniciar-servidor-lua.sh`.

## Status e limites

**Não é uma versão final validada 1:1.** Apesar da integração do servidor Lua (`server-lua/local_server.lua` e `server-lua/run.lua`), a execução completa com o cliente Windows, seus fluxos de autenticação e o teste de carga precisam ser aprovados. A distribuição é de **código-fonte Lua**, não contém runtime LuaJIT/LuaSocket executável integrado e **não substitui automaticamente o inicializador do jogo**. A execução depende da instalação do runtime indicado.

Este ZIP é gerado de arquivos existentes na cópia `windows atualização` do repositório `SrTristeSad/ToonRoyale-Assets`. O código Node original permanece intacto.
