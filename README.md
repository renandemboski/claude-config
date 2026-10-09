# claude-config

Configuração pessoal do Claude Code: regras, comandos, agentes e hooks.

Stack alvo: TypeScript, Next.js (App Router), PostgreSQL com Prisma, Better Auth, Tailwind v4, Vitest, npm.

## Instalar

Clonar e copiar o conteúdo para a pasta de configuração do Claude Code:

```bash
git clone https://github.com/renandemboski/claude-config.git
cd claude-config
cp -r CLAUDE.md settings.json rules commands agents hooks ~/.claude/
```

No Windows, a pasta é `C:\Users\<usuario>\.claude`.

## O que tem aqui

| Pasta       | Conteúdo                                                                                                             |
| ----------- | -------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE.md` | Regras gerais: escrita, estilo de resposta, stack, fluxo de trabalho                                                 |
| `rules/`    | Regras por área, lidas sob demanda antes de codar                                                                    |
| `commands/` | `/commit`, `/dev-team` (feature de ponta a ponta com o time de agentes) e `/gauntlet` (polimento até uma referência) |
| `agents/`   | Agentes do `/dev-team`: refinar, planejar, contrato de API, back, front, QA, segurança, docs                         |
| `hooks/`    | Guardas de git (commit, push, segredos), de escrita (travessão e emoji) e formatação                                 |

## Hooks

Os hooks bloqueiam ou pedem confirmação antes de: commit fora do padrão, push, amend, rebase, `git add` de arquivo sensível e operação destrutiva. Ficam registrados em `settings.json`.
