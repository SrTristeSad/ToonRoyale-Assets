# Portabilidade Windows → Android

Origem canônica: `windows atualização/`. Destino: `android/`.

### Integrado nesta migração
- Arquivos Lua de servidor copiados da versão Windows para Android.
- Mesmos mapas JSON, mods de regras/espécies e parâmetros de dificuldade.
- Menu Windows de criação de sala e opções de mapa/mod em Android.
- Código de gameplay, objetos, protocolos e artes sincronizados.
- Morte, preservação do estado da sala e renascimento pelo socket existente.
- API de seleção de sala V2 e autenticação segura no navegador.
- `src/mobile/` e arquivos nativos Android retidos sem sobrescrita.
- Build Android usa o código-fonte desta própria pasta.

### Verificação necessária
- Fluxo visual e toque em todo o menu Windows adaptado à tela Android.
- LuaSocket e hospedagem de sala real por Wi-Fi/VPN, no emulador e celular.
- Animações, mods simultâneos, novos mobs, mapa aleatório e inventário em
  partidas reais.
- CPU, uso de RAM, aquecimento e estabilidade com sala aberta.
- Compatibilidade do V2 remoto sob rede real e mudança de conectividade.

O servidor mantém autoridade exclusiva sobre os jogadores e recursos.
Não afirmar paridade ou estabilidade 1:1 sem os testes físicos acima.
