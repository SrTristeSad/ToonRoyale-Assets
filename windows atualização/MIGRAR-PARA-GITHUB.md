# Moo-IO Windows — auditoria de publicação

**Origem de desenvolvimento:** `SrTristeSad/ToonRoyale-Assets/windows atualização/`
  
**Repositório oficial de destino:** `SrTristeSad/Moo-IO/windows/`

Esta cópia ainda é a área de desenvolvimento. **Nenhum arquivo do repositório
oficial é modificado automaticamente** ao gerar os pacotes.

## O que entra no projeto Windows oficial

- `main.lua`, `conf.lua` e o único inicializador `MOO-IO.vbs`.
- `src/`: cliente LÖVE e conexão LAN/VPN e servidor V2 existente.
- `server-lua/`: servidor autoritativo, mapas JSON e mods JSON.
- `assets/`: artes, sprites e opções de animação.
- `scripts/start-server-lua.ps1`: host Lua local no Windows.
- `scripts/tls-relay.mjs`: conexão TLS para servidor V2 **existente**.
- Scripts de importação JSON/PNG, compilação e validação para quem mantém o código.
- `LICENSE`, `NOTICE.md` e `licenses/` originais.

## O que NÃO entra

- Nenhum `.bat`, launcher de teste ou inicializador duplicado.
- A pasta `server/` com o servidor Node.js histórico.
- `shared/`, `package.json`, `tools/`, `tests/` e `support/`: referências
  e ferramentas do ambiente anterior, sem dependência do runtime Lua.
- `server-lua/tests/` e `src/test_*.lua`: testes mantidos na cópia de
  desenvolvimento, não no produto nem no arquivo de fontes destinado à migração.
- Binários `love.exe`, `node.exe` e DLLs no pacote **de código-fonte**.
  Esses binários são incluídos somente no pacote **Windows executável**.

A presença de `node.exe` **na compilação Windows** é intencional: o processo
é usado como *ponte TLS de saída* para se conectar a salas V2 HTTPS/WSS. Não
é o antigo servidor Node e não hospeda partidas.

## Gerar os dois pacotes

No Windows, o pipeline de release executa:

1. `scripts/build-windows.ps1` — inclui executáveis LÖVE e a ponte TLS para
   jogadores; entrega `Moo-IO-Windows-Lua.zip`.
2. `scripts/export-github-source.ps1` — copia apenas código e recursos
   autorizados, sem binários nem testes; entrega
   `Moo-IO-GitHub-Source.zip`.

O arquivo de fontes contém **o conteúdo destinado à pasta `windows/`**,
não a raiz do repositório. O projeto oficial também contém outras partes,
incluindo Android e servidor dedicado V2; não substitua essas pastas.

## Antes de substituir `Moo-IO/windows/`

1. Compare com a pasta `windows/` já existente em `SrTristeSad/Moo-IO`,
   especialmente quaisquer mudanças feitas nela durante este desenvolvimento.
2. Trabalhe em branch/PR no repositório oficial e preserve os arquivos do
   projeto que não forem comprovadamente obsoletos.
3. Rode novamente os testes de sintaxe LuaJIT, mapa/mod, criação de sala,
   multiplayer e joystick em Windows. Consulte os testes de paridade preservados
   nesta cópia de desenvolvimento.
4. Verifique instalação limpa: `MOO-IO.vbs`, LAN, VPN, login V2, morte e
   renascimento, escolha de mapas, mods JSON e animações.
5. Somente depois integre ao `main` oficial.

Nenhuma promessa de paridade visual/funcional total é feita sem testes
manuais nos controles físicos e na interface em Windows.

## Instalação de mods sem BAT

- Mapas: `server-lua/mods/maps/*.json`
- Mods de regras/espécies: `server-lua/mods/*.json`
- Animações: `assets/custom/img/animals/animations/*.png`
- Sprites de espécies: `assets/custom/img/animals/*.png`

Use F5 no menu de criação de sala para atualizar. Mods são dados, não
executáveis Lua ou outros scripts de terceiros.
