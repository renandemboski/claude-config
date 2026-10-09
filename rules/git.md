# Regras de Git - Workflow e Convenções

## Estratégia de Branches

Padrão (projeto solo): commit direto na `main`, cada commit com permissão explícita do usuário.

```text
main            # Branch principal de todo repo (git init -b main, nunca master)
├── feature/*   # Opcional: funcionalidade grande ou trabalho em paralelo
├── fix/*       # Opcional: correção isolada
├── refactor/*  # Opcional: refatoração
└── chore/*     # Opcional: deps, configs, CI
```

- `main`: branch principal e de produção. Commit direto nela é o padrão, sempre depois de mostrar mensagem e arquivos e receber o ok do usuário.
- Branch de trabalho só quando o usuário pedir ou quando a mudança for grande demais para um commit só. Sai da `main` e volta por PR ou merge, com aprovação.
- `develop` só em projeto com time ou ambiente de homologação, quando o usuário pedir. Nesse caso, branches de trabalho saem da `develop` e `develop` vai para `main` por PR de release.

## Nomes de Branch

- Formato: `<tipo>/<short-description>` em inglês e `kebab-case`.
- Exemplos: `feature/user-registration`, `fix/login-redirect`, `refactor/split-services`.
- Nunca espaços, acentos ou caracteres especiais.
- Nunca branches genéricas como `teste`, `temp`, `nova-branch`.

## Commits - Conventional Commits

Formato, idioma, tipos, crases, tamanho e exemplos moram em `~/.claude/commands/commit.md`, fonte única. Usar `/commit` para gerar o commit; o hook `pre-commit-msg-guard.sh` barra mensagem fora do padrão.

## Pull Requests

- Título em inglês, curto e descritivo (máximo 70 caracteres). Descrição do PR em português.
- Descrição com: o que foi feito, por que, como testar.
- PR de branch de trabalho para `main` (ou para `develop`, quando o projeto tem essa branch).
- Nunca fazer merge sem build passando.

## Regras Gerais

- Nunca `git push --force` em `main` ou `develop`.
- Nunca commitar sem confirmar a branch com o usuário. Nunca dar `git push`, `commit --amend` ou `git rebase` sem permissão explícita.
- Antes de todo commit, mostrar no chat a mensagem completa e a lista de arquivos daquele commit. Em múltiplos commits, mostrar por commit.
- Nunca commitar arquivos grandes (binários, dumps, node_modules, bin/obj).
- Sempre verificar `git status` antes de commitar.
- Resolver conflitos antes de abrir PR - nunca fazer merge com conflitos.
- Para regras de `.env`, secrets e permissões de commit ver `CLAUDE.md`.
