# Claude oficial + 9router ao mesmo tempo

Os recursos da sua conta (conectores do claude.ai, sessões na nuvem, Cowork, Artifacts) só funcionam no Claude logado na conta. Por isso este sistema não tenta "passar" esses recursos para o 9router. Ele deixa os dois lado a lado e conectados.

| Comando | Passa por | Tem |
|---|---|---|
| `claude` | Sua conta Anthropic | Tudo: conectores, plugins, skills, **e a ponte para o 9router** |
| `claude9` | 9router | As mesmas skills, plugins, agentes, comandos e CLAUDE.md global |

## Instalar (Windows)

Precisa do Claude Code e do Node.js 18 ou mais novo.

1. Baixe esta pasta (`ferramentas/claude-9router`) para o seu PC.
2. Abra o PowerShell dentro dela e rode:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\instalar.ps1
   ```
3. Responda às perguntas: o endereço do 9router (o mesmo que você pôs em `ANTHROPIC_BASE_URL`), a chave, se houver, e o modelo padrão.
4. Feche e abra o terminal. Rode `claude` e faça `/login` com sua conta, se ele pedir.

Se o 9router estava configurado de forma global, o instalador avisa e oferece remover. Sem isso, o `claude` oficial continuaria sem os recursos da conta.

## Usar

- **Trabalho principal:** `claude`. No meio da conversa você pode pedir, por exemplo:
  - "Usa o 9router para gerar 20 variações deste título."
  - "Pede uma segunda opinião ao 9router sobre este código."

  O Claude oficial chama a ferramenta `perguntar_9router` e continua o trabalho com a resposta.
- **Sessão inteira barata:** `claude9`.

## Cuidados

- O 9router vê tudo o que passa por ele. Não mande senhas, tokens ou chaves.
- A chave do 9router fica salva em `~/.claude-9router/9router.json` e na configuração do MCP do seu usuário.
- Para desinstalar:
  - Rode `claude mcp remove ponte-9router --scope user`.
  - Apague o bloco `claude9` do seu `$PROFILE`.
  - Apague a pasta `~/.claude-9router`.
