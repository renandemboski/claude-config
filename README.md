# claude-config

Configuração pessoal do Claude Code: regras, agentes, comandos e hooks.

Stack alvo: TypeScript, Next.js (App Router), PostgreSQL com Prisma, Auth.js, Tailwind, Vitest, npm.

## Instalar

Clonar e copiar o conteúdo para a pasta de configuração do Claude Code:

```bash
git clone https://github.com/renandemboski/claude-config.git
cd claude-config
cp -r CLAUDE.md settings.json rules agents commands hooks ~/.claude/
```

No Windows, a pasta é `C:\Users\<usuario>\.claude`.

## O que tem aqui

| Pasta | Conteúdo |
|-------|----------|
| `CLAUDE.md` | Regras gerais: escrita, estilo de resposta, stack, fluxo de trabalho |
| `rules/` | Regras por área, lidas sob demanda antes de codar |
| `agents/` | Time de 8 agentes: refinamento, plano, contrato de API, implementação, QA, segurança, docs |
| `commands/` | `/commit` e `/dev-team` |
| `hooks/` | Guardas de git (commit, push, segredos), formatação e limpeza automática |

## Hooks

Os hooks bloqueiam ou pedem confirmação antes de: commit fora do padrão, push, amend, rebase, `git add` de arquivo sensível e operação destrutiva. Ficam registrados em `settings.json`.
