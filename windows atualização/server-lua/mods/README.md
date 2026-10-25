# Mods do servidor local Lua

Coloque arquivos JSON nesta pasta e insira seus IDs (sem `.json`) na tela de criação de sala, separados por vírgula. Exemplo: `mais-lobos,fauna-hostil`.

Formato aceito: `schemaVersion: 1`, `id`, `name`, `requiresClient: "base"`, `changes`. Os únicos grupos desta primeira API são `animals` (atributos numéricos `health`, `dmg`, `speed`, `viewRange`, `turnSpeed`) e `spawns` (atributo inteiro `desired`). As chaves internas dos grupos são índices originais dos animais. Não há scripts nem permissões de execução, rede ou arquivos. Até oito mods ativos por sala; configurações inválidas ou conflitantes impedem a inicialização.

Dificuldades: **Clássico** (valores originais), **Difícil** (50% mais mobs comuns, 20% mais dano nos animais hostis), **Extremo** (até 100% mais mobs comuns, 50% mais dano hostil). Bosses e spawns especiais preservam suas regras originais. Mods substituem valores pontuais após o preset de dificuldade.

Reinicie a sala para aplicar as alterações. O jogador convidado não precisa instalar nada: são mudanças do servidor, usando animais e sprites originais.
